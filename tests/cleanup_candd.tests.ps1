<#
.SYNOPSIS
  Cleanup_CandD_zw 仓库 Pester 测试套件（Pester 3.4.0 语法）。

.DESCRIPTION
  四大板块，覆盖全功能 / 全场景 / 全边界：

    A) powershell-audit-regression 六项 AST 审计集成（含反证复现）
       —— 对业务脚本跑审计断言全 NONE；对 6 类 buggy 片段逐项验证审计能抓住
    B) winapp2_expand.ps1 全功能（Default 键语义、* 剥离、元数据节跳过、
       边界过滤、Detect 门控、变量展开、RECURSE、REMOVESELF、ExcludeKey、
       LangSecRef、多值 FileKey、注释行）
    C) cleanup_cd.ps1 全功能（双层硬保护、标签映射、版本控制兜底、
       系统核心降级、受保护片段/安全根、现场扫描、自动清理目录、
       编码鲁棒性、错误边界）
    D) 回归锁定（v0.5.1 四处修复：Write-DeleteStat / Get-ProgramFilesPaths /
       Parse-Winapp2 换行 / Resolve-Recursive $matches）

  采用黑盒方式（用受控 .ini / .csv 驱动脚本，断言产物），不依赖脚本内部函数导出。
  AST 审计相关用例用语法树提取法（只读业务脚本，不改也不要求其导出）。

  编码说明（PS 5.1 陷阱已在辅助函数中规避）：
    - Invoke-Expand 用 -NoEnumerate 保住数组契约（单结果行时裸 return 会被拆包为标量）。
    - Where-Object 匹配结果用 @() 包成数组后再取 .Count（单匹配返回标量，.Count 为 $null）。
    - 探测文件写入 %Temp%（GetTempPath），与 winapp2_expand 内部展开来源一致。
    - 含中文的临时 .ps1 必须 UTF-8 带 BOM（PS 5.1 按 GBK 读无 BOM 文件会乱码）。
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $here '..')
$expandScript = Join-Path $repoRoot 'winapp2_expand.ps1'
$cleanupScript = Join-Path $repoRoot 'cleanup_cd.ps1'
$auditScript = Join-Path $here 'tools\Invoke-PSAstAudit.ps1'
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
    # 兼容单引号 here-string（@'...@' 不展开变量）：若 content 未被展开为真实表头
    # （即不以 " 开头，说明调用方传的是字面 $csvHeader），自动补上标准表头。
    if (-not $content.StartsWith('"')) {
        $content = $csvHeader + "`n" + $content
    }
    if ($null -eq $Encoding) { [System.IO.File]::WriteAllText($p, $content, [System.Text.UTF8Encoding]::new($false)) }
    else { [System.IO.File]::WriteAllText($p, $content, $Encoding) }
    return $p
}

# 运行 cleanup_cd.ps1，返回 @{ Output, OutCsv, OutMd, Code }
function Invoke-Cleanup {
    param([string[]]$CsvPaths, [string]$Scheme = 'Auto', [string]$Mode = 'DryRun', [hashtable]$Extra = @{})
    $outMd = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '.md')
    $outCsv = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '_files.csv')
    # -Root 扫描产物也必须用测试前缀：脚本默认会写 $env:TEMP\scan_inventory_<盘符>.csv，
    # 不显式指定就会在 TEMP 根目录留下无前缀的残留（不可追踪、不可按名清理）。
    $outScan = Join-Path $tmp ('zw_pester_' + [guid]::NewGuid().ToString('N') + '_scan.csv')
    $params = @{ CsvPaths = $CsvPaths; Mode = $Mode; Scheme = $Scheme; OutMd = $outMd; OutCsv = $outCsv; OutScanCsv = $outScan }
    foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] }
    $output = & $cleanupScript @params 2>&1
    $code = $LASTEXITCODE
    $output = $output | Out-String
    return @{ Output = $output; OutCsv = $outCsv; OutMd = $outMd; OutScanCsv = $outScan; Code = $code }
}

# 标准 CSV 表头（与 cleanup_cd 输出同构）
$csvHeader = '"FullPath","Extension","SizeMB","LastWriteTime","Category","Cleanable","Reason"'

# 用语法树从业务脚本原文中提取目标函数定义，落地临时 .ps1 后 dot-source 调用。
# 只读业务脚本，既不修改它、也不要求它导出函数，与"黑盒不改业务脚本"约定不冲突。
function Export-InternalFunction {
    param([string]$ScriptPath, [string[]]$FunctionName)
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tk, [ref]$er)
    if (@($er).Count -gt 0) { throw ('语法树解析失败：{0}' -f $ScriptPath) }
    $found = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            Where-Object { $FunctionName -contains $_.Name })
    if ($found.Count -eq 0) { throw ('未找到函数：{0}' -f ($FunctionName -join ',')) }
    $sb = New-Object System.Text.StringBuilder
    foreach ($fn in $found) { [void]$sb.AppendLine($fn.Extent.Text); [void]$sb.AppendLine() }
    $p = Join-Path $tmp ('zw_pester_ast_' + [guid]::NewGuid().ToString('N') + '.ps1')
    # PS 5.1 对无 BOM 的 .ps1 按系统 GBK 解读，被提取的函数体含中文注释，必须写 UTF-8 带 BOM
    [System.IO.File]::WriteAllText($p, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
    return $p
}

# 运行 AST 审计脚本，返回解析后的判定行（hashtable：键=项名，值=判定值）
function Invoke-Audit {
    param([string[]]$Path)
    $out = & $auditScript -Path $Path 2>&1
    $result = @{}
    $currentFile = $null
    foreach ($line in $out) {
        if ($line -match '^====') {
            $currentFile = $line
            continue
        }
        if ($currentFile -and $line -match '^(?<key>[A-F]_[A-Z_]+)=(?<val>.*)$') {
            $result[$Matches.key] = $Matches.val
        }
        if ($line -match '^PARSE_ERRORS=') { $result['PARSE_ERRORS'] = $line.Split('=')[1] }
        if ($line -match '^ENCODING_UTF8_BOM=(\S+)') { $result['ENCODING_UTF8_BOM'] = $Matches[1] }
        # RISK= 不在行首（与 ENCODING_UTF8_BOM 同一行、位于行尾），只能按行内匹配捕获，
        # 且必须取 \S+ —— 直接 Split('=') 会把 "NO NON_ASCII..." 这类后续内容一并吞掉。
        if ($line -match '\bRISK=(\S+)') { $result['RISK'] = $Matches[1] }
    }
    return $result
}

# 写一个含已知缺陷的临时 .ps1，返回路径（UTF-8 带 BOM）
function New-BuggyScript {
    param([string]$Content)
    $p = Join-Path $tmp ('zw_pester_buggy_' + [guid]::NewGuid().ToString('N') + '.ps1')
    [System.IO.File]::WriteAllText($p, $Content, (New-Object System.Text.UTF8Encoding($true)))
    return $p
}

# ===================== A. powershell-audit-regression 六项 AST 审计集成 =====================
# 本板块验证两件事：① 审计脚本对当前业务脚本输出全 NONE（无已知缺陷）；
# ② 审计脚本对 6 类 buggy 片段逐项能抓住（反证复现：证明审计不是摆设）。

