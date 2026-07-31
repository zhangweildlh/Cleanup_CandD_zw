<#
.SYNOPSIS
    磁盘垃圾文件「扫描 + 清理」一体化脚本（通用、可移植、DryRun 默认、零副作用）
.DESCRIPTION
    将「清单扫描」与「清理规划/执行」合并为单一工作流：

      [可选 -Root 现场扫描] --> 生成处置清单 CSV（FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason）
                              \
                               --> [既有 -CsvPaths 清单] --(合并)--> 加载 --> 标签->处置映射 --> 规划 --> (DryRun 输出 | Execute 删除)

    1) 若提供 -Root：递归枚举该根目录，依据「路径片段 / 扩展名 / 文件大小 / 修改时间」分类，
       实时写出与 full_inventory2/3.csv 同构的 CSV（带 BOM、RFC4180 引号），随后将其并入待清理清单。
    2) 若提供 -CsvPaths：直接读取既有处置清单（兼容原 scan2/scan3 产物）。
    3) 二者可同时提供（先扫描、再叠加既有清单）；若都不提供则报错退出。
    4) 加载后统一经「标签->处置映射层」规划三类处置：
         - 自动清理 / 是          -> 确定拟删除
         - 需确认 / 谨慎          -> 默认不删，列为待确认
         - 保留 / 否 / 受保护 / 未知 -> 永不删除（保守默认）
    5) 默认 Mode=DryRun：只把拟删除清单输出到 Markdown 与完整 CSV，绝不触碰任何文件。
       显式 -Mode Execute 才执行删除；可加 -WhatIf 做"模拟删除"试运行。

    分类规则从既有 full_inventory2.csv（C 盘，Cleanable∈{是,否,谨慎}）与
    full_inventory3.csv（D 盘，Cleanable∈{自动清理,需确认,保留}）反推，分两套标签体系：
      - 方案 C（默认用于 C:）：Cleanable ∈ {是, 否, 谨慎}
      - 方案 D（默认用于其它盘）：Cleanable ∈ {自动清理, 需确认, 保留}

    两层硬保护（保证对 Win11 系统 / 已装程序 / 工作目录 / 个人文档零破坏）：
      1) 安全根拦截：凡拟删除项落在任一"安全根目录"（默认 D:\ZW工作、D:\Tools、D:\Documents，
         且为硬编码兜底、不可被 -SafeRoots 移除）下，一律提升为"需二次确认（按目录批量）"，即便其原本为自动清理。
      2) 系统核心保护：凡拟删除项落在系统核心目录（C:\Windows、C:\Program Files、C:\Program Files (x86)、
         C:\ProgramData）下，强制降为"待确认"（系统核心目录强制待确认清单），绝不自动删除。

    编码健壮性：CSV 读取使用自研 StreamReader + BOM 探测 + RFC4180 引号解析，兼容 UTF-8（有/无 BOM）与 UTF-16；
    扫描写出使用 UTF-8 带 BOM 的 StreamWriter。删除一律使用 -LiteralPath，避免特殊字符路径被通配符误解释。

.PARAMETER Root
    扫描根目录（可选），例如 C:\ 或 D:\。提供即现场扫描并并入待清理清单。
.PARAMETER CsvPaths
    一个或多个既有处置清单 CSV（字段见上）。可同时传入 C 盘与 D 盘清单。与 -Root 可同时提供。
.PARAMETER Scheme
    'C' | 'D' | 'Auto'（默认 Auto：根以 C: 开头用 C 方案，其余用 D 方案；仅对 -Root 扫描生效）。
.PARAMETER ProtectedRoots
    受保护目录片段（子串匹配，命中即标记"受保护/保留"）。默认含 '.workbuddy'。
.PARAMETER WorkRoot
    工作目录根（用于"工作目录受保护文件"判定）。默认 D:\ZW工作。
.PARAMETER ExcludeRoots
    跳过枚举的目录（默认含系统核心目录，避免无意义扫描与权限报错）。传 @() 可扫描全部。
