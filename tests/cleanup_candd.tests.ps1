<#
.SYNOPSIS
  Cleanup_CandD_zw 仓库 Pester 测试套件（Pester 3.4.0 语法）
.DESCRIPTION
  覆盖两类核心逻辑，采用黑盒方式（用受控 .ini / .csv 驱动脚本，断言其产物 CSV / 标准输出），
  不依赖脚本内部函数导出，避免改动业务脚本：

    A) winapp2_expand.ps1 —— Winapp2 规则解析 / 分类 / 展开
       - F-3 核心：Default 键语义、节名 * 显示名剥离、元数据节跳过
       - 全功能：ExcludeKey 豁免(FILE/PATH)、Detect/DetectFile/SpecialDetect 门控、
                 变量展开、RECURSE/REMOVESELF、MaxEntries、LangSecRef 分类映射、
                 多值 FileKey、注释行跳过、空节/无目标过滤、RegKey 处理
    B) cleanup_cd.ps1 —— 扫描 + 标签映射 + 双层硬保护 + DryRun 零删除
       - 全功能：多 CSV 合并、Scheme C 标签映射、未知标签 Keep、版本控制兜底、
                 系统核心降级、AllowSystemJunk 恢复、受保护片段、安全根、Scheme D 现场扫描
       - 全边界：UTF-16/UTF-8 无 BOM 编码读取、缺必需列跳过、空数据/无入口 exit 1

  编码说明（PS 5.1 陷阱已在辅助函数中规避）：
    - Invoke-Expand 用 -NoEnumerate 保住数组契约（单结果行时裸 return 会被拆包为标量）。
    - Where-Object 匹配结果用 @() 包成数组后再取 .Count（单匹配返回标量，.Count 为 $null）。
    - 探测文件写入 %Temp%（GetTempPath），与 winapp2_expand 内部展开来源一致。
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $here '..')
$expandScript = Join-Path $repoRoot 'winapp2_expand.ps1'
$cleanupScript = Join-Path $repoRoot 'cleanup_cd.ps1'
# 与 winapp2_expand.ps1 内部展开 %Temp% 的来源保持一致，避免探测文件错位。
$tmp = [System.IO.Path]::GetTempPath()

# ===================== 公共辅助 =====================

# 准备探测文件（让 DetectFile 通过，使条目被判定为"已装"而产出处置行）
$marker = Join-Path $tmp 'zw_pester_marker.txt'
$dir = Join-Path $tmp 'zw_pester_dir'
New-Item -ItemType File -Path $marker -Force | Out-Null
New-Item -ItemType Directory -Path $dir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $dir 'a.tmp') -Force | Out-Null

# 运行 winapp2_expand.ps1，返回处置行数组（PSCustomObject[]，含 FullPath/Category/Cleanable/Reason）
function Invoke-Expand {
    param([string]$iniContent, [hashtable]$Extra = @{})
    $ini = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.ini')
    $csv = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.csv')
    [System.IO.File]::WriteAllText($ini, $iniContent, [System.Text.UTF8Encoding]::new($false))
    $params = @{ Winapp2Path = $ini; OutCsv = $csv }
    foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] }
    & $expandScript @params | Out-Null
    $rows = @(Import-Csv $csv)
    Remove-Item $ini -Force -ErrorAction SilentlyContinue
    Remove-Item $csv -Force -ErrorAction SilentlyContinue
    # -NoEnumerate 确保无论结果行数多少，调用方始终拿到真正的数组（F-2 曾失败的根因）。
    Write-Output -NoEnumerate $rows
}

# 写一份 CSV 到临时目录并返回路径（默认 UTF-8 无 BOM；可用 -Encoding 指定）
function New-TempCsv {
    param([string]$content, [System.Text.Encoding]$Encoding = $null)
    $p = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.csv')
    if ($null -eq $Encoding) { [System.IO.File]::WriteAllText($p, $content, [System.Text.UTF8Encoding]::new($false)) }
    else { [System.IO.File]::WriteAllText($p, $content, $Encoding) }
    return $p
}

