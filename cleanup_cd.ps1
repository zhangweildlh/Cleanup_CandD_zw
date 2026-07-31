<#
.SYNOPSIS
    C+D 盘垃圾文件清理规划 / 执行脚本（通用、可移植、DryRun 默认、零副作用）
.DESCRIPTION
    消费前序扫描生成的处置清单 CSV（字段：FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason），
    依据 Cleanable 字段，经"标签→处置映射层"规划三类处置：
      - 自动清理 / 是          -> 确定拟删除
      - 需确认 / 谨慎          -> 默认不删，列为待确认
      - 保留 / 否 / 受保护 / 未知 -> 永不删除（保守默认，避免遗漏未知取值导致误删）

    映射层同时兼容两套清单的 Cleanable 列取值（注意：扫描报告的"17 种描述性标签"属于
    Category 列，并非 Cleanable 列；Cleanable 列本身是简短处置标记）：
      - scan3（D 盘）：自动清理 / 需确认 / 保留 / 否 / 受保护
      - scan2（C 盘）：是（可清理）/ 否（保留）/ 谨慎（需人工确认）

    两层硬保护（保证对 Win11 系统 / 已装程序 / 工作目录 / 个人文档零破坏）：
      1) 安全根拦截：凡拟删除项落在任一"安全根目录"（默认 D:\ZW工作、D:\Tools、D:\Documents，
         且为硬编码兜底、不可被 -SafeRoots 移除）下，一律提升为"需二次确认（按目录批量）"，即便其原本为自动清理。
      2) 系统核心保护：凡拟删除项落在系统核心目录（C:\Windows、C:\Program Files、C:\Program Files (x86)、
         C:\ProgramData）下，强制降为"待确认"（系统核心目录强制待确认清单），绝不自动删除。

    默认 Mode=DryRun：只把拟删除清单输出到 Markdown 与完整 CSV，绝不触碰任何文件。
    显式 -Mode Execute 才执行删除；且对安全根 / 系统核心降级 / 目录型路径均强制按目录交互确认；
    可再加 -WhatIf 做"模拟删除"试运行（仅报告、不实际删）。

    本脚本不硬编码任何具体文件路径，所有输入均经参数传入，可针对任意清单反复复用。
    对含 [] {} 等特殊字符的路径，删除一律使用 -LiteralPath，避免被 PowerShell 通配符误解释。

    编码健壮性（F2 修复）：CSV 读取使用自研 StreamReader + BOM 探测 + RFC4180 引号解析，
    不依赖 Import-Csv -Encoding 的不可靠行为，兼容 UTF-8（有/无 BOM）与 UTF-16。
    性能（F1/F2 配套）：解析阶段仅产出轻量字符串数组，仅在分类为非保留时才构建规划对象，降低大清单（40 万+ 行）内存与耗时。
.PARAMETER CsvPaths
    一个或多个处置清单 CSV（字段见上）。可同时传入 C 盘与 D 盘清单。
.PARAMETER Mode
    DryRun（默认，仅输出，零副作用）| Execute（执行删除）。
.PARAMETER SafeRoots
    需二次确认的安全根目录列表。默认含 D:\ZW工作、D:\Tools、D:\Documents；
    注意：这三个关键根为硬编码兜底，始终生效，用户传入的 -SafeRoots 仅作"追加"，无法移除它们。
.PARAMETER OutMd
    DryRun 输出的 Markdown 报告路径。默认 cleanup_plan.md。
.PARAMETER OutCsv
    逐文件完整处置清单 CSV 路径（与 MD 互补，保证绝对路径不丢失）。默认 cleanup_plan_files.csv。
.PARAMETER DeleteConfirmed
    仅 Execute 模式有效：是否同时删除非安全根的"需确认"项与"系统核心降级"项（默认关闭，仅删自动清理 + 安全根已确认项）。
.PARAMETER FullList
    在 Markdown 中逐文件列出"需确认"与"安全根"项的绝对路径（默认关闭，改为按目录聚合 + 样本，以防 MD 过大）。