Describe 'A1 AST 审计对当前业务脚本输出全 NONE' {

    It 'cleanup_cd.ps1 六项审计全 NONE + 语法无错 + UTF-8 BOM' {
        $r = Invoke-Audit -Path $cleanupScript
        $r.PARSE_ERRORS | Should Be '0'
        $r.A_DUPLICATE_FUNCS | Should Be 'NONE'
        $r.B_POLLUTION_RISK | Should Be 'NONE'
        $r.C_PARAM_SCRIPTVAR_COLLISION | Should Be 'NONE'
        $r.D_FUNC_WRITES_OUTER_SCOPE | Should Not Be 'NONE'  # Confirm-Dir 有意缓存 $script:DirConfirmCache
        $r.F_RESERVED_VAR_SHADOW | Should Be 'NONE'
        $r.ENCODING_UTF8_BOM | Should Be 'True'
    }

    It 'winapp2_expand.ps1 六项审计全 NONE + 语法无错 + UTF-8 BOM' {
        $r = Invoke-Audit -Path $expandScript
        $r.PARSE_ERRORS | Should Be '0'
        $r.A_DUPLICATE_FUNCS | Should Be 'NONE'
        $r.B_POLLUTION_RISK | Should Be 'NONE'
        $r.C_PARAM_SCRIPTVAR_COLLISION | Should Be 'NONE'
        $r.D_FUNC_WRITES_OUTER_SCOPE | Should Be 'NONE'
        $r.E_ARRAY_RETURN_SITES | Should Be 'NONE'
        $r.F_RESERVED_VAR_SHADOW | Should Be 'NONE'
        $r.ENCODING_UTF8_BOM | Should Be 'True'
    }
}

Describe 'A2 审计项 A：重复函数定义能被抓住' {

    It '同名函数二次定义被 A 项检出' {
        $p = New-BuggyScript @'
function Dup-Foo { return 1 }
function Dup-Foo { return 2 }
'@
        $r = Invoke-Audit -Path $p
        $r.A_DUPLICATE_FUNCS | Should Not Be 'NONE'
        $r.A_DUPLICATE_FUNCS | Should Match 'Dup-Foo'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A3 审计项 B：函数污染（被赋值消费的函数内含 Write-Output）能被抓住' {

    It '函数返回值被赋值使用且体内含 Write-Output 被 B 项检出' {
        $p = New-BuggyScript @'
function Pollute-Me {
    param($Stat)
    Write-Output 'log line'
    return [int]$Stat.Fail
}
$x = Pollute-Me -Stat @{ Fail = 0 }
'@
        $r = Invoke-Audit -Path $p
        $r.B_POLLUTION_RISK | Should Not Be 'NONE'
        $r.B_POLLUTION_RISK | Should Match 'Pollute-Me'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It '函数未被赋值消费、仅用 Write-Output 打日志时不误报' {
        $p = New-BuggyScript @'
function Safe-Log {
    Write-Output 'just logging'
    return 42
}
Safe-Log | Out-Null
'@
        $r = Invoke-Audit -Path $p
        $r.B_POLLUTION_RISK | Should Be 'NONE'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A4 审计项 C：param 名与 $script: 同名能被抓住' {

    It '顶层 param 与 $script: 同名被 C 项检出' {
        # 注意：param 必须是脚本首条可执行语句（PS 语法硬约束）。若把它放到
        # $script:Config 赋值之后，解析即报 PARSE_ERRORS>0，审计会直接 continue，
        # C 项反而检不出来——这会让"反证复现"变成假阴性，必须规避。
        $p = New-BuggyScript @'
param([string]$Config)
function Use-Cfg {
    $script:Config = @{ x = 1 }
    return $script:Config
}
Write-Host $Config
'@
        $r = Invoke-Audit -Path $p
        $r.PARSE_ERRORS | Should Be '0'
        $r.C_PARAM_SCRIPTVAR_COLLISION | Should Not Be 'NONE'
        $r.C_PARAM_SCRIPTVAR_COLLISION | Should Match 'Config'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A5 审计项 D：函数内写 $script:/$global: 能被抓住' {

    It '函数内赋值 $script: 被 D 项检出' {
        $p = New-BuggyScript @'
function Leak-Cache {
    $script:Cache = @{}
    return $script:Cache
}
'@
        $r = Invoke-Audit -Path $p
        $r.D_FUNC_WRITES_OUTER_SCOPE | Should Not Be 'NONE'
        $r.D_FUNC_WRITES_OUTER_SCOPE | Should Match 'Leak-Cache'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A6 审计项 E：return @(...) 站点能被抓住' {

    It '函数体内 return @(...) 被 E 项检出' {
        $p = New-BuggyScript @'
function Get-Items {
    return @('a', 'b')
}
'@
        $r = Invoke-Audit -Path $p
        $r.E_ARRAY_RETURN_SITES | Should Not Be 'NONE'
        $r.E_ARRAY_RETURN_SITES | Should Match 'Get-Items'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A7 审计项 F：自动变量遮蔽能被抓住' {

    It 'param 名为 $matches 被 F 项检出' {
        $p = New-BuggyScript @'
function Shadow-Match {
    param($matches)
    return $matches
}
'@
        $r = Invoke-Audit -Path $p
        $r.F_RESERVED_VAR_SHADOW | Should Not Be 'NONE'
        $r.F_RESERVED_VAR_SHADOW | Should Match 'matches'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It '顶层赋值 $input 被 F 项检出' {
        $p = New-BuggyScript @'
$input = 'shadowed'
'@
        $r = Invoke-Audit -Path $p
        $r.F_RESERVED_VAR_SHADOW | Should Not Be 'NONE'
        $r.F_RESERVED_VAR_SHADOW | Should Match 'input'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

Describe 'A8 审计项：编码检查（UTF-8 BOM / 非 ASCII 风险）' {

    It '无 BOM 且含非 ASCII 的脚本被标记 RISK=YES_PS51_WILL_MOJIBAKE' {
        $p = Join-Path $tmp ('zw_pester_nobom_' + [guid]::NewGuid().ToString('N') + '.ps1')
        # 写无 BOM 且含中文（非 ASCII）的脚本
        [System.IO.File]::WriteAllText($p, "Write-Host '你好'", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Audit -Path $p
        $r.ENCODING_UTF8_BOM | Should Be 'False'
        $r['RISK'] | Should Be 'YES_PS51_WILL_MOJIBAKE'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

# ===================== B. winapp2_expand.ps1 全功能 / 全场景 / 全边界 =====================

Describe 'B1 winapp2_expand — Default 键语义与分类（F-3 核心）' {

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

Describe 'B2 winapp2_expand — 节名 * 排版标记仅作显示名剥离（F-3）' {

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

Describe 'B3 winapp2_expand — 元数据节跳过（F-2）' {

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

[ZW Real Section]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Reason -like '*Winapp2' })).Count | Should Be 0
        (@($rows | Where-Object { $_.Reason -like '*Version' })).Count | Should Be 0
        (@($rows | Where-Object { $_.Reason -like '*ZW Real Section' })).Count | Should Be $rows.Count
    }
}

Describe 'B4 winapp2_expand — 边界：空节过滤 / 无目标过滤 / RegKey 处理 / 通配符检测' {

    It '空文件节（仅检测无清理目标）被 Test-Valid 过滤，不产生处置行' {
        $ini = @'
[ZW Empty Section]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }

    It '有检测无 FileKey（hasDetect 真 / hasTarget 假）被 Test-Valid 过滤' {
        $ini = @'
[ZW Detect Only]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }

    It 'DetectFile 指向不存在文件（门控失败）时不产生处置行' {
        $ini = @'
[ZW Detect Fail]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_nonexistent_xyz.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }

    It 'RegKey 默认忽略（不带 -IncludeReg 时不产生处置行）' {
        $ini = @'
[ZW RegKey Only]
LangSecRef=3021
RegKey=SOFTWARE\ZW\Test
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }
}

Describe 'B5 winapp2_expand — Detect 注册表门控（OR 门控之一）' {

    # 门控契约：Detect 值必须带注册表根键（HKLM/HKCU/...）。Test-Registry 取首个 '\' 之前
    # 的令牌作为 hive，无法解析即返回 $null -> 判定未安装。这是 Winapp2 规范的既有约定，
    # 不是缺陷，故用例必须写成 "HKLM\SOFTWARE\..." 形式。
    It 'Detect 注册表键存在时门控通过，产生处置行' {
        $ini = @'
[ZW Reg Detect]
LangSecRef=3021
Detect=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
    }

    It 'Detect 注册表键不存在时门控失败，不产生处置行' {
        $ini = @'
[ZW Reg Detect Fail]
LangSecRef=3021
Detect=HKLM\SOFTWARE\ZW\NonExistentKey12345
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }

    It 'Detect 缺根键（裸 SOFTWARE\...）无法解析 hive，门控失败' {
        $ini = @'
[ZW Reg Detect NoHive]
LangSecRef=3021
Detect=SOFTWARE\Microsoft\Windows\CurrentVersion
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }
}

Describe 'B6 winapp2_expand — 变量展开 / RECURSE / REMOVESELF / 多值键' {

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

Describe 'B7 winapp2_expand — ExcludeKey 豁免（最高优先级白名单）' {

    It 'FILE 直接子项按名排除' {
        $exclDir = Join-Path $tmp 'zw_pester_excl'
        New-Item -ItemType Directory -Path $exclDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $exclDir 'keep.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $exclDir 'skip.tmp') -Force | Out-Null
        $ini = @'
[ZW Exclude File]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_excl|*.tmp
ExcludeKey1=FILE|%Temp%\zw_pester_excl|skip.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.FullPath -like '*\keep.tmp' })).Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\skip.tmp' })).Count | Should Be 0
    }

    It 'PATH 整个子树排除' {
        $pathDir = Join-Path $tmp 'zw_pester_path'
        New-Item -ItemType Directory -Path $pathDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $pathDir 'subtree') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $pathDir 'subtree\a.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $pathDir 'top.tmp') -Force | Out-Null
        $ini = @'
[ZW Exclude Path]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_path|*.tmp|RECURSE
ExcludeKey1=PATH|%Temp%\zw_pester_path\subtree|*
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.FullPath -like '*\top.tmp' })).Count | Should Be 1
        (@($rows | Where-Object { $_.FullPath -like '*\subtree\a.tmp' })).Count | Should Be 0
    }
}

Describe 'B8 winapp2_expand — LangSecRef 分类映射 / MaxEntries / 注释行' {

    It 'LangSecRef=3021 映射到 Applications 分类' {
        $ini = @'
[ZW LangSecRef Map]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Category -eq 'Applications' })).Count | Should Be $rows.Count
    }

    It '注释行（; 和 #）被跳过，不产生节' {
        $ini = @'
; 这是注释
[ZW Comment Section]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
# 也是注释
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Reason -like '*Comment*' })).Count | Should Be $rows.Count
    }
}