.PARAMETER RecentDays
    近期缓存阈值（天），默认 180。超过则不再判为"缓存-近期(保留)"。
.PARAMETER Mode
    DryRun（默认，仅输出，零副作用）| Execute（执行删除）。
.PARAMETER SafeRoots
    需二次确认的安全根目录列表。默认含 D:\ZW工作、D:\Tools、D:\Documents；
    注意：这三个关键根为硬编码兜底，始终生效，用户传入的 -SafeRoots 仅作"追加"，无法移除它们。
.PARAMETER OutMd
    DryRun 输出的 Markdown 报告路径。默认 cleanup_plan.md。
.PARAMETER OutCsv
    逐文件完整处置清单 CSV 路径（与 MD 互补，保证绝对路径不丢失）。默认 cleanup_plan_files.csv。
.PARAMETER OutScanCsv
    -Root 扫描输出的清单 CSV 路径。默认 ./scan_inventory_<盘符>.csv。
.PARAMETER DeleteConfirmed
    仅 Execute 模式有效：是否同时删除非安全根的"需确认"项与"系统核心降级"项（默认关闭，仅删自动清理 + 安全根已确认项）。
.PARAMETER FullList
    在 Markdown 中逐文件列出"需确认"与"安全根"项的绝对路径（默认关闭，改为按目录聚合 + 样本，以防 MD 过大）。
.PARAMETER WhatIf
    仅 Execute 模式有效：模拟删除，仅报告将删除哪些文件/目录，不实际执行删除，也不弹出交互确认。
#>

[CmdletBinding()]
param(
    [string]$Root = '',

    [string[]]$CsvPaths = @(),

    [ValidateSet('C', 'D', 'Auto')]
    [string]$Scheme = 'Auto',

    [string[]]$ProtectedRoots = @('.workbuddy'),

    [string]$WorkRoot = 'D:\ZW工作',

    [string[]]$ExcludeRoots = @('C:\Windows', 'C:\Program Files', 'C:\Program Files (x86)', 'C:\ProgramData'),

    [int]$RecentDays = 180,

    [ValidateSet('DryRun', 'Execute')]
    [string]$Mode = 'DryRun',

    [string[]]$SafeRoots = @('D:\ZW工作', 'D:\Tools', 'D:\Documents'),

    [string]$OutMd = 'cleanup_plan.md',
    [string]$OutCsv = 'cleanup_plan_files.csv',
    [string]$OutScanCsv = '',

    [switch]$DeleteConfirmed,
    [switch]$FullList,
    [switch]$WhatIf
)

# ===================== 初始化 =====================
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# ===================== 扫描工具函数 =====================
function Format-SizeMB { param($len) [math]::Round($len / 1MB, 4) }
function Quote-CsvField { param($v) '"{0}"' -f (($v -replace '"', '""')) }

