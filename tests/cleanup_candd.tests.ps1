<#
.SYNOPSIS
  Cleanup_CandD_zw 仓库 Pester 测试套件（Pester 3.4.0 语法）
.DESCRIPTION
  覆盖两类核心逻辑：
    1) winapp2_expand.ps1 —— Winapp2 规则解析/分类（含 F-2 元数据节跳过、F-3 的 Default 键语义与 * 显示名剥离）
    2) cleanup_cd.ps1 —— 双层硬保护（安全根 / 系统核心）+ DryRun 零删除
  测试采用黑盒方式：用受控 .ini / .csv 驱动脚本，断言其产物（CSV / 标准输出），
  不依赖脚本内部函数导出，避免改动业务脚本。
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $here '..')
$expandScript = Join-Path $repoRoot 'winapp2_expand.ps1'
$cleanupScript = Join-Path $repoRoot 'cleanup_cd.ps1'
# 与 winapp2_expand.ps1 内部（第 77-79 行）展开 %Temp% 的来源保持一致，
# 避免 $env:TEMP 与 [System.IO.Path]::GetTempPath() 在异常环境下不一致导致探测文件错位。
$tmp = [System.IO.Path]::GetTempPath()

# 准备探测文件（让 DetectFile 通过，使条目被判定为"已装"而产出处置行）
$marker = Join-Path $tmp 'zw_pester_marker.txt'
$dir = Join-Path $tmp 'zw_pester_dir'
New-Item -ItemType File -Path $marker -Force | Out-Null
New-Item -ItemType Directory -Path $dir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $dir 'a.tmp') -Force | Out-Null

function Invoke-Expand {
    param([string]$iniContent, [switch]$AutoDelete, [switch]$IncludeReg)
    $ini = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.ini')
    $csv = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.csv')
    [System.IO.File]::WriteAllText($ini, $iniContent, [System.Text.UTF8Encoding]::new($false))
    $params = @{ Winapp2Path = $ini; OutCsv = $csv }
    if ($AutoDelete) { $params['Winapp2AutoDelete'] = $true }
    if ($IncludeReg) { $params['IncludeReg'] = $true }
    & $expandScript @params | Out-Null
    # @() 强制数组化：Import-Csv 对单行结果返回标量，其 .Count 为 $null（非 1），
    # 会导致按 Count 断言失败；包成数组后 .Count 对任意行数都可靠。
    $rows = @(Import-Csv $csv)
    Remove-Item $ini -Force -ErrorAction SilentlyContinue
    Remove-Item $csv -Force -ErrorAction SilentlyContinue
    # 用 -NoEnumerate 保住数组契约：当结果恰好只有 1 行时，裸 return 会被输出流
    # 拆包成标量（PSCustomObject），使调用方 $rows.Count 变为 $null（正是 F-2 曾失败的根因）；
    # -NoEnumerate 确保无论结果行数多少，调用方始终拿到真正的数组。
    Write-Output -NoEnumerate $rows
}

# ===================== winapp2_expand.ps1 =====================

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
        # @() 强制数组化：Where-Object 恰好匹配 1 行时会返回标量，其 .Count 为 $null，
        # 包成数组后 .Count 对任意匹配数（0/1/N）都可靠。
        (@($rows | Where-Object { $_.Cleanable -ne '需确认' })).Count | Should Be 0
    }

    It 'AutoDelete 模式：Default=False -> 需确认；无键 / Default=True -> 自动清理' {
        $rows = Invoke-Expand -iniContent $ini -AutoDelete
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
        # [Winapp2] / [Version] 为元数据节，应被静默跳过、不产出任何处置行；
        # 因此总数必为 1，且唯一产出必须来自真实应用节 [ZW Real App]。
        # （用后缀匹配规避 Reason 中"规则:"冒号的全/半角差异。）
        $rows.Count | Should Be 1
        (@($rows | Where-Object { $_.Reason -like '*ZW Real App' })).Count | Should Be 1
    }
}