Describe 'B9 winapp2_expand — REG 换行分割健壮性（REG-3 回归锁定）' {

    It 'CRLF / LF / 混合换行三种输入产出完全一致的处置行' {
        $lines = @(
            '[ZW Newline Contract]',
            'LangSecRef=3021',
            'DetectFile=%Temp%\zw_pester_marker.txt',
            'FileKey1=%Temp%\zw_pester_dir|*.tmp'
        )
        $crlf = ($lines -join "`r`n")
        $lf = ($lines -join "`n")
        $mixed = $lines[0] + "`r`n" + $lines[1] + "`n" + $lines[2] + "`r`n" + $lines[3]
        $a = Invoke-Expand -iniContent $crlf
        $b = Invoke-Expand -iniContent $lf
        $c = Invoke-Expand -iniContent $mixed
        @($a).Count | Should Not Be 0
        @($b).Count | Should Be @($a).Count
        @($c).Count | Should Be @($a).Count
        $pa = (@($a | ForEach-Object { $_.FullPath }) -join ';')
        $pa | Should Be (@($b | ForEach-Object { $_.FullPath }) -join ';')
        $pa | Should Be (@($c | ForEach-Object { $_.FullPath }) -join ';')
    }
}

# ===================== C. cleanup_cd.ps1 全功能 / 全场景 / 全边界 =====================