.PARAMETER WhatIf
    仅 Execute 模式有效：模拟删除，仅报告将删除哪些文件/目录，不实际执行删除，也不弹出交互确认。
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$CsvPaths,

    [ValidateSet('DryRun', 'Execute')]
    [string]$Mode = 'DryRun',

    [string[]]$SafeRoots = @('D:\ZW工作', 'D:\Tools', 'D:\Documents'),

    [string]$OutMd = 'cleanup_plan.md',
    [string]$OutCsv = 'cleanup_plan_files.csv',

    [switch]$DeleteConfirmed,
    [switch]$FullList,
    [switch]$WhatIf
)

# ===================== 初始化 =====================
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# ---- 关键安全根（硬编码兜底，始终生效，不可被 -SafeRoots 覆盖移除） ----
# 即便用户自定义 -SafeRoots，以下根仍强制纳入二次确认保护（修复 F5）。
$EssentialSafeRoots = @('D:\ZW工作', 'D:\Tools', 'D:\Documents')
$SafeRoots = ($EssentialSafeRoots + @($SafeRoots)) | Sort-Object -Unique

# ---- 系统核心保护目录（硬编码）：命中即强制降为"待确认"，绝不自动删除（修复 F1 兜底） ----
$SystemProtectedRoots = @('C:\Windows', 'C:\Program Files', 'C:\Program Files (x86)', 'C:\ProgramData')