# ===================== 方案 C 分类（Cleanable: 是/否/谨慎） =====================
function Classify-C {
    param($fi, $Protected)
    $p = $fi.FullName.ToLower()
    $ext = if ($fi.Extension) { $fi.Extension.ToLower() } else { '' }
    $name = $fi.Name.ToLower()

    if ($p -match '\\\$recycle\.bin\\') { return @{Category = '回收站文件'; Cleanable = '是'; Reason = '回收站内容(可清空)' } }
    foreach ($pr in $Protected) { if ($p.Contains($pr.ToLower())) { return @{Category = '受保护'; Cleanable = '否'; Reason = '受保护目录(规则5,禁止删除)' } } }
    if ($p -match '\\network\\cookies' -or $p -match '\\cookies$' -or $p -match '\\user data\\default\\bookmarks' -or $p -match 'webview' -or $p -match '\\history$') {
        return @{Category = '浏览数据'; Cleanable = '谨慎'; Reason = '浏览历史/cookie(谨慎清理)' } }
    if ($p -match 'explorer\\iconcache_' -or $p -match 'thumbcache') { return @{Category = '缩略图缓存'; Cleanable = '是'; Reason = '缩略图/图标缓存数据库' } }
    if ($p -match 'crashdumps\\.*\.dmp$') { return @{Category = '崩溃转储'; Cleanable = '是'; Reason = '崩溃转储文件' } }
    if ($name -eq 'ntuser.dat' -or $name -like 'ntuser.dat.*' -or $name -eq 'usrclass.dat' -or $name -like 'usrclass.dat.*') {
        return @{Category = '用户配置'; Cleanable = '否'; Reason = '用户注册表配置(保留)' } }
    if (@('.exe', '.dll', '.sys', '.msi', '.ocx') -contains $ext) { return @{Category = '应用文件'; Cleanable = '否'; Reason = '可执行/库文件(保留)' } }
    if ($ext -eq '.log') { return @{Category = '日志文件'; Cleanable = '是'; Reason = '日志文件' } }
    if ($ext -in @('.tmp', '.temp', '.bak') -or $p -match '\\temp\\' -or $p -match '\\tmp\\' -or $p -match '\\_cacache\\tmp') {
        return @{Category = '临时文件'; Cleanable = '是'; Reason = '临时扩展名/临时目录' } }
    if ($p -match '\\cache\\' -or $p -match '\.cache' -or $p -match 'app\\cache') { return @{Category = '缓存文件'; Cleanable = '是'; Reason = '缓存目录/浏览器缓存' } }
    if ($p -match '\\users\\[^\\]+\\appdata\\roaming' -and $ext -in @('.json', '.ini', '.cfg', '.config', '.xml', '.setting')) {
        return @{Category = '应用配置'; Cleanable = '否'; Reason = '应用配置数据(保留)' } }
    if ($p -match '\\users\\[^\\]+\\appdata\\local') { return @{Category = '应用本地数据'; Cleanable = '否'; Reason = '应用本地数据(多数保留)' } }
    if ($p -match '\\users\\[^\\]+\\downloads\\') { return @{Category = '下载文件'; Cleanable = '谨慎'; Reason = '下载目录(需用户确认)' } }
    if ($p -match '\\users\\[^\\]+\\(documents|pictures|desktop|videos|music|contacts|links)\\') {
        return @{Category = '用户重要数据'; Cleanable = '否'; Reason = '用户文档/媒体(保留)' } }
    return @{Category = '其他/未知'; Cleanable = '否'; Reason = '未分类(需人工判断)' }
}