# 运行 cleanup_cd.ps1，返回 @{ Output, OutCsv, OutMd, Code }
function Invoke-Cleanup {
    param([string[]]$CsvPaths, [string]$Scheme = 'Auto', [string]$Mode = 'DryRun', [hashtable]$Extra = @{})
    $outMd = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.md')
    $outCsv = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '_files.csv')
    $params = @{ CsvPaths = $CsvPaths; Mode = $Mode; Scheme = $Scheme; OutMd = $outMd; OutCsv = $outCsv }
    foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] }
    $output = & $cleanupScript @params 2>&1
    $code = $LASTEXITCODE
    $output = $output | Out-String
    return @{ Output = $output; OutCsv = $outCsv; OutMd = $outMd; Code = $code }
}

# 标准 CSV 表头（与 cleanup_cd 输出同构）
$csvHeader = '"FullPath","Extension","SizeMB","LastWriteTime","Category","Cleanable","Reason"'

# ===================== A) winapp2_expand.ps1 =====================

Describe 'winapp2_expand.ps1 — Default 键语义与分类（F-3 核心）' {

    $ini = @'
[ZW Disabled By Key]
LangSecRef=3021
Default=False
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[ZW Enabled No Key]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[ZW Enabled By Key True]
LangSecRef=3021
Default=True
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@

    It '保守模式（不开 AutoDelete）：全部标为"需确认"' {
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Cleanable -ne '需确认' })).Count | Should Be 0
    }

    It 'AutoDelete 模式：Default=False -> 需确认；无键 / Default=True -> 自动清理' {
        $rows = Invoke-Expand -iniContent $ini -Extra @{ Winapp2AutoDelete = $true }
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Reason -like '*ZW Disabled By Key' -and $_.Cleanable -ne '需确认' })).Count | Should Be 0
        (@($rows | Where-Object { $_.Reason -like '*ZW Enabled No Key' -and $_.Cleanable -ne '自动清理' })).Count | Should Be 0
        (@($rows | Where-Object { $_.Reason -like '*ZW Enabled By Key True' -and $_.Cleanable -ne '自动清理' })).Count | Should Be 0
    }
}

Describe 'winapp2_expand.ps1 — 节名 * 排版标记仅作显示名剥离（F-3）' {

    It '名尾 * 被剥离，不进入显示名（Reason）' {
        $ini = @'
[Google Chrome Caches *]
LangSecRef=3029
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Reason -match ' \*$' })).Count | Should Be 0
        (@($rows | Where-Object { $_.Reason -like '*Google Chrome Caches' })).Count | Should Be $rows.Count
    }
}

Describe 'winapp2_expand.ps1 — 元数据节跳过（F-2）' {

    It '[Winapp2] / [Version] 元数据节不展开，仅应用节产出' {
        $ini = @'
[Winapp2]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[Version]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[ZW Real App]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.Reason -like '*ZW Real App' })).Count | Should Be 1
    }
}

Describe 'winapp2_expand.ps1 — 边界：空节过滤 / 无目标过滤 / RegKey 处理 / 通配符检测' {

    It '空文件节（仅检测无清理目标）被 Test-Valid 过滤，不产生处置行' {
        $ini = @'
[ZW No Target]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 0
    }

    It '有检测无 FileKey（hasDetect 真 / hasTarget 假）被 Test-Valid 过滤' {
        $ini = @'
[ZW Detect Only]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 0
    }

    It 'RegKey 默认忽略（不开 -IncludeReg）：无 FileKey 的注册表条目不产生处置行' {
        $ini = @'
[ZW Reg Only]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
RegKey1=HKLM\Software\ZWTest\junk
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 0
    }

    It 'RegKey 开启 -IncludeReg：注册表条目列为"需确认"备注（cleanup_cd 不删注册表）' {
        $ini = @'
[ZW Reg Only]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
RegKey1=HKLM\Software\ZWTest\junk
'@
        $rows = Invoke-Expand -iniContent $ini -Extra @{ IncludeReg = $true }
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.Cleanable -ne '需确认' })).Count | Should Be 0
        (@($rows | Where-Object { $_.Reason -like '*注册表规则-仅备注*' })).Count | Should Be 1
    }

    It 'DetectFile 含通配符（目录|*.tmp）能正确判定已安装并产出处置行' {
        $ini = @'
[ZW Wildcard Detect]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_dir\*.tmp
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.Reason -like '*ZW Wildcard Detect' })).Count | Should Be 1
    }

    It 'DetectFile 指向不存在文件：条目被判定未安装、不产出处置行（检测门控边界）' {
        $ini = @'
[ZW Missing Detect]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_dir\no_such_marker_xyz.tmp
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 0
    }

    It 'SpecialDetect 为未知代码（DET_FAKE）：门控失败、条目被跳过' {
        $ini = @'
[ZW Fake Special]
LangSecRef=3021
SpecialDetect=DET_FAKE
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 0
    }
}

