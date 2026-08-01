# Pester runner with environment-block trimming.
# Pester 3.4.0's SetupTeardown.ps1 calls Add-Type to compile C#, which spawns a
# process. When the inherited environment block exceeds 65535 bytes, that spawn
# fails with "The environment block used to start a process cannot be longer
# than 65535 bytes". We strip all non-essential environment variables before
# importing Pester so the block stays small.
#
# NOTE: We use [Environment]::SetEnvironmentVariable($name, $null) instead of
# "Get-ChildItem Env:" because the Env: provider throws "already added the same
# key" when the process environment contains case-duplicate variable names
# (e.g. Path vs PATH). Clearing the process-level value hides it from the
# environment block inherited by any child process Pester spawns.

$whitelist = @(
    'SystemRoot', 'SystemDrive', 'ComSpec', 'TEMP', 'TMP', 'USERPROFILE',
    'HOMEDRIVE', 'HOMEPATH', 'WINDIR', 'PSModulePath', 'PATHEXT',
    'NUMBER_OF_PROCESSORS', 'PROCESSOR_ARCHITECTURE', 'OS', 'USERNAME',
    'COMPUTERNAME', 'PUBLIC', 'ALLUSERSPROFILE', 'ProgramData', 'ProgramFiles',
    'ProgramFiles(x86)', 'CommonProgramFiles'
)

foreach ($name in [System.Environment]::GetEnvironmentVariables().Keys) {
    if ($whitelist -notcontains $name) {
        [System.Environment]::SetEnvironmentVariable($name, $null)
    }
}

# Truncate PATH to the minimal system paths required to launch PowerShell hosts.
$env:PATH = 'C:\Windows\system32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0\'

$testFile = $args[0]
if (-not $testFile) {
    Write-Error 'usage: run_pester.ps1 <test file>'
    exit 2
}

Import-Module Pester -RequiredVersion 3.4.0 -ErrorAction Stop
$result = Invoke-Pester -Path $testFile -PassThru
if ($result.FailedCount -gt 0) { exit 1 }
exit 0