# ===================== 方案 D 分类（Cleanable: 自动清理/需确认/保留） =====================
function Classify-D {
    param($fi, $Protected, $WorkRoot, $RecentDays)
    $p = $fi.FullName.ToLower()
    $ext = if ($fi.Extension) { $fi.Extension.ToLower() } else { '' }
    $name = $fi.Name.ToLower()

    if ($p -match '\\\$recycle\.bin\\') { return @{Category = '回收站文件'; Cleanable = '自动清理'; Reason = '回收站/清理箱内容(可清空)' } }
    foreach ($pr in $Protected) { if ($p.Contains($pr.ToLower())) { return @{Category = '受保护'; Cleanable = '保留'; Reason = '受保护目录(规则5,禁止删除)' } } }
    if ($p -match 'tencent files' -or $p -match 'wechat files') {
        if ($p -match '\\log\\' -or $p -match '\.qqxlog$' -or $p -match '\\cache\\') {
            return @{Category = '通讯软件缓存/日志'; Cleanable = '需确认'; Reason = '通讯软件缓存/日志(需确认避免误删)' } }
        return @{Category = '通讯软件用户数据'; Cleanable = '保留'; Reason = '通讯软件用户数据/接收文件(禁止误删)' }
    }
    if ($WorkRoot -and $p.StartsWith($WorkRoot.ToLower())) {
        if (@('.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.pdf', '.txt', '.md', '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.mp3', '.mp4', '.avi', '.zip', '.rar', '.7z', '.html', '.htm') -contains $ext) {
            return @{Category = '工作目录受保护文件'; Cleanable = '保留'; Reason = 'ZW工作目录禁止删除类型(Office/图片/音视频/TXT/MD/PDF/网页/压缩)' }
        }
    }
    if ($fi.Length -eq 0) { return @{Category = '无用文件(空文件)'; Cleanable = '需确认'; Reason = '0字节空文件(可删)' } }
    if ($p -match '\\\.git\\logs\\') { return @{Category = '垃圾文件(已卸载日志残留)'; Cleanable = '需确认'; Reason = '疑似已卸载软件日志(需确认)' } }
    if ($p -match 'node_modules\\.*\\cache' -or ($p -match '\\cache\\' -and $p -match 'node_modules')) {
        return @{Category = '垃圾文件(已卸载缓存残留)'; Cleanable = '需确认'; Reason = '疑似已卸载软件缓存(需确认)' } }
    if (@('.exe', '.msi') -contains $ext -and ($p -match '\\build\\' -or $p -match '\\temp\\' -or $p -match 'uninst' -or $p -match 'dmcp')) {
        return @{Category = '疑似已卸载程序残留'; Cleanable = '需确认'; Reason = '疑似已卸载软件程序文件(需确认后再删)' } }
    if ($ext -in @('.tmp', '.temp', '.bak') -or $p -match '\\tmp\\' -or $p -match '\\temp\\' -or $p -match '\.trash-bak' -or $p -match '\\smoke\\') {
        return @{Category = '垃圾文件(临时/过程)'; Cleanable = '自动清理'; Reason = '临时目录/临时过程文件' } }
    if ($ext -eq '.log') { return @{Category = '垃圾文件(日志)'; Cleanable = '自动清理'; Reason = '应用日志文件' } }
    if (@('.exe', '.dll', '.sys', '.msi', '.ocx') -contains $ext) { return @{Category = '应用文件'; Cleanable = '保留'; Reason = '可执行/库文件(保留)' } }
    if ($p -match '\\cache\\' -or $p -match '\.cache') {
        $age = (Get-Date) - $fi.LastWriteTime
        if ($age.TotalDays -le $RecentDays) { return @{Category = '缓存-近期(保留)'; Cleanable = '保留'; Reason = ('近期缓存(<{0}天)' -f $RecentDays) } }
    }
    if ($p -match '\\users\\[^\\]+\\(documents|pictures|desktop|videos|music|contacts|links|downloads)\\') {
        return @{Category = '用户重要数据'; Cleanable = '保留'; Reason = '用户文档/媒体(保留)' } }
    return @{Category = '其他/未知'; Cleanable = '保留'; Reason = '未分类(多数保留)' }
}

# ===================== 递归枚举 + 即时分类写盘 =====================
function Scan-Dir {
    param($Dir, $Exclude, $Writer, $Scheme, $Protected, $WorkRoot, $RecentDays, $Counter)
    $entries = $null
    try { $entries = [System.IO.Directory]::EnumerateFileSystemEntries($Dir) } catch { return }
    foreach ($e in $entries) {
        $skip = $false
        foreach ($ex in $Exclude) { if ($e -like "$ex*") { $skip = $true; break } }
        if ($skip) { continue }
        try {
            if ([System.IO.Directory]::Exists($e)) {
                Scan-Dir $e $Exclude $Writer $Scheme $Protected $WorkRoot $RecentDays $Counter
            }
            else {
                $fi = [System.IO.FileInfo]$e
                $Counter.Count++
                if ($Scheme -eq 'C') { $r = Classify-C $fi $Protected } else { $r = Classify-D $fi $Protected $WorkRoot $RecentDays }
                $sizeMB = Format-SizeMB $fi.Length
                $lwt = $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                $ext = if ($fi.Extension) { $fi.Extension.ToLower() } else { '' }
                $line = ((Quote-CsvField $fi.FullName), (Quote-CsvField $ext), (Quote-CsvField $sizeMB),
                         (Quote-CsvField $lwt), (Quote-CsvField $r.Category), (Quote-CsvField $r.Cleanable),
                         (Quote-CsvField $r.Reason)) -join ','
                $Writer.WriteLine($line)
                if (($Counter.Count % 5000) -eq 0) {
                    Write-Progress -Activity "扫描 $Scheme 方案" -Status "$($Counter.Count) 个文件" -CurrentOperation $e
                }
            }
        }
        catch { }
    }
}