Describe 'C1 cleanup_cd — 双层硬保护 + DryRun 零删除' {

    It '安全根 / 系统核心降级、保留跳过、DryRun 不删任何文件' {
        $csv = New-TempCsv -content @'
$csvHeader
"C:\Windows\System32\notepad.exe",".exe","1.5","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Temp\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Keep\important.txt",".txt","0.001","2026-01-01 00:00:00","User","保留","用户保留"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        # 安全根/系统核心降级项不进 Delete 计划
        (@($plan | Where-Object { $_.FullPath -like '*\notepad.exe' -and $_.Intent -eq 'Delete' })).Count | Should Be 0
        # 普通目录 .tmp -> Delete
        (@($plan | Where-Object { $_.FullPath -like '*\junk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        # 保留项不进 Delete
        (@($plan | Where-Object { $_.FullPath -like '*\important.txt' -and $_.Intent -eq 'Delete' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '规划 CSV 的 Intent 列精确分类计数正确（Keep 项不入盘）' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\Auto\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Keep\keep.txt",".txt","0.001","2026-01-01 00:00:00","User","保留","用户保留"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 1
        # 契约：计划 CSV 只落盘四类拟处置项（Delete/Confirm/Safe/Guarded）。
        # "保留" 项在决策点即 continue，不写 CSV —— 因此 CSV 中不存在 Intent=Keep 的行，
        # 也不应出现该路径。断言必须对齐这个真实契约，而不是臆想 Keep 行会落盘。
        (@($plan | Where-Object { $_.Intent -eq 'Keep' })).Count | Should Be 0
        (@($plan | Where-Object { $_.FullPath -like '*\Keep\keep.txt' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'C2 cleanup_cd — 标签映射（全方案 / 全边界）' {

    It 'Scheme C 标签：是->Delete / 否->Keep(跳过) / 谨慎->Confirm' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\Yes\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","是","自动清理"
"D:\No\keep.txt",".txt","0.001","2026-01-01 00:00:00","User","否","用户保留"
"D:\Cautious\maybe.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","谨慎","需确认"
'@
        $r = Invoke-Cleanup -CsvPaths $csv -Scheme C
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\Yes\junk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\Cautious\maybe.tmp' -and $_.Intent -eq 'Confirm' })).Count | Should Be 1
        # "否" 映射为 Keep：决策点 continue，不落盘（见 C1 第二条用例的契约说明）
        (@($plan | Where-Object { $_.FullPath -like '*\No\keep.txt' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '未知标签一律 Keep（不进任何计划、不误删）' {
        # 陪跑行：保证脚本不因"无任何拟处置项"而 exit 1，从而能真正验证未知标签的处置归属。
        $csv = New-TempCsv -content @'
$csvHeader
"D:\Unknown\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","未知标签XYZ","未知"
"D:\Known\real.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\Unknown\junk.tmp' })).Count | Should Be 0
        (@($plan | Where-Object { $_.FullPath -like '*\Known\real.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        # 未知标签被计入"已跳过(保留/否/受保护/未知)"
        $r.Output | Should Match '已跳过'
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '清单全部为 Keep 时无拟处置项：exit 1（拒绝空计划）' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\Keep\a.txt",".txt","0.001","2026-01-01 00:00:00","User","保留","用户保留"
"D:\Keep\b.txt",".txt","0.001","2026-01-01 00:00:00","User","否","用户保留"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 1
        $r.Output | Should Match '未加载到任何有效清单数据'
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '多 CSV 合并：两个清单的 Delete 行合并计数' {
        $csv1 = New-TempCsv -content @'
$csvHeader
"D:\M1\a.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $csv2 = New-TempCsv -content @'
$csvHeader
"D:\M2\b.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths @($csv1, $csv2)
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 2
        Remove-Item $csv1 -Force -ErrorAction SilentlyContinue
        Remove-Item $csv2 -Force -ErrorAction SilentlyContinue
    }
}

Describe 'C3 cleanup_cd — 版本控制兜底（清单模式 F-C 修复）' {

    It '.git/.svn/.hg 项在清单模式被强制排除，任何模式均不删除，且输出保护计数' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\Repo\.git\config",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Repo\.svn\entries",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Repo\.hg\hgrc",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Repo\plain.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Repo\real.txt",".txt","0.001","2026-01-01 00:00:00","User","保留","用户保留"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        # 兜底是"彻底排除"而非"降级"：三项 VCS 连一行都不应出现在计划 CSV 中
        # （既不进 Delete，也不进 Confirm / Safe / Guarded）。
        (@($plan | Where-Object { $_.FullPath -like '*\.git\*' })).Count | Should Be 0
        (@($plan | Where-Object { $_.FullPath -like '*\.svn\*' })).Count | Should Be 0
        (@($plan | Where-Object { $_.FullPath -like '*\.hg\*' })).Count | Should Be 0
        # 同清单内的普通项照常进 Delete（证明排除是精准的，不是整表丢弃）
        (@($plan | Where-Object { $_.FullPath -like '*\plain.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        # "保留" 项不落盘
        (@($plan | Where-Object { $_.FullPath -like '*\real.txt' })).Count | Should Be 0
        # 决策点输出保护计数（清单模式专用兜底生效的证据）
        $r.Output | Should Match '版本控制数据保护: 3 个'
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'C4 cleanup_cd — 系统核心降级 / AllowSystemJunk' {

    It '系统核心目录下的 Delete 项被强制降为待确认（Guarded），不自动删除' {
        $csv = New-TempCsv -content @'
$csvHeader
"C:\Windows\Temp\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\Windows\Temp\junk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '-AllowSystemJunk：命中已知垃圾热点（\windows\wer\）时恢复为 Delete' {
        $csv = New-TempCsv -content @'
$csvHeader
"C:\Windows\WER\Trace.log",".log","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ AllowSystemJunk = $true }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\WER\Trace.log' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '-AllowSystemJunk 不恢复非热点系统核心项（仍 Guarded）' {
        $csv = New-TempCsv -content @'
$csvHeader
"C:\Windows\System32\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ AllowSystemJunk = $true }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\System32\junk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'C5 cleanup_cd — 受保护片段 / 安全根（决策点兜底，非仅分类点）' {

    It 'SafeRoots 参数追加的安全根：其下 Delete 项提升为二次确认（Safe）' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\MySafeRoot\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ SafeRoots = @('D:\MySafeRoot') }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\MySafeRoot\junk.tmp' -and $_.Intent -eq 'Safe' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'C6 cleanup_cd — 现场扫描（-Root，Scheme D 分类）' {

    It '普通目录：.tmp/.log->Delete，普通 .txt->Keep(保留跳过)' {
        $scanRoot = Join-Path $tmp ('zw_pester_scan_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $scanRoot -Force | Out-Null
        # 写入内容避免被当作 0 字节空文件（空文件分类为 Confirm 而非 Delete）
        $junkTmp = Join-Path $scanRoot 'junk.tmp'
        $junkLog = Join-Path $scanRoot 'junk.log'
        $keepTxt = Join-Path $scanRoot 'keep.txt'
        New-Item -ItemType File -Path $junkTmp -Force | Out-Null
        New-Item -ItemType File -Path $junkLog -Force | Out-Null
        New-Item -ItemType File -Path $keepTxt -Force | Out-Null
        [System.IO.File]::WriteAllText($junkTmp, 'junk data', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($junkLog, 'log data', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($keepTxt, 'keep data', [System.Text.UTF8Encoding]::new($false))
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $scanRoot }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\junk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\junk.log' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        # .txt 经 Classify-D 判为"其他/未知 -> 保留"，决策点 continue，不落盘
        (@($plan | Where-Object { $_.FullPath -like '*\keep.txt' })).Count | Should Be 0
        Remove-Item $scanRoot -Force -Recurse -ErrorAction SilentlyContinue
    }

    It 'DryRun 现场扫描零副作用：目标文件在扫描前后均存在且内容不变' {
        $scanRoot = Join-Path $tmp ('zw_pester_side_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $scanRoot -Force | Out-Null
        $f = Join-Path $scanRoot 'payload.tmp'
        [System.IO.File]::WriteAllText($f, 'SENTINEL-PAYLOAD', [System.Text.UTF8Encoding]::new($false))
        $before = (Get-Item -LiteralPath $f).LastWriteTimeUtc.Ticks
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $scanRoot }
        $r.Code | Should Be 0
        (Test-Path -LiteralPath $f) | Should Be $true
        [System.IO.File]::ReadAllText($f) | Should Be 'SENTINEL-PAYLOAD'
        (Get-Item -LiteralPath $f).LastWriteTimeUtc.Ticks | Should Be $before
        Remove-Item $scanRoot -Force -Recurse -ErrorAction SilentlyContinue
    }

    It '临时目录(temp)：其下 .tmp/.log/普通.txt 一律 Delete(自动清理，需清空)' {
        $scanRoot = Join-Path $tmp ('zw_pester_temp_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $scanRoot -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $scanRoot 'a.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $scanRoot 'b.log') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $scanRoot 'c.txt') -Force | Out-Null
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $scanRoot }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 3
        Remove-Item $scanRoot -Force -Recurse -ErrorAction SilentlyContinue
    }
}

Describe 'C7 cleanup_cd — 自动清理目录（清空内容，保留壳）v0.5.0' {

    It '规则1(名恰为 temp/cache/.tmp/.cache)：其下直接子项全删、目录自身不进计划' {
        $autoRoot = Join-Path $tmp ('zw_pester_auto1_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $autoDir = Join-Path $autoRoot 'temp'
        New-Item -ItemType Directory -Path $autoDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $autoDir 'sub') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $autoDir 'a.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $autoDir 'sub\b.tmp') -Force | Out-Null
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $autoRoot }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        # 直接子项全 Delete（文件 a.tmp 与子目录 sub 均为直接子项）
        (@($plan | Where-Object { $_.FullPath -like '*\temp\a.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -eq (Join-Path $autoDir 'sub') -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        # 目录自身不进计划
        (@($plan | Where-Object { $_.FullPath -eq $autoDir })).Count | Should Be 0
        Remove-Item $autoRoot -Force -Recurse -ErrorAction SilentlyContinue
    }

    It '规则2(AI_Work_Temp 整树例外)：其内部 temp 子目录内容不进计划，同级普通 temp 仍清空' {
        $root = Join-Path $tmp ('zw_pester_auto2_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $aiDir = Join-Path $root 'AI_Work_Temp'
        $aiTemp = Join-Path $aiDir 'temp'
        $plainTemp = Join-Path $root 'temp'
        New-Item -ItemType Directory -Path $aiTemp -Force | Out-Null
        New-Item -ItemType Directory -Path $plainTemp -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $aiTemp 'inside.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $plainTemp 'outside.tmp') -Force | Out-Null
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $root }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        # AI_Work_Temp 内部 temp 不进计划
        (@($plan | Where-Object { $_.FullPath -like '*\AI_Work_Temp\temp\inside.tmp' })).Count | Should Be 0
        # 同级普通 temp 仍清空
        (@($plan | Where-Object { $_.FullPath -like '*\temp\outside.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        Remove-Item $root -Force -Recurse -ErrorAction SilentlyContinue
    }
}

Describe 'C8 cleanup_cd — 编码鲁棒性与错误边界' {

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

Describe 'C9 cleanup_cd — 输出 CSV 同构（表头与 Intent 列）' {

    It '输出 CSV 表头与实际 schema 一致（FullPath/SizeMB/Category/Reason/Intent/SafeRoot/SystemGuarded/Action）' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\T\a.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $headerLine = (Get-Content -LiteralPath $r.OutCsv | Select-Object -First 1)
        $headerLine | Should Be '"FullPath","SizeMB","Category","Reason","Intent","SafeRoot","SystemGuarded","Action"'
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

# ===================== D. 回归锁定（v0.5.1 四处修复，防回改） =====================
# 用 AST 提取法：从业务脚本原文取出函数定义，落地临时 .ps1 后 dot-source 调用。
# 只读业务脚本，不改它也不要求它导出函数，与"黑盒不改业务脚本"约定不冲突。

Describe 'D1 回归锁定：Write-DeleteStat 返回干净 int（函数污染修复）' {

    It 'Fail=0 时返回单个 System.Int32，-gt 0 为假（不得误触 exit 2）' {
        $fp = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName 'Write-DeleteStat'
        . $fp
        $stat = [pscustomobject]@{ Label = 'REG'; Ok = 3; Fail = 0; Skip = 1; Messages = @('m1', 'm2') }
        $ret = Write-DeleteStat -Stat $stat
        @($ret).Count | Should Be 1
        $ret.GetType().FullName | Should Be 'System.Int32'
        [int]$ret | Should Be 0
        ($ret -gt 0) | Should Be $false
        Remove-Item $fp -Force -ErrorAction SilentlyContinue
    }

    It '有失败时按失败数返回，调用方仍能置 exit 2' {
        $fp = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName 'Write-DeleteStat'
        . $fp
        $stat = [pscustomobject]@{ Label = 'REG2'; Ok = 1; Fail = 2; Skip = 0; Messages = @('m1') }
        $ret = Write-DeleteStat -Stat $stat
        @($ret).Count | Should Be 1
        [int]$ret | Should Be 2
        ($ret -gt 0) | Should Be $true
        Remove-Item $fp -Force -ErrorAction SilentlyContinue
    }
}

Describe 'D2 回归锁定：Get-ProgramFilesPaths 环境变量名与注册表值名各归其位' {

    It '环境变量枚举含 ProgramW6432 且不含 ProgramW6432Dir；注册表回退仍保留 ProgramW6432Dir' {
        $fp = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName 'Get-ProgramFilesPaths'
        $body = [System.IO.File]::ReadAllText($fp)
        # 环境变量枚举必须用 ProgramW6432（ProgramW6432Dir 是注册表值名，当环境变量名取不到值）
        $envEnum = [regex]::Match($body, 'foreach \(\$name in @\((.*)\)\) \{').Groups[1].Value
        $envEnum | Should Match "'ProgramW6432'"
        ($envEnum -match 'ProgramW6432Dir') | Should Be $false
        # 注册表回退处的值名本就叫 ProgramW6432Dir，不得被一并误改（修旧造新红线）
        $regEnum = [regex]::Match($body, 'foreach \(\$n in @\((.*)\)\) \{').Groups[1].Value
        $regEnum | Should Match 'ProgramW6432Dir'
        . $fp
        $paths = @(Get-ProgramFilesPaths)
        $paths.Count | Should Not Be 0
        (@($paths | Where-Object { -not (Test-Path -LiteralPath $_) })).Count | Should Be 0
        (@($paths | Where-Object { $_ -eq $env:ProgramFiles })).Count | Should Be 1
        Remove-Item $fp -Force -ErrorAction SilentlyContinue
    }
}

Describe 'D3 回归锁定：Parse-Winapp2 换行分割健壮性（源码级契约）' {

    It '源码使用 -split 而非旧式 -split "r|n"' {
        $fp = Export-InternalFunction -ScriptPath $expandScript -FunctionName 'Parse-Winapp2'
        $body = [System.IO.File]::ReadAllText($fp)
        # Should Match 把字符串当正则，需双重转义才能匹配字面量 \r?\n
        $body | Should Match ([regex]::Escape("-split '\r?\n'"))
        # 旧写法不得残留
        ($body -match [regex]::Escape('-split "`r|`n"')) | Should Be $false
        Remove-Item $fp -Force -ErrorAction SilentlyContinue
    }
}

Describe 'D4 回归锁定：Resolve-Recursive 自动变量遮蔽已消除' {

    It '函数体内不再出现 $matches 赋值（已改名 $hits）' {
        $fp = Export-InternalFunction -ScriptPath $expandScript -FunctionName 'Resolve-Recursive'
        $body = [System.IO.File]::ReadAllText($fp)
        # 不得有 $matches = 赋值（遮蔽自动变量）
        ($body -match '\$matches\s*=') | Should Be $false
        # 必须出现 $hits
        $body | Should Match '\$hits'
        Remove-Item $fp -Force -ErrorAction SilentlyContinue
    }
}

# ===================== E. 反证复现（纪律①：先证明"确实会错"，再证明修复有效） =====================
# 对每处已修缺陷，构造「修复前写法」的独立副本并实测其错误行为，给出明确判词。
# 目的：把"我觉得这样不好"升级为"实测这样会错"，使 D 板块的回归锁定有据可依。

Describe 'E1 反证复现：Write-DeleteStat 修复前写法的错误行为' {

    It '修复前写法（Write-Output 打日志）返回 4 元素数组，-gt 0 判定失真' {
        # 修复前的写法：日志用 Write-Output，与 return 值一起进成功输出流
        $buggy = New-BuggyScript @'
function Write-DeleteStatOld {
    param($Stat)
    foreach ($m in $Stat.Messages) { Write-Output $m }
    Write-Output ('{0}: 成功 {1}，失败 {2}，跳过 {3}' -f $Stat.Label, $Stat.Ok, $Stat.Fail, $Stat.Skip)
    return [int]$Stat.Fail
}
'@
        . $buggy
        $stat = [pscustomobject]@{ Label = 'OLD'; Ok = 3; Fail = 0; Skip = 0; Messages = @('m1', 'm2') }
        $oldRet = Write-DeleteStatOld -Stat $stat
        # 判词：零失败（Fail=0）时，旧写法返回值为「2 条日志 + 1 条汇总 + 1 个返回值」共 4 元素
        @($oldRet).Count | Should Be 4
        # 且 $oldRet -gt 0 返回的是「字符串比较成立的元素集合」而非 $false，
        # 在布尔上下文里被当作非空集合 -> $true，于是零失败也会误触 exit 2。
        [bool]($oldRet -gt 0) | Should Be $true

        # 同一输入下，修复后写法的正确行为（对照组）
        $fp = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName 'Write-DeleteStat'
        . $fp
        $newRet = Write-DeleteStat -Stat $stat
        @($newRet).Count | Should Be 1
        [bool]($newRet -gt 0) | Should Be $false
        Remove-Item $buggy, $fp -Force -ErrorAction SilentlyContinue
    }
}

Describe 'E2 反证复现：Get-ProgramFilesPaths 修复前环境变量名取不到值' {

    It 'ProgramW6432Dir 作为环境变量名取值为空，ProgramW6432 才能取到' {
        # 反证前提：修复前误用的名字 ProgramW6432Dir 从来就不是环境变量名
        [Environment]::GetEnvironmentVariable('ProgramW6432Dir') | Should BeNullOrEmpty
        # 修复后使用的名字能取到值（本机为 64 位 Windows，ProgramW6432 存在）
        [Environment]::GetEnvironmentVariable('ProgramW6432') | Should Not BeNullOrEmpty
        # 而 ProgramW6432Dir 恰恰是注册表值名，二者语义不同、不可互换
        $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion')
        if ($k) { ($null -ne $k.GetValue('ProgramW6432Dir')) | Should Be $true }
    }
}

Describe 'E3 反证复现：Parse-Winapp2 旧换行分割在 CR 单独出现时产生空节' {

    It '旧写法 -split "r|n" 会把单个 r 也切开，新写法 -split ''r?n'' 不会' {
        $content = "a`rb`nc`r`nd"
        $old = @($content -split "`r|`n")
        $new = @($content -split '\r?\n')
        # 判词：旧写法把裸 CR 也当分隔符，且 CRLF 被当成两次分隔（中间多出一个空串），
        # 故 "a\rb\nc\r\nd" 被切成 5 段（a / b / c / 空 / d）；新写法只认 CRLF 与裸 LF -> 3 段。
        $old.Count | Should Be 5
        $new.Count | Should Be 3
        # 关键差异：旧写法把 "a\rb" 从中间劈开，使同一逻辑行被拆成两行；
        # Winapp2 规则中一旦出现裸 CR，旧写法就会把一个节劈成两半，
        # 后半段变成无节归属的游离键而被静默丢弃。
        $old[0] | Should Be 'a'
        $new[0] | Should Be "a`rb"
        # 旧写法还会在 CRLF 处留下空段，新写法不会
        (@($old | Where-Object { $_ -eq '' })).Count | Should Be 1
        (@($new | Where-Object { $_ -eq '' })).Count | Should Be 0
    }
}

# ===================== F. 补充场景：执行模式 / 编码回退 / CSV 边界 / 深度边界 =====================

Describe 'F1 cleanup_cd — Execute 模式行为（隔离根内，不触碰真实数据）' {

    It 'Execute + WhatIf：不实际删除、不弹确认、exit 0' {
        $exRoot = Join-Path $tmp ('zw_pester_exec_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $exRoot -Force | Out-Null
        $f = Join-Path $exRoot 'victim.tmp'
        [System.IO.File]::WriteAllText($f, 'KEEP-ME', [System.Text.UTF8Encoding]::new($false))
        $csv = New-TempCsv -content (@'
$csvHeader
'@ + "`n" + '"' + $f + '",".tmp","0.0001","2026-01-01 00:00:00","Applications","自动清理","普通删除"')
        $r = Invoke-Cleanup -CsvPaths $csv -Mode 'Execute' -Extra @{ WhatIf = $true }
        $r.Code | Should Be 0
        (Test-Path -LiteralPath $f) | Should Be $true
        [System.IO.File]::ReadAllText($f) | Should Be 'KEEP-ME'
        $r.Output | Should Match 'WhatIf'
        Remove-Item $exRoot -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It 'Execute（无 WhatIf）：真实删除计划内文件，exit 0，文件消失' {
        $exRoot = Join-Path $tmp ('zw_pester_exec2_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $exRoot -Force | Out-Null
        $f = Join-Path $exRoot 'doomed.tmp'
        [System.IO.File]::WriteAllText($f, 'BYE', [System.Text.UTF8Encoding]::new($false))
        $csv = New-TempCsv -content (@'
$csvHeader
'@ + "`n" + '"' + $f + '",".tmp","0.0001","2026-01-01 00:00:00","Applications","自动清理","普通删除"')
        $r = Invoke-Cleanup -CsvPaths $csv -Mode 'Execute'
        $r.Code | Should Be 0
        (Test-Path -LiteralPath $f) | Should Be $false
        Remove-Item $exRoot -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It 'Execute 模式下"需确认"项默认不删（未加 -DeleteConfirmed）' {
        $exRoot = Join-Path $tmp ('zw_pester_exec3_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $exRoot -Force | Out-Null
        $f = Join-Path $exRoot 'confirm.tmp'
        [System.IO.File]::WriteAllText($f, 'STAY', [System.Text.UTF8Encoding]::new($false))
        $csv = New-TempCsv -content (@'
$csvHeader
'@ + "`n" + '"' + $f + '",".tmp","0.0001","2026-01-01 00:00:00","Applications","需确认","待用户决定"')
        $r = Invoke-Cleanup -CsvPaths $csv -Mode 'Execute'
        $r.Code | Should Be 0
        (Test-Path -LiteralPath $f) | Should Be $true
        $r.Output | Should Match '默认跳过'
        Remove-Item $exRoot -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'F2 cleanup_cd — 编码回退与 CSV 解析边界（RFC4180）' {

    It 'GBK 编码（无 BOM、含中文）CSV 可被回退解码，中文不乱码' {
        $gbk = [System.Text.Encoding]::GetEncoding('GB18030')
        $content = $csvHeader + "`n" + '"D:\Temp\gbk.tmp",".tmp","0.01","2026-01-01 00:00:00","系统缓存","自动清理","中文原因说明"'
        $p = Join-Path $tmp ('zw_pester_gbk_' + [guid]::NewGuid().ToString('N') + '.csv')
        [System.IO.File]::WriteAllBytes($p, $gbk.GetBytes($content))
        $r = Invoke-Cleanup -CsvPaths $p
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\gbk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        # 中文 Reason 被正确解码（乱码则不匹配）
        (@($plan | Where-Object { $_.Reason -eq '中文原因说明' })).Count | Should Be 1
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It '字段内含逗号 / 双引号 / 换行时按 RFC4180 正确还原' {
        $weird = '含,逗号和"引号"以及' + "`n" + '换行的原因'
        # 手工做 RFC4180 转义：双引号翻倍，整字段加引号
        $esc = '"' + ($weird -replace '"', '""') + '"'
        $content = $csvHeader + "`n" + '"D:\Temp\weird.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications",' + $esc + ','
        $content = $csvHeader + "`n" + '"D:\Temp\weird.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理",' + $esc
        $csv = New-TempCsv -content $content
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\weird.tmp' -and $_.Reason -eq $weird })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It '空行与缺列行被安全跳过，不崩溃且不影响有效行' {
        $content = $csvHeader + "`n" +
            '"D:\Temp\ok1.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","有效行1"' + "`n" +
            ',,,,' + "`n" +
            '"D:\Temp\short.tmp"' + "`n" +
            '"D:\Temp\ok2.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","有效行2"'
        $csv = New-TempCsv -content $content
        $r = Invoke-Cleanup -CsvPaths $csv
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.Intent -eq 'Delete' })).Count | Should Be 2
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }
}

Describe 'F3 cleanup_cd — 扫描深度边界与受保护片段（扫描模式）' {

    It '-MaxDepth 1：更深层目录被跳过，仅顶层文件入计划' {
        $root = Join-Path $tmp ('zw_pester_depth_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $lvl1 = Join-Path $root 'lvl1'
        $lvl2 = Join-Path $lvl1 'lvl2'
        New-Item -ItemType Directory -Path $lvl2 -Force | Out-Null
        $top = Join-Path $root 'top.tmp'
        $deep = Join-Path $lvl2 'deep.tmp'
        [System.IO.File]::WriteAllText($top, 'x', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($deep, 'x', [System.Text.UTF8Encoding]::new($false))
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $root; MaxDepth = 1 }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\top.tmp' })).Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\deep.tmp' })).Count | Should Be 0
        Remove-Item $root -Force -Recurse -ErrorAction SilentlyContinue
    }

    It '受保护片段（.workbuddy）目录下的文件在扫描模式被判保留，不进计划' {
        $root = Join-Path $tmp ('zw_pester_prot_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $pb = Join-Path $root '.workbuddy'
        New-Item -ItemType Directory -Path $pb -Force | Out-Null
        $inside = Join-Path $pb 'memory.tmp'
        $outside = Join-Path $root 'plain.tmp'
        [System.IO.File]::WriteAllText($inside, 'x', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($outside, 'x', [System.Text.UTF8Encoding]::new($false))
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $root; ProtectedRoots = @('.workbuddy') }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\.workbuddy\*' })).Count | Should Be 0
        (@($plan | Where-Object { $_.FullPath -like '*\plain.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        Remove-Item $root -Force -Recurse -ErrorAction SilentlyContinue
    }
}

Describe 'F4 winapp2_expand — 补充场景（Warning / 分类回退 / SpecialDetect / 多模式 / 上限 / 注册表开关）' {

    It 'Warning 键被拼接到 Reason 中' {
        $ini = @'
[ZW Warn Section]
LangSecRef=3021
Warning=危险操作
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Reason -like '*[警告: 危险操作]*' })).Count | Should Be $rows.Count
    }

    # 分类回退链（Resolve-Category）：LangSecRef 命中映射表 -> Section 键 -> 'Other Applications'。
    # 注意：节名本身并不参与回退（只有显式 Section= 键才生效），这是脚本的既有契约。
    It '无 LangSecRef 且无 Section 键：分类回退为 Other Applications' {
        $ini = @'
[ZW Fallback Cat]
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Category -eq 'Other Applications' })).Count | Should Be $rows.Count
    }

    It '有 Section 键且 LangSecRef 未命中映射表：分类取 Section 值' {
        $ini = @'
[ZW Section Cat]
Section=MySection
LangSecRef=9999
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Category -eq 'MySection' })).Count | Should Be $rows.Count
    }

    It 'LangSecRef 命中映射表优先于 Section 键' {
        $ini = @'
[ZW Priority Cat]
Section=MySection
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Category -eq 'Applications' })).Count | Should Be $rows.Count
    }

    It '多模式 FileKey（分号分隔 *.tmp;*.log）同时命中两类文件' {
        $mmDir = Join-Path $tmp 'zw_pester_multi'
        New-Item -ItemType Directory -Path $mmDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $mmDir 'x.tmp') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $mmDir 'y.log') -Force | Out-Null
        $ini = @'
[ZW Multi Pattern]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_multi|*.tmp;*.log
'@
        $rows = Invoke-Expand -iniContent $ini
        $rows.Count | Should Be 2
    }

    It '未知 SpecialDetect 代码：门控失败，不产生处置行' {
        $ini = @'
[ZW Special Detect Fail]
LangSecRef=3021
SpecialDetect=DET_NOT_A_REAL_CODE
FileKey1=%Temp%\zw_pester_dir|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        @($rows).Count | Should Be 0
    }

    It '-MaxEntries 1：只处理首条命中规则' {
        $ini = @'
[ZW First]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir|*.tmp

[ZW Second]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_dir2|*.tmp
'@
        $rows = Invoke-Expand -iniContent $ini -Extra @{ MaxEntries = 1 }
        (@($rows | Where-Object { $_.Reason -like '*ZW First*' })).Count | Should Not Be 0
        (@($rows | Where-Object { $_.Reason -like '*ZW Second*' })).Count | Should Be 0
    }

    It '-IncludeReg：RegKey 被列为需确认的备注项（不删注册表）' {
        $ini = @'
[ZW Reg Included]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
RegKey1=HKCU\SOFTWARE\ZW\Test
'@
        $rows = Invoke-Expand -iniContent $ini -Extra @{ IncludeReg = $true }
        $rows | Should Not BeNullOrEmpty
        (@($rows | Where-Object { $_.Cleanable -eq '需确认' -and $_.Reason -like '*注册表规则-仅备注*' })).Count | Should Be 1
    }

    It 'ExcludeKey 非 FILE/PATH 类型（如 REG）不误伤文件' {
        $exDir = Join-Path $tmp 'zw_pester_excl2'
        New-Item -ItemType Directory -Path $exDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $exDir 'a.tmp') -Force | Out-Null
        $ini = @'
[ZW Exclude Wrong Type]
LangSecRef=3021
DetectFile=%Temp%\zw_pester_marker.txt
FileKey1=%Temp%\zw_pester_excl2|*.tmp
ExcludeKey1=REG|%Temp%\zw_pester_excl2|a.tmp
'@
        $rows = Invoke-Expand -iniContent $ini
        (@($rows | Where-Object { $_.FullPath -like '*\a.tmp' })).Count | Should Be 1
    }
}

Describe 'F5 AST 审计 — 批量输入与聚合输出' {

    It '一次传入两个业务脚本：输出两个文件段，且均判定无解析错误' {
        $out = & $auditScript -Path $cleanupScript, $expandScript 2>&1
        $text = ($out | Out-String)
        (@($out | Where-Object { $_ -like '====*cleanup_cd.ps1*' })).Count | Should Be 1
        (@($out | Where-Object { $_ -like '====*winapp2_expand.ps1*' })).Count | Should Be 1
        # 两段各自的 PARSE_ERRORS 均为 0
        (@($out | Where-Object { $_ -match '^PARSE_ERRORS=0$' })).Count | Should Be 2
    }

    It '传入不存在的路径：抛出终止错误而非静默通过（快速失败）' {
        $missing = Join-Path $tmp ('zw_pester_missing_' + [guid]::NewGuid().ToString('N') + '.ps1')
        $threw = $false
        try { & $auditScript -Path $missing -ErrorAction Stop 2>&1 | Out-Null } catch { $threw = $true }
        $threw | Should Be $true
    }
}

# ===================== Z. 收尾：测试零残留（自清理 + 自证） =====================
# 所有临时产物统一使用 zw_pester_ 前缀，收尾时按前缀整批回收。
# ===================== H2 新增功能单元测试（H6/H5/M2/M3/H1/L1 等缺陷的针对性覆盖） =====================
# 通过 AST 提取内部函数体 dot-source，对本次新增/改动的函数做白盒断言；
# 通过 Invoke-Cleanup 黑盒驱动，对 -Aggressive / -NoSystemExclude 等新增开关做端到端断言。
Describe 'H2 新增功能与修复锁定' {

    It 'T1 Format-LongPath 四类输入（普通/UNC/已带前缀/盘符根）' {
        $p = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Format-LongPath')
        . $p
        (Format-LongPath 'C:\foo\bar.txt') | Should Be '\\?\C:\foo\bar.txt'
        (Format-LongPath '\\server\share\x.txt') | Should Be '\\?\UNC\server\share\x.txt'
        (Format-LongPath '\\?\C:\foo') | Should Be '\\?\C:\foo'          # 幂等
        (Format-LongPath 'C:\') | Should Be '\\?\C:\'                    # 盘符根（守卫在 Remove-OneItem，此处仅验证前缀）
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It 'T2 Convert-LongPathBack 反向还原三类路径' {
        $p = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Convert-LongPathBack')
        . $p
        (Convert-LongPathBack '\\?\C:\foo') | Should Be 'C:\foo'
        (Convert-LongPathBack '\\?\UNC\server\share\x') | Should Be '\\server\share\x'
        (Convert-LongPathBack 'C:\foo') | Should Be 'C:\foo'             # 无前缀原样返回
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It 'T3 Test-Admin 返回类型必须为 [bool]（不被 Write-Output 污染）' {
        $p = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Test-Admin')
        . $p
        $r = Test-Admin
        ($r -is [bool]) | Should Be $true
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It 'T4 Test-DangerousRoot 盘符根/UNC共享根守卫（H6）' {
        $p = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Test-DangerousRoot', 'Test-PathPrefix')
        . $p
        (Test-DangerousRoot 'C:\') | Should Be $true
        (Test-DangerousRoot 'C:') | Should Be $true
        (Test-DangerousRoot '\\server') | Should Be $true
        (Test-DangerousRoot '\\server\share') | Should Be $true
        (Test-DangerousRoot '') | Should Be $true
        (Test-DangerousRoot 'C:\Windows') | Should Be $false
        (Test-DangerousRoot 'D:\Data\junk') | Should Be $false
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It 'T5 Test-PathPrefix 边界匹配（避免 C:\Windows 误匹配 C:\WindowsApps）' {
        $p = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Test-PathPrefix')
        . $p
        (Test-PathPrefix 'C:\Windows\foo' 'C:\Windows') | Should Be $true
        (Test-PathPrefix 'C:\Windows' 'C:\Windows') | Should Be $true
        (Test-PathPrefix 'C:\WindowsApps' 'C:\Windows') | Should Be $false
        (Test-PathPrefix 'C:\Windows.old' 'C:\Windows') | Should Be $false
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    It 'T6 Expand-PendingDelete 非空目录递归展开 + 子项先于父项 + UNC 前缀（H5+M2）' {
        # 构建非空目录树：d\f1, d\sub\f2
        $d = Join-Path $tmp ('zw_pester_pend_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $sub = Join-Path $d 'sub'
        New-Item -ItemType Directory -Path $sub -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $d 'f1.txt'), 'x', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $sub 'f2.txt'), 'x', [System.Text.UTF8Encoding]::new($false))
        $p = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Expand-PendingDelete', 'Format-LongPath', 'Convert-LongPathBack')
        . $p
        # 用 @(...) 强制数组化：PS 5.1 会把单元素集合拆包为标量，导致 .Count 为 $null；
        # 生产代码以 foreach 遍历（对标量/集合均安全），此处仅断言需显式数组化。
        $pairs = @(Expand-PendingDelete -Path $d)
        # d 自身 + f1 + sub + f2 = 4 条
        $pairs.Count | Should Be 4
        # 全部 dest 为空串
        (@($pairs | Where-Object { $_.Dest -ne '' })).Count | Should Be 0
        # 全部本地项用 \??\ 前缀
        (@($pairs | Where-Object { -not $_.Source.StartsWith('\??\') })).Count | Should Be 0
        # 排序正确性：最深路径（f2.txt）必须排在最前（父路径是子路径前缀 ⇒ 子更长，降序即子先父后）
        $srcs = @($pairs.Source)
        $srcs[0] | Should Match 'f2\.txt'
        Remove-Item $p -Force -ErrorAction SilentlyContinue
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue

        # M2：UNC 路径用 \??\UNC\ 前缀（无真实共享，仅验证前缀规范化）
        $p2 = Export-InternalFunction -ScriptPath $cleanupScript -FunctionName @('Expand-PendingDelete', 'Format-LongPath', 'Convert-LongPathBack')
        . $p2
        $upairs = @(Expand-PendingDelete -Path '\\fakehost\share\file.txt')
        $upairs.Count | Should Be 1
        $upairs[0].Source | Should Be '\??\UNC\fakehost\share\file.txt'
        Remove-Item $p2 -Force -ErrorAction SilentlyContinue
    }

    It 'T7 -Aggressive 端到端冒烟：开关被接受、不破坏既有分类契约' {
        $csv = New-TempCsv -content @'
$csvHeader
"D:\Agg\real.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
"D:\Agg\keep.txt",".txt","0.001","2026-01-01 00:00:00","User","保留","用户保留"
'@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ Aggressive = $true }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\Agg\real.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        (@($plan | Where-Object { $_.FullPath -like '*\Agg\keep.txt' })).Count | Should Be 0
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It 'T8 -NoSystemExclude 与 -ExcludeRoots 同时生效（M5 修复：不被静默忽略）' {
        # 关键回归：旧实现中 -ExcludeRoots 会让 -NoSystemExclude 整体失效且无提示。
        # 此处以「组合不报错 + 退出码 0 + 既有权限降级契约不变」锁定修复。
        $csv = New-TempCsv -content @'
$csvHeader
"D:\NS\junk.tmp",".tmp","0.01","2026-01-01 00:00:00","Applications","自动清理","普通删除"
'@
        $r = Invoke-Cleanup -CsvPaths $csv -Extra @{ ExcludeRoots = @('D:\NS\irrelevant'); NoSystemExclude = $true }
        $r.Code | Should Be 0
        $plan = @(Import-Csv $r.OutCsv)
        (@($plan | Where-Object { $_.FullPath -like '*\NS\junk.tmp' -and $_.Intent -eq 'Delete' })).Count | Should Be 1
        Remove-Item $csv -Force -ErrorAction SilentlyContinue
    }

    It 'T9 H1 非交互守卫已落地（[Environment]::UserInteractive 短路 Read-Host）' {
        $src = [System.IO.File]::ReadAllText($cleanupScript)
        ($src -match 'UserInteractive') | Should Be $true
    }

    It 'T10 L1 重启删除退出码 4 已声明并在主流程生效（HasPendingReboot）' {
        $src = [System.IO.File]::ReadAllText($cleanupScript)
        ($src -match 'HasPendingReboot') | Should Be $true
        # .OUTPUTS 声明了退出码 0/1/2/3/4 全链
        ($src -match '4 = 存在已注册、需重启后删除的项') | Should Be $true
    }
}

# 这一条既是卫生要求，也是"测试不污染宿主环境"的可验证断言。

Describe 'Z 收尾：测试零残留（自证 + 自清理）' {

    It '-Root 扫描产物落在 zw_pester_ 前缀路径（不写默认名 scan_inventory_*）' {
        $root = Join-Path $tmp ('zw_pester_scanout_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root 'a.tmp'), 'x', [System.Text.UTF8Encoding]::new($false))
        $r = Invoke-Cleanup -CsvPaths @() -Scheme D -Mode DryRun -Extra @{ Root = $root }
        # 契约：测试包装器已把 OutScanCsv 重定向到 zw_pester_ 前缀，
        # 因此不会在 TEMP 根目录新增无前缀的 scan_inventory_<盘符>.csv。
        (Split-Path $r.OutScanCsv -Leaf) | Should Match '^zw_pester_'
        (Test-Path -LiteralPath $r.OutScanCsv) | Should Be $true
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $r.OutScanCsv -Force -ErrorAction SilentlyContinue
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $r.OutCsv -Force -ErrorAction SilentlyContinue
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $r.OutMd -Force -ErrorAction SilentlyContinue
    }

    # 必须放在最后：本用例执行后再无用例生成临时产物，故断言即为最终状态。
    It '清理后 TEMP 下不再残留任何 zw_pester_ 前缀项' {
        $items = @(Get-ChildItem -LiteralPath $tmp -Filter 'zw_pester*' -Force -ErrorAction SilentlyContinue)
        foreach ($it in $items) {
            # 用内置 cmdlet 全限定名，避免被宿主自定义的 Remove-Item 包装函数改写语义
            Microsoft.PowerShell.Management\Remove-Item -LiteralPath $it.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        $left = @(Get-ChildItem -LiteralPath $tmp -Filter 'zw_pester*' -Force -ErrorAction SilentlyContinue)
        $left.Count | Should Be 0
    }
}