Describe 'winapp2_expand.ps1 — Detect 注册表门控（OR 门控之一）' {

    It 'Detect 注册表键存在则通过检测并产出处置行' {
        New-Item -Path 'HKCU:\Software\ZWTestCleanup\probe' -Force | Out-Null
        try {
            $ini = @'
[ZW Reg Detect]
LangSecRef=3021
Detect=HKCU\Software\ZWTestCleanup\probe
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
            $rows = Invoke-Expand -iniContent $ini
            $rows | Should Not BeNullOrEmpty
            $rows.Count | Should Be 1
        } finally {
            Remove-Item 'HKCU:\Software\ZWTestCleanup\probe' -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Detect 注册表键不存在则条目被判定未安装、不产出处置行' {
        Remove-Item 'HKCU:\Software\ZWTestCleanup\probe' -Recurse -Force -ErrorAction SilentlyContinue
        $ini = @'
[ZW Reg Detect Absent]
LangSecRef=3021
Detect=HKCU\Software\ZWTestCleanup\absent
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 0
    }
}

Describe 'winapp2_expand.ps1 — 变量展开 / RECURSE / REMOVESELF / 多值键' {

    It '变量展开：%Temp% 在 FileKey 路径中被展开为真实临时目录' {
        $ini = @'
[ZW Var Expand]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $resolved = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
        (@($rows | Where-Object { $_.FullPath.StartsWith($resolved, [System.StringComparison]::OrdinalIgnoreCase) })).Count | Should Be $rows.Count
    }

    It 'RECURSE：FileKey 通配符递归进入子目录产出深层文件' {
        $recDir = Join-Path $tmp 'zw_pester_rec'
        New-Item -ItemType Directory -Path $recDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $recDir 'top.tmp') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $recDir 'sub') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $recDir 'sub\deep.tmp') -Force | Out-Null
        $ini = @'
[ZW Recurse]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_rec|*.tmp|RECURSE
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 2
        (@($rows | Where-Object { $_.FullPath -like '*\top.tmp' })).Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\sub\deep.tmp' })).Count | Should Be 1
    }

    It 'REMOVESELF：目标为目录自身，产出目录路径（非其下文件）' {
        $rmDir = Join-Path $tmp 'zw_pester_rmself'
        New-Item -ItemType Directory -Path $rmDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $rmDir 'inside.tmp') -Force | Out-Null
        $ini = @'
[ZW RemoveSelf]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_rmself|REMOVESELF
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        $rows[0].FullPath | Should Be $rmDir
    }

    It '多值 FileKey（FileKey1/FileKey2）各自产出处置行' {
        $dir2 = Join-Path $tmp 'zw_pester_dir2'
        New-Item -ItemType Directory -Path $dir2 -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir2 'c.tmp') -Force | Out-Null
        $ini = @'
[ZW Multi FileKey]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
FileKey2=%Temp%\zw_pester_dir2|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 2
        (@($rows | Where-Object { $_.FullPath -like '*\zw_pester_dir\a.tmp' })).Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\zw_pester_dir2\c.tmp' })).Count | Should Be 1
    }
}

Describe 'winapp2_expand.ps1 — ExcludeKey 豁免（最高优先级白名单）' {

    It 'ExcludeKey FILE：直接子项按名匹配被排除，同目录其它文件保留' {
        $exDir = Join-Path $tmp 'zw_pester_excl'
        New-Item -ItemType Directory -Path $exDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $exDir 'keep.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $exDir 'skipme.tmp') -Force | Out-Null
        $ini = @'
[ZW Excl File]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_excl|*.tmp
ExcludeKey1=FILE|%Temp%\zw_pester_excl|skipme.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\keep.tmp' })).Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\skipme.tmp' })).Count | Should Be 0
    }

    It 'ExcludeKey PATH：整个子树被排除，根目录文件保留' {
        $pDir = Join-Path $tmp 'zw_pester_path'
        New-Item -ItemType Directory -Path $pDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $pDir 'root.tmp') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $pDir 'sub') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $pDir 'sub\deep.tmp') -Force | Out-Null
        $ini = @'