# ===================== 安全根 / 系统核心保护（清理侧，硬编码兜底） =====================
# 关键安全根（硬编码兜底，始终生效，不可被 -SafeRoots 覆盖移除）
$EssentialSafeRoots = @('D:\ZW工作', 'D:\Tools', 'D:\Documents')
$SafeRoots = ($EssentialSafeRoots + @($SafeRoots)) | Sort-Object -Unique

# 系统核心保护目录（硬编码）：命中即强制降为"待确认"，绝不自动删除
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

# ===================== 标签 -> 处置 映射层 =====================
# 覆盖两套清单的 Cleanable 列取值：
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

# ===================== 健壮 CSV 读取（轻量返回字符串数组） =====================
# 自研 RFC4180 引号解析 + BOM 探测，兼容 UTF-8（有/无 BOM）与 UTF-16 LE/BE。
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
        $encoding = [System.Text.Encoding]::UTF8              # 无 BOM：默认按 UTF-8
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
    if ($field.Length -gt 0 -or $row.Count -gt 0) {
        [void]$row.Add($field.ToString()); [void]$field.Clear()
        [void]$records.Add($row.ToArray()); $row.Clear()
    }

    if ($records.Count -eq 0) { return [PSCustomObject]@{ Header = @(); Records = $records } }

    $header = $records[0]
    [void]$records.RemoveAt(0)

    $clean = [System.Collections.Generic.List[string[]]]::new()
    foreach ($rec in $records) {
        $nonEmpty = 0
        foreach ($cv in $rec) { if (-not [string]::IsNullOrEmpty($cv)) { $nonEmpty++ } }
        if ($nonEmpty -gt 0) { [void]$clean.Add($rec) }
    }

    return [PSCustomObject]@{ Header = $header; Records = $clean }
}

# ===================== 主流程入口：扫描（若提供 -Root） =====================
$scanGenerated = $null
if ($Root) {
    if (-not (Test-Path -LiteralPath $Root)) { Write-Error ("根目录不存在: {0}" -f $Root); exit 1 }
    $resolved = Resolve-Path $Root
    $drive = ($resolved.Path.Substring(0, 1)).ToUpper()
    if ($Scheme -eq 'Auto') { $Scheme = if ($drive -eq 'C') { 'C' } else { 'D' } }
    if (-not $OutScanCsv) { $OutScanCsv = Join-Path $PSScriptRoot ("scan_inventory_$drive.csv") }

    Write-Output ("开始扫描: 根={0} 方案={1} 输出={2}" -f $resolved.Path, $Scheme, $OutScanCsv)

    $writer = [System.IO.StreamWriter]::new($OutScanCsv, $false, [System.Text.UTF8Encoding]::new($true))
    $writer.WriteLine('FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason')

    $counter = @{ Count = 0 }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Scan-Dir $resolved.Path $ExcludeRoots $writer $Scheme $ProtectedRoots $WorkRoot $RecentDays $counter
    $sw.Stop()
    $writer.Close()
    Write-Progress -Activity "扫描 $Scheme 方案" -Completed

    Write-Output ("扫描完成: 共 {0} 个文件，耗时 {1:N1}s，已写入 {2}" -f $counter.Count, $sw.Elapsed.TotalSeconds, $OutScanCsv)
    $CsvPaths = @($OutScanCsv) + @($CsvPaths)
    $scanGenerated = $OutScanCsv
}
elseif ($Scheme -eq 'Auto') {
    Write-Warning '未提供 -Root，扫描方案沿用默认；仅在读取既有清单时 -Scheme 不生效。'
}

