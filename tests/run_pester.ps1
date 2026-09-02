<#
.SYNOPSIS
  Cleanup_CandD_zw 仓库 Pester 测试运行器（Pester 3.4.0 / PowerShell 5.1）。

.DESCRIPTION
  - 指定 RequiredVersion 3.4.0，避免新版 Pester 语法不兼容。
  - 用法：.\tests\run_pester.ps1
         .\tests\run_pester.ps1 .\tests\cleanup_candd.tests.ps1
  - 退出码：0 = 全绿；1 = 存在失败用例；2 = 运行器自身异常。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$TestFile
)

$ErrorActionPreference = 'Stop'

# 说明：$PSScriptRoot 在 PS 5.1 的 param 块默认值求值时可能尚未就绪（实测为空字符串，
# 导致 Join-Path 抛参绑错误），因此默认值放到脚本体内解析。
if ([string]::IsNullOrWhiteSpace($TestFile)) {
    $TestFile = Join-Path $PSScriptRoot 'cleanup_candd.tests.ps1'
}

if (-not (Test-Path -LiteralPath $TestFile)) {
    Write-Host "测试文件不存在: $TestFile"
    exit 2
}

# ---- 导入 Pester 3.4.0 ----
try {
    Import-Module Pester -RequiredVersion 3.4.0 -ErrorAction Stop
}
catch {
    Write-Host "Pester 3.4.0 导入失败: $($_.Exception.Message)"
    exit 2
}

# ---- 运行测试（-PassThru 取回结果，用于退出码）----
Write-Host "运行测试: $TestFile"
$result = Invoke-Pester -Script $TestFile -Verbose -PassThru

$passed = [int]$result.PassedCount
$failed = [int]$result.FailedCount
Write-Host ("SUMMARY: Passed={0} Failed={1}" -f $passed, $failed)

if ($failed -gt 0) { exit 1 }
exit 0