# 安全根规范化（带末尾反斜杠，供前缀匹配）。使用 StartsWith 大小写不敏感，避免 -like 通配符陷阱。
$safeRootPatterns = @()
foreach ($r in $SafeRoots) {
    $norm = ($r.Trim().TrimEnd('\') + '\')
    $safeRootPatterns += [PSCustomObject]@{ Raw = $r.Trim(); Pattern = $norm }
}

function Test-SafeRootMatch {
    param([string]$Path)
    foreach ($s in $safeRootPatterns) {
        if ($Path.StartsWith($s.Pattern, [System.StringComparison]::OrdinalIgnoreCase)) { return $s.Raw }
    }
    return $null
}

# 系统核心目录规范化与匹配
$systemPatterns = $SystemProtectedRoots | ForEach-Object { ($_.Trim().TrimEnd('\') + '\') }
function Test-SystemProtected {
    param([string]$Path)
    foreach ($p in $systemPatterns) {
        if ($Path.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

# ===================== 标签 -> 处置 映射层（修复 F1） =====================
# 覆盖两套清单的 Cleanable 列取值（注意：扫描报告的"17 种描述性标签"属于 Category 列，
# 并非 Cleanable 列；Cleanable 列本身是简短处置标记）：
#   - scan3（D 盘）：自动清理 / 需确认 / 保留 / 否 / 受保护
#   - scan2（C 盘）：是（可清理）/ 否（保留）/ 谨慎（需人工确认）
# 未知取值一律保留（保守默认，避免误删）。
$DeleteLabels = @(
    '自动清理',   # scan3：直接可清理
    '是'          # scan2：C 盘标记为"是"= 可清理
)
$ConfirmLabels = @(
    '需确认',     # scan3：需用户确认
    '谨慎'        # scan2：C 盘标记为"谨慎"= 需人工确认
)

function Map-Cleanable {
    param([string]$Label)
    if ($DeleteLabels -contains $Label) { return 'Delete' }
    if ($ConfirmLabels -contains $Label) { return 'Confirm' }
    return 'Keep'   # 保留 / 否 / 受保护 / 未知 -> 一律保留
}

function Format-MdRow {
    param([string]$Path, [string]$Size, [string]$Cat, [string]$Reason)
    $p = $Path -replace '\|', '/'
    $r = $Reason -replace '\|', '/'
    return ('| {0} | {1} | {2} | {3} |' -f $p, $Size, $Cat, $r)
}

function Format-CsvLine {
    param($fields)
    $parts = foreach ($v in $fields) {
        $s = if ($null -eq $v) { '' } else { $v.ToString() }
        '"' + ($s -replace '"', '""') + '"'
    }
    return ($parts -join ',')
}

function Convert-SizeToDouble {
    param($Value)
    if ($null -eq $Value) { return 0.0 }
    try { return [double]($Value.ToString()) } catch { return 0.0 }
}

# ===================== 健壮 CSV 读取（修复 F2，轻量返回字符串数组） =====================
# 自研 RFC4180 引号解析 + BOM 探测，兼容 UTF-8（有/无 BOM）与 UTF-16 LE/BE。
# 返回 [PSCustomObject]@{ Header = string[]; Records = List[string[]] }，避免在解析阶段构建重型对象。
function Read-CsvRecords {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $encoding = [System.Text.Encoding]::UTF8
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.Encoding]::UTF8
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.Encoding]::Unicode          # UTF-16 LE
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.Encoding]::BigEndianUnicode  # UTF-16 BE
    }
    else {
        $encoding = [System.Text.Encoding]::UTF8              # 无 BOM：默认按 UTF-8（本清单实测均为 UTF-8）
    }

    $text = [System.IO.File]::ReadAllText($Path, $encoding)

    $records = [System.Collections.Generic.List[string[]]]::new()
    $field = [System.Text.StringBuilder]::new()
    $row = [System.Collections.Generic.List[string]]::new()
    $inQuotes = $false
    $i = 0
    $len = $text.Length

    while ($i -lt $len) {
        $c = $text[$i]
        if ($inQuotes) {
            if ($c -eq '"') {
                if ($i + 1 -lt $len -and $text[$i + 1] -eq '"') {
                    [void]$field.Append('"'); $i += 2; continue
                }
                else { $inQuotes = $false; $i++; continue }
            }
            else { [void]$field.Append($c); $i++; continue }
        }
        else {
            if ($c -eq '"') { $inQuotes = $true; $i++; continue }
            elseif ($c -eq ',') {
                [void]$row.Add($field.ToString()); [void]$field.Clear(); $i++; continue
            }
            elseif ($c -eq "`r") {
                if ($i + 1 -lt $len -and $text[$i + 1] -eq "`n") { $i += 2 } else { $i++ }
                [void]$row.Add($field.ToString()); [void]$field.Clear()
                [void]$records.Add($row.ToArray()); $row.Clear()
                continue
            }
            elseif ($c -eq "`n") {
                [void]$row.Add($field.ToString()); [void]$field.Clear()
                [void]$records.Add($row.ToArray()); $row.Clear()
                $i++; continue
            }
            else { [void]$field.Append($c); $i++; continue }
        }
    }
    # 处理末尾无换行的最后一条记录
    if ($field.Length -gt 0 -or $row.Count -gt 0) {
        [void]$row.Add($field.ToString()); [void]$field.Clear()
        [void]$records.Add($row.ToArray()); $row.Clear()
    }

    if ($records.Count -eq 0) { return [PSCustomObject]@{ Header = @(); Records = $records } }

    $header = $records[0]
    [void]$records.RemoveAt(0)   # 移除表头，Records 仅含数据行

    # 过滤全空数据行
    $clean = [System.Collections.Generic.List[string[]]]::new()
    foreach ($rec in $records) {
        $nonEmpty = 0
        foreach ($cv in $rec) { if (-not [string]::IsNullOrEmpty($cv)) { $nonEmpty++ } }
        if ($nonEmpty -gt 0) { [void]$clean.Add($rec) }
    }

    return [PSCustomObject]@{ Header = $header; Records = $clean }
}

# ===================== 加载清单 + 规划处置（一次遍历） =====================
$planDelete = [System.Collections.ArrayList]::new()
$planConfirm = [System.Collections.ArrayList]::new()
$planSafe = [System.Collections.ArrayList]::new()
$planGuarded = [System.Collections.ArrayList]::new()   # 系统核心目录强制降级的待确认项
$skippedKeep = 0
$loadedFiles = @()

foreach ($cp in $CsvPaths) {
    if (-not (Test-Path -LiteralPath $cp)) {
        Write-Warning ('CSV 不存在，已跳过: {0}' -f $cp)
        continue
    }
    try {
        $data = Read-CsvRecords -Path $cp
        if ($data.Records.Count -eq 0) {
            Write-Warning ('CSV 解析为空，已跳过: {0}' -f $cp)
            continue
        }
        # 表头校验（修复 F6）：缺必需列即跳过并报错
        $hdr = $data.Header
        $idxFull = [array]::IndexOf($hdr, 'FullPath')
        $idxClean = [array]::IndexOf($hdr, 'Cleanable')
        $idxSize = [array]::IndexOf($hdr, 'SizeMB')
        $idxCat = [array]::IndexOf($hdr, 'Category')
        $idxReason = [array]::IndexOf($hdr, 'Reason')
        if ($idxFull -lt 0 -or $idxClean -lt 0) {
            Write-Warning ('CSV 缺少必需列(FullPath/Cleanable)，表头为 [{0}]，已跳过: {1}' -f ($hdr -join ','), $cp)
            continue
        }

        # 一次遍历：提取 -> 映射 -> 分类 -> 仅非保留项构建规划对象
        foreach ($cols in $data.Records) {
            $fp = if ($idxFull -lt $cols.Count) { $cols[$idxFull].Trim() } else { '' }
            if ([string]::IsNullOrWhiteSpace($fp)) { continue }

            $cleanable = if ($idxClean -lt $cols.Count) { $cols[$idxClean].Trim() } else { '' }
            $intent = Map-Cleanable $cleanable
            if ($intent -eq 'Keep') { $skippedKeep++; continue }

            $safeRoot = Test-SafeRootMatch -Path $fp

            # 系统核心目录强制降级（F1 兜底）：Delete -> Confirm
            $systemGuarded = $false
            if ($intent -eq 'Delete' -and (Test-SystemProtected -Path $fp)) {
                $intent = 'Confirm'
                $systemGuarded = $true
            }

            # 先按索引取值（避免 if 作为函数实参的语法问题），再构建对象
            $sizeVal   = if ($idxSize -lt $cols.Count) { $cols[$idxSize] } else { $null }
            $catVal    = if ($idxCat -lt $cols.Count) { $cols[$idxCat] } else { '' }
            $reasonVal = if ($idxReason -lt $cols.Count) { $cols[$idxReason] } else { '' }

            $item = [PSCustomObject]@{
                Path          = $fp
                SizeMB        = (Convert-SizeToDouble $sizeVal)
                Category      = $catVal
                Reason        = $reasonVal
                Intent        = $intent
                SafeRoot      = $safeRoot
                SystemGuarded = $systemGuarded
                Parent        = (Split-Path $fp -Parent)
            }

            if ($safeRoot) { [void]$planSafe.Add($item) }
            elseif ($systemGuarded) { [void]$planGuarded.Add($item) }
            elseif ($intent -eq 'Delete') { [void]$planDelete.Add($item) }
            else { [void]$planConfirm.Add($item) }
        }

        $loadedFiles += $cp
        Write-Output ('已加载: {0} （数据行 {1}）' -f $cp, $data.Records.Count)
    }
    catch {
        Write-Warning ('读取 CSV 失败，已跳过: {0} - {1}' -f $cp, $_.Exception.Message)
        continue
    }
}

if (($planDelete.Count + $planConfirm.Count + $planSafe.Count + $planGuarded.Count) -eq 0) {
    Write-Error '未加载到任何有效清单数据（或清单中无拟处置项），脚本终止。'
    exit 1
}

# ===================== 目录聚合辅助（O(n) 单次遍历，避免逐组嵌套 Group-Object 的性能灾难） =====================
function Get-ParentAggregation {
    param($Items, [int]$TopN = 0)
    $agg = @{}
    foreach ($it in $Items) {
        $p = $it.Parent
        if (-not $agg.ContainsKey($p)) { $agg[$p] = @{ Count = 0; Size = 0.0; Cats = @{} } }
        $a = $agg[$p]
        $a.Count++
        $a.Size += $it.SizeMB
        $c = $it.Category
        if ($a.Cats.ContainsKey($c)) { $a.Cats[$c]++ } else { $a.Cats[$c] = 1 }
    }
    $rows = foreach ($k in $agg.Keys) {
        $a = $agg[$k]
        $topCat = '未知'; $best = 0
        foreach ($ck in $a.Cats.Keys) { if ($a.Cats[$ck] -gt $best) { $best = $a.Cats[$ck]; $topCat = $ck } }
        [PSCustomObject]@{ Parent = $k; Count = $a.Count; Size = $a.Size; TopCat = $topCat }
    }
    $rows = $rows | Sort-Object Count -Descending
    if ($TopN -gt 0 -and $rows.Count -gt $TopN) { $rows = $rows | Select-Object -First $TopN }
    return $rows
}

# ===================== 生成 Markdown 报告 =====================
function New-MarkdownReport {
    param(
        $PlanDelete, $PlanConfirm, $PlanSafe, $PlanGuarded,
        $LoadedFiles, $SafeRoots, $SystemProtectedRoots, $Mode, $WhatIf
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# C+D 盘垃圾文件清理规划报告')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(('> 生成时间: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$sb.AppendLine(('> 运行模式: **{0}**（{1}）' -f $Mode, $(if ($Mode -eq 'DryRun') { '仅输出，未删除任何文件' } elseif ($WhatIf) { '模拟删除（WhatIf，未实际删除）' } else { '执行删除' })))
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## 一、数据来源')
    foreach ($f in $LoadedFiles) { [void]$sb.AppendLine(('- ' + $f)) }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## 二、安全根目录（删前需二次确认，硬编码兜底）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('凡拟删除项落于以下目录，一律按目录批量二次确认，绝不自动删除（含硬编码兜底根，不可被参数移除）：')
    [void]$sb.AppendLine()
    foreach ($r in $SafeRoots) { [void]$sb.AppendLine(('- ' + $r)) }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## 三、系统核心保护目录（命中即强制降为待确认）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('凡拟删除项落于以下系统目录，一律强制降为"待确认"，绝不自动删除，保证 Win11 系统与已装程序零破坏：')
    [void]$sb.AppendLine()
    foreach ($r in $SystemProtectedRoots) { [void]$sb.AppendLine(('- ' + $r)) }
    [void]$sb.AppendLine()

    $delSize = ($PlanDelete | Measure-Object -Property SizeMB -Sum).Sum
    $conSize = ($PlanConfirm | Measure-Object -Property SizeMB -Sum).Sum
    $safeSize = ($PlanSafe | Measure-Object -Property SizeMB -Sum).Sum
    $guardSize = ($PlanGuarded | Measure-Object -Property SizeMB -Sum).Sum

    [void]$sb.AppendLine('## 四、处置统计')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| 处置类别 | 文件数 | 总体积(MB) | 说明 |')
    [void]$sb.AppendLine('| --- | --- | --- | --- |')
    [void]$sb.AppendLine(('| 确定拟删除（自动清理，非安全根、非系统核心） | {0} | {1:N2} | 默认删除（DryRun 仅列出） |' -f $PlanDelete.Count, $delSize))
    [void]$sb.AppendLine(('| 待确认（需确认，非安全根） | {0} | {1:N2} | 默认不删，需用户决定 |' -f $PlanConfirm.Count, $conSize))
    [void]$sb.AppendLine(('| 安全根二次确认 | {0} | {1:N2} | 按目录批量确认后删除 |' -f $PlanSafe.Count, $safeSize))
    [void]$sb.AppendLine(('| 系统核心降级待确认 | {0} | {1:N2} | 命中系统核心目录，强制待确认，不自动删 |' -f $PlanGuarded.Count, $guardSize))
    [void]$sb.AppendLine()

    # 第一节 确定拟删除
    [void]$sb.AppendLine('## 五、确定拟删除清单（自动清理，非安全根、非系统核心）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> 以下文件经标签映射为"自动清理"，且不在任一安全根、也不在系统核心目录下，默认删除。')
    [void]$sb.AppendLine()
    if ($PlanDelete.Count -eq 0) {
        [void]$sb.AppendLine('_无_')
    }
    else {
        [void]$sb.AppendLine('| 绝对路径 | 体积(MB) | 分类 | 说明(Reason) |')
        [void]$sb.AppendLine('| --- | --- | --- | --- |')
        foreach ($it in $PlanDelete) {
            [void]$sb.AppendLine((Format-MdRow -Path $it.Path -Size ('{0:N4}' -f $it.SizeMB) -Cat $it.Category -Reason $it.Reason))
        }
    }
    [void]$sb.AppendLine()

    # 第二节 待确认
    [void]$sb.AppendLine('## 六、待确认清单（需确认，非安全根）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(('> 共 {0} 个文件 / {1:N2} MB，默认不删除。' -f $PlanConfirm.Count, $conSize))
    if (-not $FullList) {
        [void]$sb.AppendLine('> 以下按所在目录聚合展示；如需逐文件绝对路径，请运行脚本时加 `-FullList`，或查阅同目录完整清单 CSV。')
    }
    [void]$sb.AppendLine()
    if ($PlanConfirm.Count -eq 0) {
        [void]$sb.AppendLine('_无_')
    }
    else {
        if ($FullList) {
            [void]$sb.AppendLine('| 绝对路径 | 体积(MB) | 分类 | 说明(Reason) |')
            [void]$sb.AppendLine('| --- | --- | --- | --- |')
            foreach ($it in $PlanConfirm) {
                [void]$sb.AppendLine((Format-MdRow -Path $it.Path -Size ('{0:N4}' -f $it.SizeMB) -Cat $it.Category -Reason $it.Reason))
            }
        }
        else {
            [void]$sb.AppendLine('| 所在目录 | 文件数 | 总体积(MB) | 主要分类 |')
            [void]$sb.AppendLine('| --- | --- | --- | --- |')
            $grp = Get-ParentAggregation -Items $PlanConfirm -TopN 500
            foreach ($g in $grp) {
                [void]$sb.AppendLine(('| {0} | {1} | {2:N2} | {3} |' -f ($g.Parent -replace '\|', '/'), $g.Count, $g.Size, $g.TopCat))
            }
            [void]$sb.AppendLine()
            [void]$sb.AppendLine(('> 注：仅展示文件数前 500 的目录；完整 {0} 项见同目录清单 CSV。' -f $PlanConfirm.Count))
        }
    }
    [void]$sb.AppendLine()

    # 第三节 安全根
    [void]$sb.AppendLine('## 七、安全根目录待二次确认清单')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> 以下拟删除项落在安全根目录下，执行删除前将按目录批量请求确认。DryRun 模式下仅列出。')
    [void]$sb.AppendLine()
    if ($PlanSafe.Count -eq 0) {
        [void]$sb.AppendLine('_无（安全根目录下当前无拟删除项，已验证未误伤）_')
    }
    else {
        $byRoot = $PlanSafe | Group-Object SafeRoot
        foreach ($br in $byRoot) {
            [void]$sb.AppendLine(('### 安全根：{0}' -f $br.Name))
            [void]$sb.AppendLine()
            if ($FullList) {
                [void]$sb.AppendLine('| 绝对路径 | 体积(MB) | 原分类 | 说明(Reason) |')
                [void]$sb.AppendLine('| --- | --- | --- | --- |')
                foreach ($it in $br.Group) {
                    [void]$sb.AppendLine((Format-MdRow -Path $it.Path -Size ('{0:N4}' -f $it.SizeMB) -Cat $it.Category -Reason $it.Reason))
                }
            }
            else {
                [void]$sb.AppendLine('| 所在子目录 | 文件数 | 总体积(MB) |')
                [void]$sb.AppendLine('| --- | --- | --- |')
                $grp = Get-ParentAggregation -Items $br.Group
                foreach ($g in $grp) {
                    [void]$sb.AppendLine(('| {0} | {1} | {2:N2} |' -f ($g.Parent -replace '\|', '/'), $g.Count, $g.Size))
                }
            }
            [void]$sb.AppendLine()
        }
    }

    # 第四节 系统核心降级
    [void]$sb.AppendLine('## 八、系统核心目录强制待确认清单')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> 以下拟删除项命中系统核心保护目录（C:\Windows / Program Files / ProgramData 等），已被强制降为"待确认"，绝不自动删除。如需清理，需显式 `-DeleteConfirmed` 并在交互中确认。')
    [void]$sb.AppendLine()
    if ($PlanGuarded.Count -eq 0) {
        [void]$sb.AppendLine('_无（系统核心目录下当前无拟删除项，已验证未误伤）_')
    }
    else {
        if ($FullList) {
            [void]$sb.AppendLine('| 绝对路径 | 体积(MB) | 分类 | 说明(Reason) |')
            [void]$sb.AppendLine('| --- | --- | --- | --- |')
            foreach ($it in $PlanGuarded) {
                [void]$sb.AppendLine((Format-MdRow -Path $it.Path -Size ('{0:N4}' -f $it.SizeMB) -Cat $it.Category -Reason $it.Reason))
            }
        }
        else {
            [void]$sb.AppendLine('| 所在目录 | 文件数 | 总体积(MB) |')
            [void]$sb.AppendLine('| --- | --- | --- |')
            $grp = Get-ParentAggregation -Items $PlanGuarded -TopN 500
            foreach ($g in $grp) {
                [void]$sb.AppendLine(('| {0} | {1} | {2:N2} |' -f ($g.Parent -replace '\|', '/'), $g.Count, $g.Size))
            }
        }
    }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## 九、安全声明')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('- 本脚本 DryRun 模式**不删除任何文件**，仅生成规划报告。')
    [void]$sb.AppendLine('- 所有删除决策来源于清单 CSV 的 `Cleanable` 字段，经"标签→处置映射层"统一处理（兼容 scan2 描述性标签与 scan3 三值标签），未硬编码任何具体文件。')
    [void]$sb.AppendLine('- 安全根目录（D:\ZW工作、D:\Tools、D:\Documents 等，含硬编码兜底）下的任何拟删除项均被拦截为二次确认，避免误删用户工作/工具/文档。')
    [void]$sb.AppendLine('- 系统核心目录（C:\Windows、C:\Program Files、C:\ProgramData 等）下的拟删除项被强制降为待确认，保证 Win11 系统与已装程序零破坏。')
    [void]$sb.AppendLine('- 删除操作使用 `-LiteralPath`，对含 `[]{}` 等特殊字符的路径安全；目录型路径显式 `-Recurse` 且按目录二次确认；Execute 模式可用 `-WhatIf` 模拟试运行。')

    return $sb.ToString()
}

$md = New-MarkdownReport -PlanDelete $planDelete -PlanConfirm $planConfirm -PlanSafe $planSafe -PlanGuarded $planGuarded -LoadedFiles $loadedFiles -SafeRoots $SafeRoots -SystemProtectedRoots $SystemProtectedRoots -Mode $Mode -WhatIf $WhatIf
[System.IO.File]::WriteAllText($OutMd, $md, [System.Text.Encoding]::UTF8)

# 完整清单 CSV（逐文件，绝对路径不丢失，供一致性校验）
# 必须使用 List[string] 的 Add（O(1) 摊销），禁止用数组 += 拼接（退化为 O(n^2)）
$csvLines = [System.Collections.Generic.List[string]]::new()
[void]$csvLines.Add('"FullPath","SizeMB","Category","Reason","Intent","SafeRoot","SystemGuarded","Action"')
foreach ($it in $planDelete) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Delete', '', 'False', '拟删除'))) }
foreach ($it in $planConfirm) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Confirm', '', 'False', '待确认'))) }
foreach ($it in $planSafe) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Safe', $it.SafeRoot, 'False', '安全根二次确认'))) }
foreach ($it in $planGuarded) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Guarded', '', 'True', '系统核心降级待确认'))) }
[System.IO.File]::WriteAllText($OutCsv, ($csvLines -join "`r`n"), [System.Text.Encoding]::UTF8)

Write-Output ('已生成 Markdown 报告: {0}' -f $OutMd)
Write-Output ('已生成完整清单 CSV: {0}' -f $OutCsv)

$delSize = ($planDelete | Measure-Object -Property SizeMB -Sum).Sum
$conSize = ($planConfirm | Measure-Object -Property SizeMB -Sum).Sum
$safeSize = ($planSafe | Measure-Object -Property SizeMB -Sum).Sum
$guardSize = ($planGuarded | Measure-Object -Property SizeMB -Sum).Sum
Write-Output ('确定拟删除: {0} 个 / {1:N2} MB' -f $planDelete.Count, $delSize)
Write-Output ('待确认: {0} 个 / {1:N2} MB' -f $planConfirm.Count, $conSize)
Write-Output ('安全根二次确认: {0} 个 / {1:N2} MB' -f $planSafe.Count, $safeSize)
Write-Output ('系统核心降级待确认: {0} 个 / {1:N2} MB' -f $planGuarded.Count, $guardSize)
Write-Output ('已跳过(保留/否/受保护/未知): {0} 个' -f $skippedKeep)

# ===================== 执行删除（仅 Execute 模式） =====================
function Remove-OneItem {
    param($It)
    if (-not (Test-Path -LiteralPath $It.Path)) { return 'missing' }
    $isDir = $false
    try { $isDir = (Get-Item -LiteralPath $It.Path -ErrorAction Stop) -is [System.IO.DirectoryInfo] }
    catch { Write-Warning ('无法访问: {0} - {1}' -f $It.Path, $_.Exception.Message); return 'fail' }
    try {
        # F3 修复：目录显式 -Recurse；文件仅 -Force（不递归）
        if ($isDir) { Remove-Item -LiteralPath $It.Path -Recurse -Force -ErrorAction Stop }
        else { Remove-Item -LiteralPath $It.Path -Force -ErrorAction Stop }
        return 'ok'
    }
    catch {
        Write-Warning ('删除失败: {0} - {1}' -f $It.Path, $_.Exception.Message)
        return 'fail'
    }
}

$dirConfirmCache = @{}
function Confirm-Dir {
    param([string]$Dir)
    if ($dirConfirmCache.ContainsKey($Dir)) { return $dirConfirmCache[$Dir] }
    if ($script:WhatIf) { $dirConfirmCache[$Dir] = $true; return $true }   # WhatIf 下不弹确认，直接视为将删（仅报告）
    $ans = Read-Host ('是否递归删除目录 [{0}] ? (y/N)' -f $Dir)
    $ok = ($ans -match '^[yY]')
    $dirConfirmCache[$Dir] = $ok
    return $ok
}

function Invoke-DeleteBatch {
    param($Items, [bool]$RequireDirConfirm, [bool]$WhatIf, [string]$Label)
    $ok = 0; $fail = 0; $skip = 0
    foreach ($it in $Items) {
        if (-not (Test-Path -LiteralPath $it.Path)) { $skip++; continue }
        $isDir = (Get-Item -LiteralPath $it.Path) -is [System.IO.DirectoryInfo]
        # F3 修复：目录型路径在删除前按目录二次确认（防止误整树删除）
        if ($isDir -and $RequireDirConfirm) {
            $parent = Split-Path $it.Path -Parent
            if (-not (Confirm-Dir -Dir $parent)) {
                Write-Output ('已跳过目录 [{0}]' -f $parent)
                $skip++; continue
            }
        }
        if ($WhatIf) {
            # WhatIf 模拟：仅报告，不实际删除；用 Write-Output 保证控制台与重定向日志均可见
            Write-Output ('WhatIf: 将删除 {0} [{1}]' -f $(if ($isDir) { '目录' } else { '文件' }), $it.Path)
            $ok++; continue
        }
        $r = Remove-OneItem -It $it
        switch ($r) {
            'ok' { $ok++ }
            'fail' { $fail++ }
            'missing' { $skip++ }
        }
    }
    Write-Output ('{0}: 成功 {1}，失败 {2}，跳过 {3}' -f $Label, $ok, $fail, $skip)
}

if ($Mode -eq 'Execute') {
    Write-Output '===== 进入执行删除模式 ====='
    if ($WhatIf) { Write-Output '（WhatIf 已启用：仅模拟删除，不实际删除任何文件，不弹出交互确认）' }

    # 1. 确定拟删除（非安全根、非系统核心）：目录型按目录确认
    Invoke-DeleteBatch -Items $planDelete -RequireDirConfirm $true -WhatIf $WhatIf -Label '自动清理删除'

    # 2. 需确认项 / 系统核心降级项（仅当显式 -DeleteConfirmed）
    if ($DeleteConfirmed) {
        Invoke-DeleteBatch -Items $planConfirm -RequireDirConfirm $true -WhatIf $WhatIf -Label '需确认项(已授权)删除'
        Invoke-DeleteBatch -Items $planGuarded -RequireDirConfirm $true -WhatIf $WhatIf -Label '系统核心降级项(已授权)删除'
    }
    else {
        Write-Output ('非安全根需确认项 {0} 个、系统核心降级项 {1} 个默认跳过（未删除）。' -f $planConfirm.Count, $planGuarded.Count)
    }

    # 3. 安全根项：按目录批量交互确认（始终需显式 y；不静默删）
    if ($planSafe.Count -gt 0) {
        Invoke-DeleteBatch -Items $planSafe -RequireDirConfirm $true -WhatIf $WhatIf -Label '安全根目录删除'
    }
}
else {
    Write-Output '===== DryRun 模式：未删除任何文件 ====='
}