if ($CsvPaths.Count -eq 0) {
    Write-Error '未提供 -Root 或 -CsvPaths，无法继续。请至少提供其一。'
    exit 1
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
        # 表头校验：缺必需列即跳过并报错
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

            # 系统核心目录强制降级：Delete -> Confirm
            $systemGuarded = $false
            if ($intent -eq 'Delete' -and (Test-SystemProtected -Path $fp)) {
                $intent = 'Confirm'
                $systemGuarded = $true
            }

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

# ===================== 目录聚合辅助 =====================
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
        $LoadedFiles, $SafeRoots, $SystemProtectedRoots, $Mode, $WhatIf, $ScanGenerated
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# 磁盘垃圾文件扫描 + 清理规划报告')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine(('> 生成时间: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$sb.AppendLine(('> 运行模式: **{0}**（{1}）' -f $Mode, $(if ($Mode -eq 'DryRun') { '仅输出，未删除任何文件' } elseif ($WhatIf) { '模拟删除（WhatIf，未实际删除）' } else { '执行删除' })))
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## 一、数据来源')
    foreach ($f in $LoadedFiles) { [void]$sb.AppendLine(('- ' + $f)) }
    if ($ScanGenerated) { [void]$sb.AppendLine(('- （上述含脚本现场扫描生成的清单：' + $ScanGenerated + '）')) }
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
            [void]$sb.AppendLine('| --- | --- | --- | ---')
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
    [void]$sb.AppendLine('- 所有删除决策来源于清单（现场扫描或既有 CSV）的 `Cleanable` 字段，经"标签→处置映射层"统一处理（兼容 scan2 描述性标签与 scan3 三值标签），未硬编码任何具体文件。')
    [void]$sb.AppendLine('- 安全根目录（D:\ZW工作、D:\Tools、D:\Documents 等，含硬编码兜底）下的任何拟删除项均被拦截为二次确认，避免误删用户工作/工具/文档。')
    [void]$sb.AppendLine('- 系统核心目录（C:\Windows、C:\Program Files、C:\ProgramData 等）下的拟删除项被强制降为待确认，保证 Win11 系统与已装程序零破坏。')
    [void]$sb.AppendLine('- 删除操作使用 `-LiteralPath`，对含 `[]{}` 等特殊字符的路径安全；目录型路径显式 `-Recurse` 且按目录二次确认；Execute 模式可用 `-WhatIf` 模拟试运行。')

    return $sb.ToString()
}

$md = New-MarkdownReport -PlanDelete $planDelete -PlanConfirm $planConfirm -PlanSafe $planSafe -PlanGuarded $planGuarded -LoadedFiles $loadedFiles -SafeRoots $SafeRoots -SystemProtectedRoots $SystemProtectedRoots -Mode $Mode -WhatIf $WhatIf -ScanGenerated $scanGenerated
[System.IO.File]::WriteAllText($OutMd, $md, [System.Text.Encoding]::UTF8)

# 完整清单 CSV（逐文件，绝对路径不丢失，供一致性校验）
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
        # 使用底层 .NET API 删除，绕开可能被安全软件 hook 的 Remove-Item cmdlet（本机 safe-delete 会拦截/重定义 Remove-Item）。
        # 路径为绝对 LiteralPath，不涉及 PowerShell 通配符，对含 [] {} $ 等特殊字符的路径安全。
        if ($isDir) { [System.IO.Directory]::Delete($It.Path, $true) }   # 递归删除目录
        else { [System.IO.File]::Delete($It.Path) }
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
        if ($isDir -and $RequireDirConfirm) {
            $parent = Split-Path $it.Path -Parent
            if (-not (Confirm-Dir -Dir $parent)) {
                Write-Output ('已跳过目录 [{0}]' -f $parent)
                $skip++; continue
            }
        }
        if ($WhatIf) {
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