[ZW Excl Path]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_path|*.tmp
ExcludeKey1=PATH|%Temp%\zw_pester_path\sub
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\root.tmp' })).Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\sub\deep.tmp' })).Count | Should Be 0
    }
}

Describe 'winapp2_expand.ps1 — LangSecRef 分类映射 / MaxEntries / 注释行' {

    It 'LangSecRef=3021 映射为分类 "Applications"' {
        $ini = @'
[ZW Category]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Category -eq 'Applications' })).Count | Should Be $rows.Count
    }

    It 'MaxEntries=1：仅处理首条已装应用（规模冒烟边界）' {
        $ini = @'
[ZW App One]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[ZW App Two]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[ZW App Three]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        # 不开 MaxEntries：3 条全部产出（每条 1 行）
        $full = Invoke-Expand -iniContent $ini
        $full.Count | Should Be 3
        # 开 MaxEntries=1：只处理首条
        $limited = Invoke-Expand -iniContent $ini -Extra @{ MaxEntries = 1 }
        $limited.Count | Should Be 1
    }

    It '注释行（; 与 #）被跳过，不影响条目解析' {
        $ini = @'
; 这是一条注释
# 这也是注释
[ZW With Comments]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.Reason -like '*ZW With Comments' })).Count | Should Be 1
    }

    It '输出 CSV 同构（表头为 FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason）' {
        $ini = @'
[ZW Header Check]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $csvOut = Join-Path $tmp ('zw_pester_hdr_' + [guid]::NewGuid().ToString('N') + '.csv')
        $params = @{ Winapp2Path = (Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.ini')) ; OutCsv = $csvOut }
        [System.IO.File]::WriteAllText($params.Winapp2Path, $ini, [System.Text.UTF8Encoding]::new($false))
        & $expandScript @params | Out-Null
        $hdr = (Get-Content -LiteralPath $csvOut -Encoding UTF8 | Select-Object -First 1)
        $hdr | Should Be '"FullPath","Extension","SizeMB","LastWriteTime","Category","Cleanable","Reason"'
        Remove-Item $params.Winapp2Path -Force -ErrorAction SilentlyContinue
        Remove-Item $csvOut -Force -ErrorAction SilentlyContinue
    }
}

# ===================== B) cleanup_cd.ps1 =====================

Describe 'cleanup_cd.ps1 — 双层硬保护 + DryRun 零删除' {

    $baseCsv = @"
$csvHeader
"C:\Windows\System32\junk.dll",".dll","0","2026-01-01 00:00:00","Windows","自动清理","系统核心"
"D:\ZW工作\mydoc.txt",".txt","0","2026-01-01 00:00:00","Applications","自动清理","安全根"
"D:\Temp\realjunk.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Temp\keep.txt",".txt","0","2026-01-01 00:00:00","Applications","保留","保留项"
"D:\Temp\confirm.txt",".txt","0","2026-01-01 00:00:00","Applications","需确认","需确认项"
"@

    It '安全根 / 系统核心降级、保留跳过、DryRun 不删任何文件' {
        $csv = New-TempCsv -content $baseCsv
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $r.Output | Should Match 'DryRun 模式：未删除任何文件'
        $lines = $r.Output -split "`n"
        ($lines | Where-Object { $_ -match '^确定拟删除: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^待确认: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^安全根二次确认: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^系统核心降级待确认: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^已跳过\(保留/否/受保护/未知\): 1 个' }).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '规划汇总 CSV（cleanup_plan_files.csv）的 Intent 列精确分类计数正确' {
        $csv = New-TempCsv -content $baseCsv
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 4
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Confirm' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Safe' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Guarded' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'cleanup_cd.ps1 — 标签映射（全方案 / 全边界）' {

    It 'Scheme C 标签：是->Delete / 否->Keep(跳过) / 谨慎->Confirm' {
        $csv = New-TempCsv -content @"
$csvHeader
"D:\Temp\a.tmp",".tmp","0","2026-01-01 00:00:00","Applications","是","可清理"
"D:\Temp\b.txt",".txt","0","2026-01-01 00:00:00","Applications","否","保留"
"D:\Temp\c.tmp",".tmp","0","2026-01-01 00:00:00","Applications","谨慎","需确认"
"@
        $r = Invoke-Cleanup -CsvPaths $csv -Scheme C
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 2
        (@($plan | Where-Object { $_.Intent -eq 'Delete' -and $_.FullPath -like '*\a.tmp' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Confirm' -and $_.FullPath -like '*\c.tmp' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '未知标签一律 Keep（不进任何计划、不误删）' {
        $csv = New-TempCsv -content @"
$csvHeader
"D:\Temp\auto.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Temp\weird.x",".x","0","2026-01-01 00:00:00","Applications","神秘标签","未知"
"@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\auto.tmp' })).Count | Should Be 1
        $r.Output | Should Match '已跳过\(保留/否/受保护/未知\): 1 个'
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '多 CSV 合并：两个清单的 Delete 行合并计数' {
        $csv1 = New-TempCsv -content @"
$csvHeader
"D:\Temp\one.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"@
        $csv2 = New-TempCsv -content @"
$csvHeader
"D:\Temp\two.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"@
        $r = Invoke-Cleanup -CsvPaths @($csv1, $csv2)
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 2
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 2
        Remove-Item $csv1 -Force -ErrorAction SilentlyContinue
        Remove-Item $csv2 -Force -ErrorAction SilentlyContinue
    }
}

Describe 'cleanup_cd.ps1 — 版本控制兜底（清单模式 F-C 修复）' {

    It '.git/.svn/.hg 项在清单模式被强制排除，任何模式均不删除，且输出保护计数' {
        $csv = New-TempCsv -content @"
$csvHeader
"D:\Temp\realjunk.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\repo\.git\objects\abc123",".pack","0","2026-01-01 00:00:00","版本控制数据","自动清理","版本库"
"@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $r.Output | Should Match '版本控制数据保护: 1 个'
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\.git\*' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'cleanup_cd.ps1 — 系统核心降级 / AllowSystemJunk' {

    It '系统核心目录下的 Delete 项被强制降为待确认（Guarded），不自动删除' {
        $csv = New-TempCsv -content @"
$csvHeader
"C:\Windows\System32\junk.dll",".dll","0","2026-01-01 00:00:00","Windows","自动清理","系统核心"
"@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Guarded' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '-AllowSystemJunk：命中已知垃圾热点（\windows\wer\）时恢复为 Delete' {
        $csv = New-TempCsv -content @"
$csvHeader
"C:\Windows\wer\report.txt",".txt","0","2026-01-01 00:00:00","错误报告","自动清理","已知垃圾热点"
"@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ AllowSystemJunk = $true }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '-AllowSystemJunk 不恢复非热点系统核心项（仍 Guarded）' {
        $csv = New-TempCsv -content @"
$csvHeader
"C:\Windows\System32\junk.dll",".dll","0","2026-01-01 00:00:00","Windows","自动清理","系统核心"
"@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ AllowSystemJunk = $true }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.Intent -eq 'Guarded' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'cleanup_cd.ps1 — 受保护片段 / 安全根（决策点兜底，非仅分类点）' {

    It '-SafeRoots 参数追加的安全根：其下 Delete 项提升为二次确认（Safe）' {
        $safeDir = Join-Path $tmp 'zw_pester_safe'
        New-Item -ItemType Directory -Path $safeDir -Force | Out-Null
        $csv = New-TempCsv -content @"
$csvHeader
"$safeDir\mydoc.txt",".txt","0","2026-01-01 00:00:00","Applications","自动清理","安全根"
"@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ SafeRoots = @($safeDir) }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Safe' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
        Remove-Item $safeDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It '受保护片段（.workbuddy）经 -Root 扫描命中即保留、不进计划' {
        $scanRoot = Join-Path $tmp ('zw_pester_scan_prot_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $scanRoot -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $scanRoot 'auto.tmp'), 'junk')
        $wbDir = Join-Path $scanRoot 'sub\.workbuddy'
        New-Item -ItemType Directory -Path $wbDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $wbDir 'keep.txt'), 'k')
        $outMd = Join-Path $tmp ('zw_pester_prot_' + [guid]::NewGuid().ToString('N') + '.md')
        $outCsv = Join-Path $tmp ('zw_pester_prot_' + [guid]::NewGuid().ToString('N') + '_files.csv')
        $output = & $cleanupScript -Root $scanRoot -Scheme D -Mode DryRun -OutMd $outMd -OutCsv $outCsv
        $code = $LASTEXITCODE
        $output = $output | Out-String
        $code | Should Be 0
        $plan = @(Import-Csv $outCsv)
        # auto.tmp -> Delete；.workbuddy\keep.txt -> 受保护 -> Keep(跳过)
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\.workbuddy\*' })).Count | Should Be 0
        Remove-Item $scanRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outMd -Force -ErrorAction SilentlyContinue
        Remove-Item $outCsv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'cleanup_cd.ps1 — 现场扫描（-Root，Scheme D 分类）' {

    It '扫描临时目录：.tmp/.log->Delete，普通 .txt->保留跳过' {
        $scanRoot = Join-Path $tmp ('zw_pester_scan_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $scanRoot -Force | Out-Null
        # 非空 .tmp -> 自动清理(Delete)；非空 .log -> 自动清理(Delete)
        [System.IO.File]::WriteAllText((Join-Path $scanRoot 'a.tmp'), 'junk')
        [System.IO.File]::WriteAllText((Join-Path $scanRoot 'b.log'), 'log')
        # 普通 .txt -> 其他/未知 -> 保留(Keep)
        [System.IO.File]::WriteAllText((Join-Path $scanRoot 'c.txt'), 'doc')
        $outMd = Join-Path $tmp ('zw_pester_scan_' + [guid]::NewGuid().ToString('N') + '.md')
        $outCsv = Join-Path $tmp ('zw_pester_scan_' + [guid]::NewGuid().ToString('N') + '_files.csv')
        $output = & $cleanupScript -Root $scanRoot -Scheme D -Mode DryRun -OutMd $outMd -OutCsv $outCsv
        $code = $LASTEXITCODE
        $output = $output | Out-String
        $code | Should Be 0
        $plan = @(Import-Csv $outCsv)
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 2
        (@($plan | Where-Object { $_.FullPath -like '*\c.txt' })).Count | Should Be 0
        $output | Should Match 'DryRun 模式：未删除任何文件'
        Remove-Item $scanRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outMd -Force -ErrorAction SilentlyContinue
        Remove-Item $outCsv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'cleanup_cd.ps1 — 编码鲁棒性与错误边界' {

    It 'UTF-16 LE 编码 CSV 可被正确解析（BOM 探测）' {
        $content = @"
$csvHeader
"D:\Temp\uni.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"@
        $csv = New-TempCsv -content $content -Encoding ([System.Text.Encoding]::Unicode)
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        $plan.Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\uni.tmp' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '缺必需列（无 FullPath）的 CSV 被跳过，且无有效数据时 exit 1' {
        $content = @'
"Cleanable","Category"
"自动清理","Applications"
'@
        $csv = New-TempCsv -content $content
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 1
        $r.Output | Should Match '未加载到任何有效清单数据'
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '仅表头无数据行：exit 1（无有效清单）' {
        $csv = New-TempCsv -content $csvHeader
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '未提供 -Root 与 -CsvPaths：exit 1（参数错误）' {
        $outMd = Join-Path $tmp ('zw_pester_noinput_' + [guid]::NewGuid().ToString('N') + '.md')
        $outCsv = Join-Path $tmp ('zw_pester_noinput_' + [guid]::NewGuid().ToString('N') + '_files.csv')
        $output = & $cleanupScript -OutMd $outMd -OutCsv $outCsv
        $code = $LASTEXITCODE
        $code | Should Be 1
        Remove-Item $outMd -Force -ErrorAction SilentlyContinue
        Remove-Item $outCsv -Force -ErrorAction SilentlyContinue
    }
}
