<#
.SYNOPSIS
  Winapp2 / Winappx 规则扩展器（方案甲：零改动伴生器）
.DESCRIPTION
  解析 Winapp2 格式清理规则库，对"已安装应用"的 FileKey 做：
    变量展开(%AppData% 等) + 递归通配符解析 + ExcludeKey 豁免
  输出与 cleanup_cd.ps1 同构的处置清单 CSV：
    FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason
  该 CSV 可直接喂给 cleanup_cd.ps1 -CsvPaths 消费，从而复用其全部
  双层硬保护(安全根 / 系统核心)与 DryRun 默认零副作用。

  本脚本只"展开 / 列出"，绝不删除任何文件；删除决策完全交给 cleanup_cd.ps1。

  设计要点（对齐 FluentCleaner.Core）：
    - Winapp2Parser 等价：INI 分节 + 编号多值键(FileKeyN/RegKeyN/ExcludeKeyN/DetectN*)；
      仅保留"同时具备检测条件 + 清理目标"的条目。
    - PathExpander 等价：约 20 个变量映射；通配符跨树解析（直接复用 .NET
      Directory.GetFileSystemEntries / EnumerateFiles，对齐 Win32 语义，不用 PS -Filter）；
      %ProgramFiles% 自动补试 x86 变体；%SystemDrive% 根级陷阱修正。
    - DetectionService 等价：Detect(注册表) / DetectFile / SpecialDetect 的 OR 门控。
    - ExcludeKey 等价：作为最高优先级白名单豁免（FILE 仅直接子项 / PATH 递归子树）。
.PARAMETER Winapp2Path
  Winapp2.ini / Winappx.ini 路径（必填）。
.PARAMETER OutCsv
  输出 CSV 路径。默认 $env:TEMP\winapp2_expanded.csv。
.PARAMETER Winapp2AutoDelete
  默认关闭（保守）：所有衍生项标记"需确认"。开启后，Default 省略/True 的条目
  标记"自动清理"（仍需过 cleanup_cd 的硬保护）。
.PARAMETER IncludeReg
  默认关闭：忽略 RegKey（注册表清理不在 cleanup_cd 文件清理范围内）。
  开启后仅把 RegKey 列为"需确认"的备注项，cleanup_cd 仍只删文件/目录。
.PARAMETER MaxEntries
  限制处理的规则条目数（0 = 不限制）。用于规模冒烟测试，避免全库枚举过久。
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Winapp2Path,

    [string]$OutCsv = (Join-Path $env:TEMP 'winapp2_expanded.csv'),

    [switch]$Winapp2AutoDelete,
    [switch]$IncludeReg,
    [int]$MaxEntries = 0
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# ===================== 变量映射（PathExpander.BuildVarMap 等价） =====================
function Get-VarMap {
    $m = @{}
    $add = {
        param($name, $val)
        if ($val -and $val.Length -gt 0) { $m["%$name%"] = $val.TrimEnd('\', '/') }
    }
    & $add 'AppData'            ([Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData))
    & $add 'LocalAppData'       ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData))
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    & $add 'LocalLowAppData'    (Join-Path (Join-Path $local '..') 'LocalLow')
    & $add 'ProgramFiles'       ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles))
    & $add 'ProgramFiles(x86)'  ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86))
    & $add 'ProgramFilesX86'    ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86))
    & $add 'ProgramData'        ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData))
    & $add 'CommonAppData'      ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData))
    & $add 'UserProfile'        ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile))
    & $add 'Documents'          ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments))
    & $add 'Desktop'            ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory))
    & $add 'Music'              ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyMusic))
    & $add 'Pictures'           ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyPictures))
    & $add 'Videos'             ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyVideos))
    & $add 'SystemRoot'         ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows))
    & $add 'WinDir'             ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows))
    & $add 'System'             ([Environment]::GetFolderPath([Environment+SpecialFolder]::System))
    & $add 'SystemX86'          ([Environment]::GetFolderPath([Environment+SpecialFolder]::SystemX86))
    $tmp = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
    & $add 'Temp' $tmp
    & $add 'Tmp'  $tmp
    $sys = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
    $drv = [System.IO.Path]::GetPathRoot($sys).TrimEnd('\')
    if (-not $drv) { $drv = 'C:' }
    & $add 'SystemDrive' $drv
    return $m
}

