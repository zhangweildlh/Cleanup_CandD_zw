<#
.SYNOPSIS
  PowerShell 脚本六项 AST 静态审计（通用，无项目耦合）。

.DESCRIPTION
  对给定的一个或多个 .ps1 / .psm1 文件做机器化静态审计，输出可读判定行。
  目标是所有项均为 NONE；非 NONE 项须人工核判，不得默认有罪也不得默认无罪。

  审计项：
    A  重复函数定义（后者静默覆盖前者 = 函数污染）
    B  返回值被赋值消费的函数体内含 Write-Output（日志串入返回值，判定失真）
    C  param 参数名与 $script: 同名（PS 5.1 类型强转导致对象被静默字符串化）
    D  函数内写 $global: / $script:（可能是有意缓存，也可能是变量泄露）
    E  return @(...) 站点（PS 5.1 单元素数组拆包为标量，.Count 取到 $null）
    F  赋值给自动变量（$matches/$input/$args/$error/$host... 被遮蔽）

.PARAMETER Path
  一个或多个待审计的脚本路径。

.EXAMPLE
  .\Invoke-PSAstAudit.ps1 -Path .\build.ps1, .\deploy.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'

$reserved = @('_', 'args', 'input', 'error', 'host', 'this', 'true', 'false', 'null',
    'psitem', 'matches', 'lastexitcode', 'pwd', 'home', 'profile', 'psscriptroot', 'pscommandpath')

foreach ($t in $Path) {
    $full = (Resolve-Path -LiteralPath $t).Path
    "==================== $full ===================="

    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$tk, [ref]$er)
    "PARSE_ERRORS=" + @($er).Count
    if (@($er).Count -gt 0) {
        $er | ForEach-Object { '   ' + $_.Message }
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($full)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $nonAscii = @($bytes | Where-Object { $_ -gt 127 }).Count -gt 0
    "ENCODING_UTF8_BOM=$hasBom NON_ASCII_PRESENT=$nonAscii RISK=" +
    $(if ($nonAscii -and -not $hasBom) { 'YES_PS51_WILL_MOJIBAKE' } else { 'NO' })

    $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
    "FUNC_TOTAL=" + $funcs.Count

    # ---- A) 重复函数定义 ----
    $dup = @($funcs | Group-Object Name | Where-Object { $_.Count -gt 1 })
    "A_DUPLICATE_FUNCS=" + $(if ($dup.Count -eq 0) { 'NONE' }
        else { ($dup | ForEach-Object { $_.Name + '(x' + $_.Count + ')' }) -join ',' })

    # ---- B) 被赋值消费的函数内含 Write-Output ----
    $funcNames = @($funcs | ForEach-Object { $_.Name })
    $assigned = New-Object System.Collections.Generic.HashSet[string]
    foreach ($a in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
        foreach ($c in @($a.Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))) {
            $nm = $c.GetCommandName()
            if ($nm -and ($funcNames -contains $nm)) { [void]$assigned.Add($nm) }
        }
    }
    "B_ASSIGN_CONSUMED_FUNCS=" + $(if ($assigned.Count -eq 0) { 'NONE' } else { (@($assigned) | Sort-Object) -join ',' })
    $polluted = @()
    foreach ($f in $funcs) {
        if (-not $assigned.Contains($f.Name)) { continue }
        $wo = @($f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
                Where-Object { $_.GetCommandName() -eq 'Write-Output' })
        if ($wo.Count -gt 0) {
            $polluted += ('{0}@line{1}(Write-Output x{2})' -f $f.Name, $f.Extent.StartLineNumber, $wo.Count)
        }
    }
    "B_POLLUTION_RISK=" + $(if ($polluted.Count -eq 0) { 'NONE' } else { $polluted -join ' | ' })

    # ---- C) param 名与 $script: 同名 ----
    $scriptVars = New-Object System.Collections.Generic.HashSet[string]
    foreach ($v in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
        $p = $v.VariablePath.UserPath
        if ($p -like 'script:*') { [void]$scriptVars.Add($p.Substring(7).ToLower()) }
    }
    $collide = @()
    if ($ast.ParamBlock) {
        foreach ($pp in $ast.ParamBlock.Parameters) {
            $n = $pp.Name.VariablePath.UserPath.ToLower()
            if ($scriptVars.Contains($n)) { $collide += ('TOP_PARAM:$' + $n) }
        }
    }
    foreach ($f in $funcs) {
        if (-not $f.Body.ParamBlock) { continue }
        foreach ($pp in $f.Body.ParamBlock.Parameters) {
            $n = $pp.Name.VariablePath.UserPath.ToLower()
            if ($scriptVars.Contains($n)) { $collide += ($f.Name + ':$' + $n) }
        }
    }
    "C_PARAM_SCRIPTVAR_COLLISION=" + $(if ($collide.Count -eq 0) { 'NONE' } else { ($collide | Sort-Object -Unique) -join ',' })

    # ---- D) 函数内写外层作用域 ----
    $leaks = @()
    foreach ($f in $funcs) {
        foreach ($a in @($f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
            foreach ($l in @($a.Left.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
                $up = $l.VariablePath.UserPath
                if ($up -like 'global:*' -or $up -like 'script:*') {
                    $leaks += ('{0}@line{1}->${2}' -f $f.Name, $a.Extent.StartLineNumber, $up)
                }
            }
        }
    }
    "D_FUNC_WRITES_OUTER_SCOPE=" + $(if ($leaks.Count -eq 0) { 'NONE' } else { ($leaks | Sort-Object -Unique) -join ' | ' })

    # ---- E) return @(...) 站点 ----
    $arrRet = @()
    foreach ($f in $funcs) {
        foreach ($r in @($f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))) {
            if ($r.Extent.Text -match 'return\s+@\(') { $arrRet += ('{0}@line{1}' -f $f.Name, $r.Extent.StartLineNumber) }
        }
    }
    "E_ARRAY_RETURN_SITES=" + $(if ($arrRet.Count -eq 0) { 'NONE' } else { ($arrRet | Sort-Object -Unique) -join ' | ' })

    # ---- F) 自动变量遮蔽 ----
    $shadow = @()
    foreach ($f in $funcs) {
        if (-not $f.Body.ParamBlock) { continue }
        foreach ($pp in $f.Body.ParamBlock.Parameters) {
            $n = $pp.Name.VariablePath.UserPath.ToLower()
            if ($reserved -contains $n) { $shadow += ($f.Name + ':param$' + $n) }
        }
    }
    foreach ($a in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
        if ($a.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $n = $a.Left.VariablePath.UserPath.ToLower()
            if ($reserved -contains $n) { $shadow += ('line' + $a.Extent.StartLineNumber + ':$' + $n) }
        }
    }
    "F_RESERVED_VAR_SHADOW=" + $(if ($shadow.Count -eq 0) { 'NONE' } else { ($shadow | Sort-Object -Unique) -join ',' })
    ''
}