Describe 'winapp2_expand.ps1 — 边界：空节过滤 / RegKey 处理 / 通配符检测' {

    It '空文件节（仅检测无清理目标）被 Test-Valid 过滤，不产生处置行' {
        $ini = @'
[ZW No Target]
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
        $rows = Invoke-Expand -iniContent $ini -IncludeReg
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
}

# ===================== cleanup_cd.ps1 =====================

Describe 'cleanup_cd.ps1 — 双层硬保护 + DryRun 零删除' {

    It '安全根 / 系统核心降级、保留跳过、DryRun 不删任何文件' {
        $csv = Join-Path $tmp ('zw_pester_cd_' + [guid]::NewGuid().ToString('N') + '.csv')
        $outMd = Join-Path $tmp ('zw_pester_cd_' + [guid]::NewGuid().ToString('N') + '.md')
        $outCsv = Join-Path $tmp ('zw_pester_cd_' + [guid]::NewGuid().ToString('N') + '_files.csv')
        $content = @'
"FullPath","Extension","SizeMB","LastWriteTime","Category","Cleanable","Reason"
"C:\Windows\System32\junk.dll",".dll","0","2026-01-01 00:00:00","Windows","自动清理","系统核心"
"D:\ZW工作\mydoc.txt",".txt","0","2026-01-01 00:00:00","Applications","自动清理","安全根"
"D:\Temp\realjunk.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Temp\keep.txt",".txt","0","2026-01-01 00:00:00","Applications","保留","保留项"
"D:\Temp\confirm.txt",".txt","0","2026-01-01 00:00:00","Applications","需确认","需确认项"
'@
        [System.IO.File]::WriteAllText($csv, $content, [System.Text.UTF8Encoding]::new($false))

        $output = & $cleanupScript -CsvPaths $csv -Mode DryRun -OutMd $outMd -OutCsv $outCsv | Out-String

        # DryRun 必须零删除
        $output | Should Match 'DryRun 模式：未删除任何文件'

        $lines = $output -split "`n"
        ($lines | Where-Object { $_ -match '^确定拟删除: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^待确认: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^安全根二次确认: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^系统核心降级待确认: 1 个' }).Count | Should Be 1
        ($lines | Where-Object { $_ -match '^已跳过\(保留/否/受保护/未知\): 1 个' }).Count | Should Be 1

        Remove-Item $csv -Force -ErrorAction SilentlyContinue
        Remove-Item $outMd -Force -ErrorAction SilentlyContinue
        Remove-Item $outCsv -Force -ErrorAction SilentlyContinue
    }

    It '规划汇总 CSV（cleanup_plan_files.csv）的 Intent 列精确分类计数正确' {
        $csv = Join-Path $tmp ('zw_pester_cd_' + [guid]::NewGuid().ToString('N') + '.csv')
        $outMd = Join-Path $tmp ('zw_pester_cd_' + [guid]::NewGuid().ToString('N') + '.md')
        $outCsv = Join-Path $tmp ('zw_pester_cd_' + [guid]::NewGuid().ToString('N') + '_files.csv')
        $content = @'
"FullPath","Extension","SizeMB","LastWriteTime","Category","Cleanable","Reason"
"C:\Windows\System32\junk.dll",".dll","0","2026-01-01 00:00:00","Windows","自动清理","系统核心"
"D:\ZW工作\mydoc.txt",".txt","0","2026-01-01 00:00:00","Applications","自动清理","安全根"
"D:\Temp\realjunk.tmp",".tmp","0","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Temp\keep.txt",".txt","0","2026-01-01 00:00:00","Applications","保留","保留项"
"D:\Temp\confirm.txt",".txt","0","2026-01-01 00:00:00","Applications","需确认","需确认项"
'@
        [System.IO.File]::WriteAllText($csv, $content, [System.Text.UTF8Encoding]::new($false))

        & $cleanupScript -CsvPaths $csv -Mode DryRun -OutMd $outMd -OutCsv $outCsv | Out-Null

        # 直接读产物 CSV 的 Intent 列做分类计数断言（与控制台文案解耦，更稳健）：
        # 保留项(Keep) 不进入规划清单 CSV，故总数应为 4（Delete1 / Confirm1 / Safe1 / Guarded1）。
        $plan = @(Import-Csv $outCsv)
        $plan.Count | Should Be 4
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Confirm' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Safe' })).Count | Should Be 1
        (@($plan | Where-Object { $_.Intent -eq 'Guarded' })).Count | Should Be 1

        Remove-Item $csv -Force -ErrorAction SilentlyContinue
        Remove-Item $outMd -Force -ErrorAction SilentlyContinue
        Remove-Item $outCsv -Force -ErrorAction SilentlyContinue
    }
}