function Replace-CI {
    param($src, $old, $new)
    $sb = [System.Text.StringBuilder]::new()
    $pos = 0
    while ($true) {
        $idx = $src.IndexOf($old, $pos, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -lt 0) { [void]$sb.Append($src, $pos, $src.Length - $pos); break }
        [void]$sb.Append($src, $pos, $idx - $pos)
        [void]$sb.Append($new)
        $pos = $idx + $old.Length
    }
    return $sb.ToString()
}

function Expand-Variables {
    param($path, $varMap)
    foreach ($k in $varMap.Keys) {
        if ($path.IndexOf($k, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $path = Replace-CI $path $k $varMap[$k]
        }
    }
    $path = [Environment]::ExpandEnvironmentVariables($path)
    # %SystemDrive% 展开为 "C:" 仅表示驱动器当前工作目录而非根；补分隔符
    if ($path.Length -eq 2 -and [char]::IsLetter($path[0]) -and $path[1] -eq ':') { $path += '\' }
    return $path
}

# 递归通配符解析（PathExpander.ResolveRecursive 等价，直接复用 .NET API 对齐 Win32）
function Resolve-Recursive {
    param($path, $results)
    $parts = $path.Split(@('\', '/'), [System.StringSplitOptions]::None)
    $wcIdx = -1
    for ($i = 0; $i -lt $parts.Length; $i++) {
        if ($parts[$i].Contains('*') -or $parts[$i].Contains('?')) { $wcIdx = $i; break }
    }
    if ($wcIdx -lt 0) { [void]$results.Add($path); return }
    $basePath = if ($wcIdx -eq 0) { [System.IO.Path]::GetPathRoot($path) } else { [string]::Join('\', $parts[0..($wcIdx - 1)]) }
    if ([string]::IsNullOrEmpty($basePath)) { $basePath = [System.IO.Path]::GetPathRoot($path) }
    if (-not (Test-Path -LiteralPath $basePath)) { return }
    $wildcard = $parts[$wcIdx]
    $remaining = if ($wcIdx + 1 -lt $parts.Length) { $parts[($wcIdx + 1)..($parts.Length - 1)] } else { @() }
    try {
        # 变量名不用 $matches：那是 PowerShell 自动变量（-match 的捕获组容器），
        # 在同一作用域内赋值会遮蔽它，一旦本函数将来引入 -match 判断就会静默读到错值。
        $hits = if ($remaining.Length -eq 0) {
            [System.IO.Directory]::GetFileSystemEntries($basePath, $wildcard)
        } else {
            [System.IO.Directory]::GetDirectories($basePath, $wildcard)
        }
        foreach ($mt in $hits) {
            if ($remaining.Length -eq 0) { [void]$results.Add($mt) }
            else { Resolve-Recursive (Join-Path $mt ([string]::Join('\', $remaining))) $results }
        }
    } catch { }
}

function Resolve-Paths {
    param($rawPath, $varMap)
    $results = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    Resolve-Recursive (Expand-Variables $rawPath $varMap) $results
    if ($rawPath.IndexOf('%ProgramFiles%', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $x86 = Replace-CI $rawPath '%ProgramFiles%' '%ProgramFiles(x86)%'
        Resolve-Recursive (Expand-Variables $x86 $varMap) $results
    }
    return $results
}

# ===================== 检测门控（DetectionService.IsInstalled 等价） =====================
function Get-RegHive {
    param($token)
    switch ($token.ToUpper()) {
        'HKLM'             { return [Microsoft.Win32.Registry]::LocalMachine }
        'HKEY_LOCAL_MACHINE' { return [Microsoft.Win32.Registry]::LocalMachine }
        'HKCU'             { return [Microsoft.Win32.Registry]::CurrentUser }
        'HKEY_CURRENT_USER'  { return [Microsoft.Win32.Registry]::CurrentUser }
        'HKU'              { return [Microsoft.Win32.Registry]::Users }
        'HKEY_USERS'       { return [Microsoft.Win32.Registry]::Users }
        'HKCR'             { return [Microsoft.Win32.Registry]::ClassesRoot }
        'HKEY_CLASSES_ROOT'  { return [Microsoft.Win32.Registry]::ClassesRoot }
        'HKCC'             { return [Microsoft.Win32.Registry]::CurrentConfig }
        'HKEY_CURRENT_CONFIG' { return [Microsoft.Win32.Registry]::CurrentConfig }
        default            { return $null }
    }
}

function Test-Registry {
    param($regPath)
    try {
        $pipe = $regPath.LastIndexOf('|')
        $rp = $regPath; $val = $null
        if ($pipe -ge 0) { $rp = $regPath.Substring(0, $pipe); $val = $regPath.Substring($pipe + 1) }
        $slash = $rp.IndexOf('\')
        if ($slash -lt 0) { return $false }
        $hiveTok = $rp.Substring(0, $slash)
        $sub = $rp.Substring($slash + 1)
        $hive = Get-RegHive $hiveTok
        if ($null -eq $hive) { return $false }
        $key = $hive.OpenSubKey($sub, $false)
        if ($null -eq $key) { return $false }
        if ([string]::IsNullOrEmpty($val)) { return $true }
        return ($null -ne $key.GetValue($val))
    } catch { return $false }
}

function Test-PathExpanded {
    param($raw, $varMap)
    return (Test-Path -LiteralPath (Expand-Variables $raw $varMap))
}

function Test-SpecialDetect {
    param($code, $varMap)
    switch ($code.ToUpper()) {
        'DET_CHROME'    { return (Test-PathExpanded '%LocalAppData%\Google\Chrome\User Data' $varMap) }
        'DET_FIREFOX'   { return (Test-PathExpanded '%AppData%\Mozilla\Firefox' $varMap) }
        'DET_IE'        { return (Test-Registry 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\IEXPLORE.EXE') }
        'DET_THUNDERBIRD' { return (Test-PathExpanded '%AppData%\Thunderbird' $varMap) }
        'DET_OPERA'     { return (Test-PathExpanded '%AppData%\Opera Software\Opera Stable' $varMap) }
        'DET_EDGE'      { return (Test-PathExpanded '%LocalAppData%\Microsoft\Edge\User Data' $varMap) }
        'DET_WINSTORE'  { return (Test-PathExpanded '%LocalAppData%\Packages' $varMap) }
        default         { return $false }
    }
}

function Test-DetectFile {
    param($raw, $varMap)
    $p = Expand-Variables $raw $varMap
    if ($p.Contains('*') -or $p.Contains('?')) {
        try { return ((Resolve-Paths $raw $varMap).Count -gt 0) } catch { return $false }
    }
    # 处理 DetectFile 含 "|子串/值" 高级语法的情形：仅校验文件路径是否存在，
    # 避免 "C:\Windows|SIGVERIF.TXT" 这类含管道符的路径直接喂给 Test-Path 触发非法字符异常。
    $pipe = $p.LastIndexOf('|')
    if ($pipe -ge 0) { $p = $p.Substring(0, $pipe) }
    try { return (Test-Path -LiteralPath $p) } catch { return $false }
}

function Test-Installed {
    param($entry, $varMap)
    if ($entry.SpecialDetect -and $entry.SpecialDetect.Length -gt 0) {
        if (Test-SpecialDetect $entry.SpecialDetect $varMap) { return $true }
    }
    foreach ($d in $entry.DetectKeys)  { if (Test-Registry $d)    { return $true } }
    foreach ($f in $entry.DetectFiles) { if (Test-DetectFile $f $varMap) { return $true } }
    return $false
}

# ===================== 分类解析（CategoryResolver 等价） =====================
$CategoryMap = @{
    3006 = 'Microsoft Edge'; 3021 = 'Applications'; 3022 = 'Internet'; 3023 = 'Multimedia';
    3024 = 'Utilities'; 3025 = 'Windows'; 3026 = 'Firefox'; 3027 = 'Opera'; 3028 = 'Safari';
    3029 = 'Google Chrome'; 3030 = 'Thunderbird'; 3031 = 'Microsoft Store'; 3033 = 'Vivaldi';
    3034 = 'Brave'; 3035 = 'Opera GX'; 3036 = 'Spotify'; 3037 = 'Avast Secure Browser';
    3038 = 'AVG Secure Browser'; 3039 = 'Arc Browser'; 3040 = 'iTunes'; 3042 = 'WhatsApp';
    3043 = 'Norton Private Browser'; 3044 = 'Avira Secure Browser'
}

function Resolve-Category {
    param($entry)
    if ($null -ne $entry.LangSecRef -and $CategoryMap.ContainsKey($entry.LangSecRef)) {
        return $CategoryMap[$entry.LangSecRef]
    }
    if ($entry.Section -and $entry.Section.Length -gt 0) { return $entry.Section }
    return 'Other Applications'
}

# ===================== 字段解析 =====================
function Parse-FileKey {
    param($value)
    $parts = $value -split '\|'
    $path = $parts[0]
    $pattern = '*'; $recurse = $false; $removeself = $false
    for ($i = 1; $i -lt $parts.Length; $i++) {
        $t = $parts[$i].Trim()
        if ($t -eq 'RECURSE') { $recurse = $true }
        elseif ($t -eq 'REMOVESELF') { $removeself = $true }
        else { $pattern = $t }
    }
    return [PSCustomObject]@{ Path = $path; Pattern = $pattern; Recurse = $recurse; RemoveSelf = $removeself; Patterns = ($pattern -split ';') }
}

function Parse-ExcludeKey {
    param($value)
    $parts = $value -split '\|'
    $type = if ($parts.Length -gt 0) { $parts[0].Trim().ToUpper() } else { '' }
    $folder = if ($parts.Length -gt 1) { $parts[1] } else { '' }
    $pattern = if ($parts.Length -gt 2) { $parts[2] } else { '' }
    return [PSCustomObject]@{ Type = $type; Folder = $folder; Pattern = $pattern }
}

function Expand-FileKey {
    param($fk, $varMap)
    $out = [System.Collections.Generic.List[string]]::new()
    $dirs = Resolve-Paths $fk.Path $varMap
    foreach ($dir in $dirs) {
        if ($fk.RemoveSelf) {
            # REMOVESELF：目标是目录本身。若解析结果为文件（final-* 返回内容），取其父目录
            $target = if ([System.IO.Directory]::Exists($dir)) { $dir } else { Split-Path $dir -Parent }
            if ($target -and (Test-Path -LiteralPath $target)) { [void]$out.Add($target) }
            continue
        }
        if ([System.IO.Directory]::Exists($dir)) {
            foreach ($pat in $fk.Patterns) {
                $p = if ([string]::IsNullOrWhiteSpace($pat)) { '*' } else { $pat }
                try {
                    $opt = if ($fk.Recurse) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }
                    foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, $p, $opt)) { [void]$out.Add($f) }
                } catch { }
            }
        } elseif ([System.IO.File]::Exists($dir)) {
            # 解析结果为文件（如路径段 final-* 返回目录内容）：按 pattern 直接匹配
            foreach ($pat in $fk.Patterns) {
                $p = if ([string]::IsNullOrWhiteSpace($pat)) { '*' } else { $pat }
                if ($dir -like $p) { [void]$out.Add($dir) }
            }
        }
    }
    return $out
}

function Test-Excluded {
    param($filePath, $excludeList, $varMap)
    foreach ($ex in $excludeList) {
        $folder = (Expand-Variables $ex.Folder $varMap).TrimEnd('\')
        if ($ex.Type -eq 'FILE') {
            $parent = Split-Path $filePath -Parent
            if ($parent -and ($parent -eq $folder)) {
                $name = Split-Path $filePath -Leaf
                if ([string]::IsNullOrEmpty($ex.Pattern) -or $ex.Pattern -eq '*' -or ($name -like $ex.Pattern)) { return $true }
            }
        } elseif ($ex.Type -eq 'PATH') {
            if ($filePath -eq $folder -or $filePath.StartsWith($folder + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                if ([string]::IsNullOrEmpty($ex.Pattern) -or $ex.Pattern -eq '*' -or (Split-Path $filePath -Leaf) -like $ex.Pattern) { return $true }
            }
        }
    }
    return $false
}

function Test-Valid {
    param($e)
    $hasDetect = ($e.DetectKeys.Count -gt 0 -or $e.DetectFiles.Count -gt 0 -or ($e.SpecialDetect -and $e.SpecialDetect.Length -gt 0))
    $hasTarget = ($e.FileKeys.Count -gt 0 -or $e.RegKeys.Count -gt 0)
    return ($hasDetect -and $hasTarget)
}

# ===================== 解析 INI =====================
function Parse-Winapp2 {
    param($content)
    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $cur = $null
    $lines = $content -split '\r?\n'
    foreach ($line in $lines) {
        $l = $line.Trim()
        if ($l.Length -eq 0 -or $l[0] -eq ';' -or $l[0] -eq '#') { continue }
        if ($l.StartsWith('[') -and $l.EndsWith(']')) {
            if ($cur -and (Test-Valid $cur)) { [void]$entries.Add($cur) }
            $rawName = $l.Substring(1, $l.Length - 2).Trim()
            # 精确跳过元数据节（避免 -like 'Winapp2*' 误伤以 Winapp2 开头的应用节）
            if ($rawName -eq 'Winapp2' -or $rawName -eq 'Version') { $cur = $null; continue }
            # 节名末尾的 " *"（空格+星号）是 Winapp2 的排版标记（社区贡献条目），仅作显示用途、
            # 由解析器静默剥离（对齐 FluentCleaner 规范），并非"默认禁用"语义——禁用语义由 Default=False 键表达。
            # 因此只从显示名剥离 "*"，不据此设置 Default（F-3 修正：撤销原 F-1 的 *->Default=$false 误判）。
            $name = $rawName.TrimEnd('*').TrimEnd()
            $cur = [PSCustomObject]@{
                Name = $name
                LangSecRef = $null; Section = ''; SpecialDetect = ''; Warning = ''; Default = $null
                DetectKeys = [System.Collections.ArrayList]::new()
                DetectFiles = [System.Collections.ArrayList]::new()
                FileKeys = [System.Collections.ArrayList]::new()
                RegKeys = [System.Collections.ArrayList]::new()
                ExcludeKeys = [System.Collections.ArrayList]::new()
            }
            continue
        }
        if ($null -eq $cur) { continue }
        $eq = $l.IndexOf('=')
        if ($eq -lt 0) { continue }
        $key = $l.Substring(0, $eq).Trim()
        $val = $l.Substring($eq + 1).Trim()
        if ($val.Length -eq 0) { continue }
        if ($key -eq 'LangSecRef') { if ($val -match '^\d+$') { $cur.LangSecRef = [int]$val } }
        elseif ($key -eq 'Section') { $cur.Section = $val }
        elseif ($key -eq 'SpecialDetect') { $cur.SpecialDetect = $val }
        elseif ($key -eq 'Warning') { $cur.Warning = $val }
        elseif ($key -eq 'Default') { $cur.Default = ($val -eq 'True') }
        elseif ($key -match '^Detect\d*$') { [void]$cur.DetectKeys.Add($val) }
        elseif ($key -match '^DetectFile\d*$') { [void]$cur.DetectFiles.Add($val) }
        elseif ($key -match '^FileKey\d+$') { [void]$cur.FileKeys.Add((Parse-FileKey $val)) }
        elseif ($key -match '^RegKey\d+$') { [void]$cur.RegKeys.Add($val) }
        elseif ($key -match '^ExcludeKey\d+$') { [void]$cur.ExcludeKeys.Add((Parse-ExcludeKey $val)) }
    }
    if ($cur -and (Test-Valid $cur)) { [void]$entries.Add($cur) }
    return $entries
}

# ===================== 主流程 =====================
if (-not (Test-Path -LiteralPath $Winapp2Path)) { Write-Error ("规则文件不存在: {0}" -f $Winapp2Path); exit 1 }

$varMap = Get-VarMap
$content = [System.IO.File]::ReadAllText($Winapp2Path)
$entries = Parse-Winapp2 $content
Write-Output ('已解析规则条目: {0}' -f $entries.Count)

$rows = [System.Collections.Generic.List[PSCustomObject]]::new()
$stats = @{ Installed = 0; Emitted = 0; Excluded = 0; RegSkipped = 0; Processed = 0 }
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($e in $entries) {
    if ($MaxEntries -gt 0 -and $stats.Processed -ge $MaxEntries) { break }
    if (-not (Test-Installed $e $varMap)) { continue }
    $stats.Processed++
    $stats.Installed++

    # FileKey 展开
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($fk in $e.FileKeys) {
        $expanded = Expand-FileKey $fk $varMap
        foreach ($p in $expanded) { [void]$paths.Add($p) }
    }

    # RegKey（默认忽略；开启时仅列为备注）
    if ($e.RegKeys.Count -gt 0) {
        if ($IncludeReg) {
            foreach ($rk in $e.RegKeys) {
                # 注意：不使用 "REG::" 前缀——cleanup_cd 的 Split-Path 会把 REG:: 误判为
                # PowerShell 提供程序而崩溃。RegKey 仅作备注项，用纯注册表路径串 + 明确 Reason 标记，
                # 由 cleanup_cd 归入"待确认"（DryRun 不删，Execute 下 File.Delete 对注册表串会安全失败）。
                [void]$rows.Add([PSCustomObject]@{
                    FullPath = $rk; Extension = ''; SizeMB = 0.0
                    LastWriteTime = ''; Category = (Resolve-Category $e); Cleanable = '需确认'
                    Reason = ('[注册表规则-仅备注,cleanup_cd 不删注册表] {0}: {1}' -f $e.Name, $rk)
                })
                $stats.Emitted++
            }
        } else {
            $stats.RegSkipped += $e.RegKeys.Count
        }
    }

    # ExcludeKey 豁免
    $final = $paths | Where-Object { -not (Test-Excluded $_ $e.ExcludeKeys $varMap) }
    $excludedCount = $paths.Count - $final.Count
    $stats.Excluded += $excludedCount

    $cat = Resolve-Category $e
    $cleanable = if ($Winapp2AutoDelete -and $e.Default -ne $false) { '自动清理' } else { '需确认' }
    $reason = 'Winapp2规则: ' + $e.Name
    if ($e.Warning -and $e.Warning.Length -gt 0) { $reason += (' [警告: ' + $e.Warning + ']') }

    foreach ($p in $final) {
        $ext = ''; $size = 0.0; $lwt = ''
        try {
            if ([System.IO.Directory]::Exists($p)) {
                $di = [System.IO.DirectoryInfo]$p
                $ext = ''; $size = 0.0; $lwt = $di.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            } else {
                $fi = [System.IO.FileInfo]$p
                $ext = if ($fi.Extension) { $fi.Extension.ToLower() } else { '' }
                $size = [math]::Round($fi.Length / 1MB, 4)
                $lwt = $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            }
        } catch { }
        [void]$rows.Add([PSCustomObject]@{
            FullPath = $p; Extension = $ext; SizeMB = $size
            LastWriteTime = $lwt; Category = $cat; Cleanable = $cleanable; Reason = $reason
        })
        $stats.Emitted++
    }

    if ($stats.Processed % 200 -eq 0) {
        Write-Progress -Activity 'Winapp2 扩展' -Status ('已处理 {0} 条已装应用' -f $stats.Processed) -CurrentOperation $e.Name
    }
}
Write-Progress -Activity 'Winapp2 扩展' -Completed
$sw.Stop()

# ===================== 写出 CSV（与 cleanup_cd.ps1 同构，UTF-8 BOM + RFC4180 引号） =====================
function Quote-Csv { param($v) '"{0}"' -f ($v -replace '"', '""') }

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('"FullPath","Extension","SizeMB","LastWriteTime","Category","Cleanable","Reason"')
foreach ($r in $rows) {
    [void]$sb.AppendLine(
        (Quote-Csv $r.FullPath) + ',' + (Quote-Csv $r.Extension) + ',' +
        (Quote-Csv $r.SizeMB) + ',' + (Quote-Csv $r.LastWriteTime) + ',' +
        (Quote-Csv $r.Category) + ',' + (Quote-Csv $r.Cleanable) + ',' + (Quote-Csv $r.Reason)
    )
}
[System.IO.File]::WriteAllText($OutCsv, $sb.ToString(), [System.Text.UTF8Encoding]::new($true))

Write-Output ('耗时: {0:N1}s' -f $sw.Elapsed.TotalSeconds)
Write-Output ('已装应用(通过检测): {0}' -f $stats.Installed)
Write-Output ('已跳过 RegKey(未启用 -IncludeReg): {0}' -f $stats.RegSkipped)
Write-Output ('ExcludeKey 豁免命中: {0}' -f $stats.Excluded)
Write-Output ('输出处置行: {0}' -f $stats.Emitted)
Write-Output ('已写出 CSV: {0}' -f $OutCsv)
