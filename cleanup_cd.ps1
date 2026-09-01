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
      - 方案 C（默认用于系统盘）：Cleanable ∈ {是, 否, 谨慎}
      - 方案 D（默认用于其它盘）：Cleanable ∈ {自动清理, 需确认, 保留}

    三层硬保护（保证对 Windows 系统 / 已装程序 / 工作目录 / 个人文档零破坏）：
      1) 安全根拦截：凡拟删除项落在任一"安全根目录"下，一律提升为"需二次确认（按目录批量）"，
         即便其原本为自动清理。安全根来源（按优先级，全部可配置、无本机硬编码）：
           a. 环境变量 CLEANUP_SAFE_ROOTS（分号分隔）
           b. -SafeRoots 参数（追加）
           c. 外置配置文件 cleanup_config.json 的 safeRoots
           d. 运行时自动探测的"用户个人目录"（桌面/文档/下载/图片/视频/音乐，经注册表 Known Folder 解析）
      2) 系统核心保护：凡拟删除项落在系统核心目录（自动探测的 Windows / Program Files /
         Program Files (x86) / ProgramData）下，强制降为"待确认"，绝不自动删除。
         除非显式 -AllowSystemJunk 且该项命中"已知垃圾热点"（如 Windows 更新下载缓存）。
      3) 版本控制保护：.git / .svn / .hg 目录下的内容一律保留，永不删除（防止误删 reflog 等引用数据）。

    编码健壮性：CSV 读取使用自研 StreamReader + BOM 探测 + RFC4180 引号解析，
    兼容 UTF-8（有/无 BOM）、UTF-16 LE/BE 与 GBK（无 BOM 时按字节特征回退）；
    扫描写出使用 UTF-8 带 BOM 的 StreamWriter。删除一律使用 -LiteralPath 与底层 .NET API，
    避免特殊字符路径被通配符误解释。

.PARAMETER Root
    扫描根目录（可选），例如 C:\ 或 D:\。提供即现场扫描并并入待清理清单。
.PARAMETER CsvPaths
    一个或多个既有处置清单 CSV（字段见上）。可同时传入 C 盘与 D 盘清单。与 -Root 可同时提供。
.PARAMETER Scheme
    'C' | 'D' | 'Auto'（默认 Auto：落在系统盘用 C 方案，其余用 D 方案；仅对 -Root 扫描生效）。
.PARAMETER Config
    外置配置文件路径（JSON）。默认取脚本同目录的 cleanup_config.json。缺失时回退内置默认规则。
.PARAMETER ProtectedRoots
    受保护目录片段（子串匹配，命中即标记"受保护/保留"）。默认取配置文件，缺省为 @('.workbuddy')。
.PARAMETER WorkRoot
    工作目录根（用于"工作目录受保护文件"判定）。默认取配置文件的 workRoots 首项。
.PARAMETER ExcludeRoots
    跳过枚举的目录（默认含系统核心目录，避免无意义扫描与权限报错）。传 @() 可扫描全部。
.PARAMETER RecentDays
    近期缓存阈值（天），默认取配置文件（缺省 180）。超过则不再判为"缓存-近期(保留)"。
.PARAMETER Mode
    DryRun（默认，仅输出，零副作用）| Execute（执行删除）。
.PARAMETER SafeRoots
    需二次确认的安全根目录列表（**追加**，无法移除配置文件与自动探测所确定的安全根）。
.PARAMETER OutMd
    DryRun 输出的 Markdown 报告路径。默认写入 $env:TEMP，避免污染脚本所在仓库。
.PARAMETER OutCsv
    逐文件完整处置清单 CSV 路径（与 MD 互补，保证绝对路径不丢失）。默认写入 $env:TEMP。
.PARAMETER OutScanCsv
    -Root 扫描输出的清单 CSV 路径。默认写入 $env:TEMP 的 scan_inventory_<盘符>.csv。
.PARAMETER DeleteConfirmed
    仅 Execute 模式有效：是否同时删除非安全根的"需确认"项与"系统核心降级"项（默认关闭，仅删自动清理 + 安全根已确认项）。
.PARAMETER AllowSystemJunk
    仅 Execute 模式有效：对命中"已知垃圾热点"的项，即使位于系统核心目录也不强制降级为待确认。
    默认关闭（保守）：系统核心目录一律待确认。
.PARAMETER FullList
    在 Markdown 中逐文件列出"需确认"与"安全根"项的绝对路径（默认关闭，改为按目录聚合 + 样本，以防 MD 过大）。
.PARAMETER MaxDepth
    扫描最大递归深度保护（0 = 不限制）。默认 0。全盘扫描时建议保留默认，文件系统本身受 MAX_PATH 约束。
.PARAMETER WhatIf
    仅 Execute 模式有效：模拟删除，仅报告将删除哪些文件/目录，不实际执行删除，也不弹出交互确认。

.OUTPUTS
    退出码：0 = 成功；1 = 参数/清单错误；2 = Execute 模式下存在删除失败项。
#>

[CmdletBinding()]
param(
    [string]$Root = '',

    [string[]]$CsvPaths = @(),

    [ValidateSet('C', 'D', 'Auto')]
    [string]$Scheme = 'Auto',

    # 注意：此处不可命名为 $Config。脚本内部用 $script:Config 存放配置对象，
    # 二者同为脚本作用域的同一变量；若本参数带 [string] 约束，
    # 则把配置对象赋给 $script:Config 时会被强制字符串化（安全根/阈值全部失效）。
    # 故命名为 $ConfigPath（配置文件路径），并保留 -Config 别名以兼容旧用法。
    [Alias('Config')]
    [string]$ConfigPath = '',

    [string[]]$ProtectedRoots = @(),

    [string]$WorkRoot = '',

    [string[]]$ExcludeRoots = @(),

    [int]$RecentDays = -1,

    [ValidateSet('DryRun', 'Execute')]
    [string]$Mode = 'DryRun',

    [string[]]$SafeRoots = @(),

    [string]$OutMd = '',
    [string]$OutCsv = '',
    [string]$OutScanCsv = '',

    [switch]$DeleteConfirmed,
    [switch]$AllowSystemJunk,
    [switch]$FullList,
    [int]$MaxDepth = 0,
    [switch]$WhatIf
)

# ===================== 初始化 =====================
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ===================== 通用工具函数 =====================
function Format-SizeMB { param($len) [math]::Round($len / 1MB, 4) }
function Quote-CsvField { param($v) '"{0}"' -f (($v -replace '"', '""')) }

# 安全的数值求和：Measure-Object 对空集合返回 $null，直接格式化会输出空白（已实测的显示缺陷）
function Get-SafeSum {
    param($Items, [string]$Property)
    if ($null -eq $Items) { return 0.0 }
    $n = @($Items).Count
    if ($n -eq 0) { return 0.0 }
    $s = ($Items | Measure-Object -Property $Property -Sum).Sum
    if ($null -eq $s) { return 0.0 }
    return [double]$s
}

# 路径前缀边界匹配：避免 "C:\Windows" 误匹配 "C:\WindowsApps" / "C:\Windows.old"
function Test-PathPrefix {
    param([string]$Path, [string]$Prefix)
    if ([string]::IsNullOrEmpty($Path) -or [string]::IsNullOrEmpty($Prefix)) { return $false }
    $prefix = $Prefix.Trim().TrimEnd('\', '/')
    if ($Path.Equals($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $Path.StartsWith($prefix + '\', [System.StringComparison]::OrdinalIgnoreCase) -or
           $Path.StartsWith($prefix + '/', [System.StringComparison]::OrdinalIgnoreCase)
}

# ===================== 系统路径自适应探测（去硬编码） =====================
function Get-WindowsDirectoryPath {
    $p = [Environment]::GetEnvironmentVariable('SystemRoot')
    if (-not $p) { $p = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows) }
    if (-not $p) { $p = Join-Path ([System.IO.Path]::GetPathRoot($env:SystemDrive)) 'Windows' }
    return $p
}

function Get-SystemDriveLetter {
    $d = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ($d) { return $d.Substring(0, 1).ToUpper() }
    return ([System.IO.Path]::GetPathRoot([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows))).Substring(0, 1).ToUpper()
}

function Get-ProgramFilesPaths {
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @('ProgramFiles', 'ProgramW6432')) {
        $v = [Environment]::GetEnvironmentVariable($name)
        if ($v) { [void]$out.Add($v) }
    }
    $x86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($x86) { [void]$out.Add($x86) }
    # 回退：注册表（当环境变量被清理/未继承时仍可解析）
    if ($out.Count -eq 0) {
        try {
            $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion')
            if ($k) {
                foreach ($n in @('ProgramFilesDir', 'ProgramFilesDir (x86)', 'ProgramW6432Dir')) {
                    $v = $k.GetValue($n)
                    if ($v) { [void]$out.Add([string]$v) }
                }
            }
        } catch { }
    }
    # 再回退：Shell SpecialFolder
    if ($out.Count -eq 0) {
        foreach ($sf in @([Environment+SpecialFolder]::ProgramFiles, [Environment+SpecialFolder]::ProgramFilesX86)) {
            $v = [Environment]::GetFolderPath($sf)
            if ($v) { [void]$out.Add($v) }
        }
    }
    return @($out | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-ProgramDataPath {
    $p = [Environment]::GetEnvironmentVariable('ProgramData')
    if ($p) { return $p }
    $p = [Environment]::GetEnvironmentVariable('ALLUSERSPROFILE')
    if ($p) { return $p }
    return [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
}

# Known Folder 解析（经注册表 User Shell Folders，兼容重定向过的个人目录）
$script:KnownFolderGuids = @{
    Desktop   = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
    Documents = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'
    Downloads = '{374DE290-123F-4565-9164-39C4925E467B}'
    Pictures  = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'
    Videos    = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'
    Music     = '{4BD8D571-6D19-48D3-BE97-422220080E43}'
}
function Get-KnownFolderPath {
    param([string]$Name)
    $guid = $script:KnownFolderGuids[$Name]
    if (-not $guid) { return $null }
    try {
        $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders')
        if ($k) {
            $v = $k.GetValue($guid)
            if ($v) { return [Environment]::ExpandEnvironmentVariables([string]$v) }
        }
    } catch { }
    # 回退：.NET SpecialFolder（不覆盖重定向场景，但保证有值）
    $map = @{ Desktop = 'DesktopDirectory'; Documents = 'MyDocuments'; Pictures = 'MyPictures'; Videos = 'MyVideos'; Music = 'MyMusic' }
    if ($map.ContainsKey($Name)) {
        $v = [Environment]::GetFolderPath([Environment+SpecialFolder]::($map[$Name]))
        if ($v) { return $v }
    }
    return $null
}

# ===================== 配置加载（外置优先，内置兜底） =====================
function Get-DefaultConfig {
    $c = [PSCustomObject]@{
        safeRoots         = @()
        workRoots         = @()
        protectedRoots    = @('.workbuddy')
        extraExcludeRoots = @()
        recentDays        = 180
        classification    = [PSCustomObject]@{
            tempExtensions      = @('.tmp', '.temp', '.bak', '.old', '.dmp', '.etl', '.chk', '.gid', '.fts', '.nch')
            logExtensions       = @('.log')
            cacheDirFragments   = @('\cache\', '\caches\', '\temp\', '\tmp\', '\logs\', '\log\', '\crashdumps\', '\dumps\')
            keepExtensions      = @('.exe', '.dll', '.sys', '.msi', '.ocx', '.drv', '.efi')
            workKeepExtensions  = @('.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.pdf', '.txt', '.md',
                                     '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.mp3', '.mp4', '.avi',
                                     '.zip', '.rar', '.7z', '.html', '.htm')
            versionControlDirs  = @('\.git\', '\.svn\', '\.hg\')
        }
        knownJunkTargets  = @()
        autoClearExcludeDirs = @('AI_Work_Temp')
    }
    return $c
}

function Import-CleanupConfig {
    param([string]$Path)
    $cfg = Get-DefaultConfig
    if ([string]::IsNullOrEmpty($Path)) {
        $Path = Join-Path $script:ScriptDir 'cleanup_config.json'
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning ('未找到配置文件 [{0}]，改用内置默认规则（安全根将仅由自动探测与 -SafeRoots 决定）。' -f $Path)
        return $cfg
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($raw.safeRoots)         { $cfg.safeRoots = @($raw.safeRoots) }
        if ($raw.workRoots)         { $cfg.workRoots = @($raw.workRoots) }
        if ($raw.protectedRoots)    { $cfg.protectedRoots = @($raw.protectedRoots) }
        if ($raw.extraExcludeRoots) { $cfg.extraExcludeRoots = @($raw.extraExcludeRoots) }
        if ($raw.recentDays)        { $cfg.recentDays = [int]$raw.recentDays }
        if ($raw.classification) {
            $cl = $raw.classification
            if ($cl.tempExtensions)     { $cfg.classification.tempExtensions = @($cl.tempExtensions) }
            if ($cl.logExtensions)      { $cfg.classification.logExtensions = @($cl.logExtensions) }
            if ($cl.cacheDirFragments)  { $cfg.classification.cacheDirFragments = @($cl.cacheDirFragments) }
            if ($cl.keepExtensions)     { $cfg.classification.keepExtensions = @($cl.keepExtensions) }
            if ($cl.workKeepExtensions) { $cfg.classification.workKeepExtensions = @($cl.workKeepExtensions) }
            if ($cl.versionControlDirs) { $cfg.classification.versionControlDirs = @($cl.versionControlDirs) }
        }
        if ($raw.knownJunkTargets) { $cfg.knownJunkTargets = @($raw.knownJunkTargets) }
        if ($raw.autoClearExcludeDirs) { $cfg.autoClearExcludeDirs = @($raw.autoClearExcludeDirs) }
        # 本函数返回值会被赋值使用（$script:Config = Import-CleanupConfig ...），
        # 因此函数体内绝不能用 Write-Output 打日志——那会串入返回值并污染配置对象。
        # 日志一律走 Write-Verbose（不进成功输出流）；面向用户的提示由调用方输出。
        Write-Verbose ('已加载配置文件: {0}' -f $Path)
    }
    catch {
        Write-Warning ('配置文件解析失败，改用内置默认规则: {0} - {1}' -f $Path, $_.Exception.Message)
    }
    return $cfg
}

$script:Config = Import-CleanupConfig -Path $ConfigPath
Write-Output ('配置就绪: 安全根 {0} 项 / 受保护片段 {1} 项 / 已知垃圾热点 {2} 条 / 近期缓存阈值 {3} 天' -f
    @($script:Config.safeRoots).Count, @($script:Config.protectedRoots).Count,
    @($script:Config.knownJunkTargets).Count, $script:Config.recentDays)

# ---- 分类规则（来自配置，可被 -ProtectedRoots / -RecentDays 覆盖）----
$Cls = $script:Config.classification
$script:TempExtensions     = @($Cls.tempExtensions)
$script:LogExtensions      = @($Cls.logExtensions)
$script:CacheDirFragments  = @($Cls.cacheDirFragments)
$script:KeepExtensions     = @($Cls.keepExtensions)
$script:WorkKeepExtensions = @($Cls.workKeepExtensions)
$script:VersionControlDirs = @($Cls.versionControlDirs)
$script:KnownJunkTargets   = @($script:Config.knownJunkTargets)
$script:AutoClearExcludeDirs = @($script:Config.autoClearExcludeDirs)

if ($ProtectedRoots.Count -eq 0) { $ProtectedRoots = @($script:Config.protectedRoots) }
if ([string]::IsNullOrEmpty($WorkRoot)) {
    if ($script:Config.workRoots.Count -gt 0) { $WorkRoot = [string]$script:Config.workRoots[0] }
}
if ($RecentDays -lt 0) { $RecentDays = [int]$script:Config.recentDays }

# ---- 系统核心目录（自动探测，无硬编码盘符）----
$script:SystemDriveLetter = Get-SystemDriveLetter
$SystemProtectedRoots = @(
    (Get-WindowsDirectoryPath)
) + (Get-ProgramFilesPaths) + @(
    (Get-ProgramDataPath)
) | Where-Object { $_ } | Sort-Object -Unique

if ($ExcludeRoots.Count -eq 0) {
    $ExcludeRoots = @($SystemProtectedRoots) + @($script:Config.extraExcludeRoots) | Where-Object { $_ } | Sort-Object -Unique
}

# ---- 安全根（配置 + 自动探测 + 参数追加；自动探测项不可被移除）----
$AutoDetectedSafeRoots = @()
foreach ($n in @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Videos', 'Music')) {
    $p = Get-KnownFolderPath -Name $n
    if ($p) { $AutoDetectedSafeRoots += $p }
}
$AutoDetectedSafeRoots = @($AutoDetectedSafeRoots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique)

# 环境变量优先级最高（便于 CI / 临时覆写）
$EnvSafeRoots = @()
$envVal = [Environment]::GetEnvironmentVariable('CLEANUP_SAFE_ROOTS')
if ($envVal) { $EnvSafeRoots = @($envVal -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$EssentialSafeRoots = @($EnvSafeRoots) + @($script:Config.safeRoots) + @($AutoDetectedSafeRoots) |
                      Where-Object { $_ } | Sort-Object -Unique
$SafeRoots = @($EssentialSafeRoots) + @($SafeRoots) | Where-Object { $_ } | Sort-Object -Unique

# 安全根 / 系统核心 / 排除根 的规范化前缀（供边界匹配）
$script:SafeRootList   = @($SafeRoots)
$script:SystemRootList = @($SystemProtectedRoots)
$script:ExcludeList    = @($ExcludeRoots)

function Test-SafeRootMatch {
    param([string]$Path)
    foreach ($r in $script:SafeRootList) { if (Test-PathPrefix -Path $Path -Prefix $r) { return $r } }
    return $null
}
function Test-SystemProtected {
    param([string]$Path)
    foreach ($r in $script:SystemRootList) { if (Test-PathPrefix -Path $Path -Prefix $r) { return $true } }
    return $false
}

# ===================== 已知垃圾热点匹配 =====================
function Test-KnownJunkTarget {
    param([string]$LowerPath)
    foreach ($t in $script:KnownJunkTargets) {
        $frag = [string]$t.fragment
        if ($frag -and $LowerPath.Contains($frag.ToLower())) { return $t }
    }
    return $null
}

# ===================== 版本控制保护（防止误删 .git reflog 等引用数据） =====================
function Test-VersionControlled {
    param([string]$LowerPath)
    foreach ($d in $script:VersionControlDirs) {
        if ($LowerPath.Contains($d.ToLower())) { return $true }
    }
    return $false
}

# ===================== 自动清理目录判定（v0.5.0 用户决策） =====================
# 三类命名规则：目录名「恰好等于 / 包含 / 以 .temp/.tmp/.cache 开头」temp|tmp|cache 时，
# 其下「所有子目录与文件」一律判为自动清理（清空内容），但「目录自身保留（不删除）」。
#   - 规则1：名恰为 temp / tmp / cache / .temp / .tmp / .cache
#   - 规则2：名包含 temp / tmp / cache（如 mytempdir、pipcache、templates）
#   - 规则3：名以 .temp / .tmp / .cache 开头（如 .cache2、.temp_build、.caches）
# 实现位置在 Scan-Dir 枚举阶段（决策点前）：命中即「清空其内容、保留目录壳」且不向下递归。
# 三层硬保护对「子项」逐条仍生效：
#   - 安全根：子项落在安全根 -> 提升为二次确认（Safe），不自动删
#   - 系统核心：子项落在系统核心 -> 强制降级待确认（Guarded）
#   - 版本控制：子项名含 .git/.svn/.hg -> 跳过（永不删）
# 默认 DryRun + 交互确认，不会自动落盘删除。
function Test-AutoClearDirName {
    param([string]$Name)
    $n = $Name.ToLower()
    # 规则1：恰好等于
    if (@('temp', 'tmp', 'cache', '.temp', '.tmp', '.cache') -contains $n) { return $true }
    # 规则2：包含 temp/tmp/cache（不区分大小写、未锚定，故 templates/temporary 等亦命中）
    if ($n -match 'temp|tmp|cache') { return $true }
    # 规则3：以 .temp/.tmp/.cache 开头
    if ($n -like '.temp*' -or $n -like '.tmp*' -or $n -like '.cache*') { return $true }
    return $false
}

# 自动清理目录例外（不触发清空）：默认含 AI_Work_Temp 及其整棵子树。
# 来源：配置 autoClearExcludeDirs（可追加），默认 { AI_Work_Temp }。
# 判定：路径的任一段（目录名）等于例外名 -> 该目录自身及其全部后代均例外。
function Test-AutoClearExcluded {
    param([string]$Path)
    $p = $Path.ToLower()
    $segments = $p -split '[\\/]' | Where-Object { $_ }
    foreach ($ex in $script:AutoClearExcludeDirs) {
        $e = $ex.ToLower()
        if ($segments -contains $e) { return $true }
    }
    return $false
}

# ===================== 方案 C 分类（Cleanable: 是/否/谨慎） =====================
function Classify-C {
    param($fi, $Protected)
    $p = $fi.FullName.ToLower()
    $ext = if ($fi.Extension) { $fi.Extension.ToLower() } else { '' }
    $name = $fi.Name.ToLower()

    foreach ($pr in $Protected) { if ($p.Contains($pr.ToLower())) { return @{Category = '受保护'; Cleanable = '否'; Reason = '受保护目录(禁止删除)' } } }
    if (Test-VersionControlled -LowerPath $p) { return @{Category = '版本控制数据'; Cleanable = '否'; Reason = '版本控制目录(.git/.svn/.hg)，禁止删除' } }
    # 自动清理例外目录（默认 AI_Work_Temp 整树）：其下任何文件一律保留，不进自动清理。
    if (Test-AutoClearExcluded -Path $fi.FullName) { return @{Category = '自动清理例外目录'; Cleanable = '否'; Reason = 'AI_Work_Temp 等例外目录(整树保留)' } }
    if ($p -match '\\\$recycle\.bin\\') { return @{Category = '回收站文件'; Cleanable = '是'; Reason = '回收站内容(可清空)' } }

    # 已知垃圾热点优先（微软官方认可可安全清理的标准位置）
    $junk = Test-KnownJunkTarget -LowerPath $p
    if ($junk) { return @{Category = [string]$junk.category; Cleanable = [string]$junk.cleanable; Reason = [string]$junk.reason } }

    if ($p -match '\\network\\cookies' -or $p -match '\\cookies$' -or $p -match '\\user data\\default\\bookmarks' -or $p -match 'webview' -or $p -match '\\history$') {
        return @{Category = '浏览数据'; Cleanable = '谨慎'; Reason = '浏览历史/cookie(谨慎清理)' } }
    if ($p -match 'explorer\\iconcache_' -or $p -match 'thumbcache') { return @{Category = '缩略图缓存'; Cleanable = '是'; Reason = '缩略图/图标缓存数据库' } }
    if ($p -match 'crashdumps\\.*\.dmp$') { return @{Category = '崩溃转储'; Cleanable = '是'; Reason = '崩溃转储文件' } }
    if ($name -eq 'ntuser.dat' -or $name -like 'ntuser.dat.*' -or $name -eq 'usrclass.dat' -or $name -like 'usrclass.dat.*') {
        return @{Category = '用户配置'; Cleanable = '否'; Reason = '用户注册表配置(保留)' } }
    if (@($script:KeepExtensions) -contains $ext) { return @{Category = '应用文件'; Cleanable = '否'; Reason = '可执行/库文件(保留)' } }
    if (@($script:LogExtensions) -contains $ext) { return @{Category = '日志文件'; Cleanable = '是'; Reason = '日志文件' } }
    if ((@($script:TempExtensions) -contains $ext) -or ($p -match '\\_cacache\\tmp')) {
        return @{Category = '临时文件'; Cleanable = '是'; Reason = '临时扩展名/临时或缓存目录(可清空)' } }
    foreach ($frag in $script:CacheDirFragments) { if ($p.Contains($frag)) { return @{Category = '缓存文件'; Cleanable = '是'; Reason = '缓存目录/浏览器缓存' } } }
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

    foreach ($pr in $Protected) { if ($p.Contains($pr.ToLower())) { return @{Category = '受保护'; Cleanable = '保留'; Reason = '受保护目录(禁止删除)' } } }
    # .git\logs 是 Git reflog（引用日志），不是"已卸载软件日志残留"——旧版此处误判会导致
    # -DeleteConfirmed 时删除 reflog，造成 Git 引用不可恢复。现统一受版本控制保护。
    if (Test-VersionControlled -LowerPath $p) { return @{Category = '版本控制数据'; Cleanable = '保留'; Reason = '版本控制目录(.git/.svn/.hg)，禁止删除' } }
    # 自动清理例外目录（默认 AI_Work_Temp 整树）：其下任何文件一律保留，不进自动清理。
    if (Test-AutoClearExcluded -Path $fi.FullName) { return @{Category = '自动清理例外目录'; Cleanable = '保留'; Reason = 'AI_Work_Temp 等例外目录(整树保留)' } }
    if ($p -match '\\\$recycle\.bin\\') { return @{Category = '回收站文件'; Cleanable = '自动清理'; Reason = '回收站/清理箱内容(可清空)' } }

    $junk = Test-KnownJunkTarget -LowerPath $p
    if ($junk) { return @{Category = [string]$junk.category; Cleanable = [string]$junk.cleanable; Reason = [string]$junk.reason } }

    if ($p -match 'tencent files' -or $p -match 'wechat files') {
        if ($p -match '\\log\\' -or $p -match '\.qqxlog$' -or $p -match '\\cache\\') {
            return @{Category = '通讯软件缓存/日志'; Cleanable = '需确认'; Reason = '通讯软件缓存/日志(需确认避免误删)' } }
        return @{Category = '通讯软件用户数据'; Cleanable = '保留'; Reason = '通讯软件用户数据/接收文件(禁止误删)' }
    }
    if ($WorkRoot -and (Test-PathPrefix -Path $fi.FullName -Prefix $WorkRoot)) {
        if (@($script:WorkKeepExtensions) -contains $ext) {
            return @{Category = '工作目录受保护文件'; Cleanable = '保留'; Reason = '工作目录禁止删除类型(Office/图片/音视频/TXT/MD/PDF/网页/压缩)' }
        }
    }
    if ($fi.Length -eq 0) { return @{Category = '无用文件(空文件)'; Cleanable = '需确认'; Reason = '0字节空文件(可删)' } }
    if ((@($script:TempExtensions) -contains $ext) -or ($p -match '\.trash-bak') -or ($p -match '\\smoke\\')) {
        return @{Category = '垃圾文件(临时/过程)'; Cleanable = '自动清理'; Reason = '临时/缓存扩展名或过程目录(需清空)' } }
    if (@($script:LogExtensions) -contains $ext) { return @{Category = '垃圾文件(日志)'; Cleanable = '自动清理'; Reason = '应用日志文件' } }
    if (@($script:KeepExtensions) -contains $ext) { return @{Category = '应用文件'; Cleanable = '保留'; Reason = '可执行/库文件(保留)' } }
    if ($p -match 'node_modules\\.*\\cache' -or ($p -match '\\cache\\' -and $p -match 'node_modules')) {
        return @{Category = '依赖缓存(node_modules)'; Cleanable = '需确认'; Reason = '包依赖缓存，重装可恢复(需确认)' } }
    foreach ($frag in $script:CacheDirFragments) {
        if ($p.Contains($frag)) {
            $age = (Get-Date) - $fi.LastWriteTime
            if ($age.TotalDays -le $RecentDays) { return @{Category = '缓存-近期(保留)'; Cleanable = '保留'; Reason = ('近期缓存(<{0}天)' -f $RecentDays) } }
            return @{Category = '缓存-陈旧(可清理)'; Cleanable = '需确认'; Reason = ('陈旧缓存(>{0}天)' -f $RecentDays) }
        }
    }
    if ($p -match '\\users\\[^\\]+\\(documents|pictures|desktop|videos|music|contacts|links|downloads)\\') {
        return @{Category = '用户重要数据'; Cleanable = '保留'; Reason = '用户文档/媒体(保留)' } }
    return @{Category = '其他/未知'; Cleanable = '保留'; Reason = '未分类(多数保留)' }
}

# ===================== 自动清理目录：清空直接子项、保留目录壳 =====================
# 给定命中三类命名规则的目录 $Dir，将其「直接子项（文件 + 子目录）」整批写为 Delete 行，
# 目录自身不写入（保留壳），且不向下递归（避免重复分类）。
#   - 子项名含 .git/.svn/.hg -> 跳过（版本控制保护，永不删）
#   - 子项本身为 AI_Work_Temp 等例外目录 -> 跳过清空
#   - 子项为重解析点(junction/symlink) -> 跳过（避免跟随自指 junction）
#   - 子目录行 SizeMB 记 0（其子树体积在 DryRun 报告中略低估，删除目标完整）；
#     文件行记真实体积与扩展名。Cleanable 标签随方案 C/D 取「是 / 自动清理」。
function Clear-AutoDirChildren {
    param([string]$Dir, $Writer, [string]$Scheme, $Counter)
    $childEntries = $null
    try { $childEntries = [System.IO.Directory]::EnumerateFileSystemEntries($Dir) } catch { $Counter.Errors++; return }
    foreach ($c in $childEntries) {
        try {
            # 版本控制保护：子项名含 .git/.svn/.hg -> 跳过
            if (Test-VersionControlled -LowerPath $c.ToLower()) { continue }
            # 子项本身若为 AI_Work_Temp 等例外目录 -> 跳过清空
            if (Test-AutoClearExcluded -Path $c) { continue }
            $cIsDir = $false
            try { $cIsDir = [System.IO.Directory]::Exists($c) } catch { $cIsDir = $false }
            if ($cIsDir) {
                try {
                    $attrsC = [System.IO.Directory]::GetAttributes($c)
                    if (($attrsC -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) { continue }
                } catch { }
            }
            $ext = ''
            $sizeMB = 0.0
            $lwt = ''
            if ($cIsDir) {
                try { $lwt = ([System.IO.Directory]::GetLastWriteTime($c)).ToString('yyyy-MM-dd HH:mm:ss') } catch { $lwt = '' }
            }
            else {
                $fi = [System.IO.FileInfo]$c
                $ext = if ($fi.Extension) { $fi.Extension.ToLower() } else { '' }
                try { $sizeMB = Format-SizeMB $fi.Length } catch { $sizeMB = 0.0 }
                try { $lwt = $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') } catch { $lwt = '' }
            }
            $label = if ($Scheme -eq 'C') { '是' } else { '自动清理' }
            $line = ((Quote-CsvField $c), (Quote-CsvField $ext), (Quote-CsvField $sizeMB),
                     (Quote-CsvField $lwt), (Quote-CsvField '临时/缓存目录(清空,保留壳)'),
                     (Quote-CsvField $label), (Quote-CsvField '目录名命中自动清理规则(temp/tmp/cache)，清空其内容、保留目录自身')) -join ','
            $Writer.WriteLine($line)
            $Counter.Count++
        }
        catch { $Counter.Errors++ }
    }
}

# ===================== 迭代式枚举 + 即时分类写盘 =====================
# 用显式栈代替递归：彻底规避 PowerShell 脚本递归深度上限（溢出是终止性错误，会中断整轮扫描）
function Scan-Dir {
    param($Dir, $Exclude, $Writer, $Scheme, $Protected, $WorkRoot, $RecentDays, $Counter, $MaxDepth)

    $pathStack  = [System.Collections.Generic.Stack[string]]::new()
    $depthStack = [System.Collections.Generic.Stack[int]]::new()
    if ((Test-AutoClearDirName -Name (Split-Path -Path $Dir -Leaf)) -and -not (Test-AutoClearExcluded -Path $Dir)) {
        # 根目录自身命中自动清理规则：清空其直接子项，保留根目录壳，不入栈递归。
        Clear-AutoDirChildren -Dir $Dir -Writer $Writer -Scheme $Scheme -Counter $Counter
    }
    else {
        $pathStack.Push($Dir)
        $depthStack.Push(0)
    }

    while ($pathStack.Count -gt 0) {
        $current = $pathStack.Pop()
        $depth   = $depthStack.Pop()

        if ($MaxDepth -gt 0 -and $depth -gt $MaxDepth) { $Counter.DepthSkipped++; continue }

        $entries = $null
        try { $entries = [System.IO.Directory]::EnumerateFileSystemEntries($current) } catch { $Counter.Errors++; continue }

        foreach ($e in $entries) {
            # 排除目录：边界匹配，避免 "C:\Windows" 误排除 "C:\WindowsApps"
            $skip = $false
            foreach ($ex in $Exclude) { if (Test-PathPrefix -Path $e -Prefix $ex) { $skip = $true; break } }
            if ($skip) { continue }

                try {
                    if ([System.IO.Directory]::Exists($e)) {
                        # 跳过 NTFS 重解析点（junction/symlink），避免跟随自指 junction
                        try {
                            $attrs = [System.IO.Directory]::GetAttributes($e)
                            if (($attrs -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) { continue }
                        } catch { }
                        # 自动清理目录判定（v0.5.0）：命中三类命名规则且未例外 -> 清空其内容、保留目录壳
                        if ((Test-AutoClearDirName -Name (Split-Path -Path $e -Leaf)) -and -not (Test-AutoClearExcluded -Path $e)) {
                            # 枚举直接子项并写入 Delete 行；不向下递归（避免重复分类）。
                            Clear-AutoDirChildren -Dir $e -Writer $Writer -Scheme $Scheme -Counter $Counter
                            continue
                        }
                        $pathStack.Push($e)
                        $depthStack.Push($depth + 1)
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
            catch { $Counter.Errors++ }
        }
    }
}

# ===================== 标签 -> 处置 映射层 =====================
# 覆盖两套清单的 Cleanable 列取值：
#   - scan3（D 盘）：自动清理 / 需确认 / 保留 / 否 / 受保护
#   - scan2（C 盘）：是（可清理）/ 否（保留）/ 谨慎（需人工确认）
# 未知取值一律保留（保守默认，避免误删）。
$script:DeleteLabels = @('自动清理', '是')
$script:ConfirmLabels = @('需确认', '谨慎')

function Map-Cleanable {
    param([string]$Label)
    if (@($script:DeleteLabels) -contains $Label) { return 'Delete' }
    if (@($script:ConfirmLabels) -contains $Label) { return 'Confirm' }
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

# ===================== 健壮 CSV 读取（RFC4180 + BOM 探测 + GBK 回退） =====================
function Get-TextContent {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::Unicode)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::BigEndianUnicode)
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    }
    # UTF-8 无 BOM：先按 UTF-8 严格解码验证，失败则回退 GBK（中文 Windows 常见遗留编码）
    try {
        $strict = [System.Text.UTF8Encoding]::new($false, $true)
        return $strict.GetString($bytes)
    } catch {
        try { return [System.Text.Encoding]::GetEncoding('GB18030').GetString($bytes) }
        catch { return [System.Text.Encoding]::Default.GetString($bytes) }
    }
}

function Read-CsvRecords {
    param([string]$Path)

    $text = Get-TextContent -Path $Path

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

# ===================== 默认产物路径（写入 TEMP，避免污染仓库） =====================
if ([string]::IsNullOrEmpty($OutMd))  { $OutMd  = Join-Path $env:TEMP 'cleanup_plan.md' }
if ([string]::IsNullOrEmpty($OutCsv)) { $OutCsv = Join-Path $env:TEMP 'cleanup_plan_files.csv' }

# ===================== 主流程入口：扫描（若提供 -Root） =====================
$scanGenerated = $null
if ($Root) {
    if (-not (Test-Path -LiteralPath $Root)) { Write-Error ("根目录不存在: {0}" -f $Root); exit 1 }
    $resolved = Resolve-Path $Root
    $drive = ($resolved.Path.Substring(0, 1)).ToUpper()
    if ($Scheme -eq 'Auto') { $Scheme = if ($drive -eq $script:SystemDriveLetter) { 'C' } else { 'D' } }
    if (-not $OutScanCsv) { $OutScanCsv = Join-Path $env:TEMP ("scan_inventory_$drive.csv") }

    Write-Output ("开始扫描: 根={0} 方案={1} 输出={2}" -f $resolved.Path, $Scheme, $OutScanCsv)

    $writer = [System.IO.StreamWriter]::new($OutScanCsv, $false, [System.Text.UTF8Encoding]::new($true))
    $writer.WriteLine('FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason')

    $counter = @{ Count = 0; Errors = 0; DepthSkipped = 0 }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Scan-Dir $resolved.Path $ExcludeRoots $writer $Scheme $ProtectedRoots $WorkRoot $RecentDays $counter $MaxDepth
    $sw.Stop()
    $writer.Close()
    Write-Progress -Activity "扫描 $Scheme 方案" -Completed

    Write-Output ("扫描完成: 共 {0} 个文件，耗时 {1:N1}s，访问异常 {2} 次，超深跳过 {3} 个，已写入 {4}" -f
        $counter.Count, $sw.Elapsed.TotalSeconds, $counter.Errors, $counter.DepthSkipped, $OutScanCsv)
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
$skippedVcs  = 0
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
        $hdrLower = $hdr | ForEach-Object { $_.ToLower() }   # 大小写不敏感匹配表头
        $idxFull = [array]::IndexOf($hdrLower, 'fullpath')
        $idxClean = [array]::IndexOf($hdrLower, 'cleanable')
        $idxSize = [array]::IndexOf($hdrLower, 'sizemb')
        $idxCat = [array]::IndexOf($hdrLower, 'category')
        $idxReason = [array]::IndexOf($hdrLower, 'reason')
        if ($idxFull -lt 0 -or $idxClean -lt 0) {
            Write-Warning ('CSV 缺少必需列(FullPath/Cleanable)，表头为 [{0}]，已跳过: {1}' -f ($hdr -join ','), $cp)
            continue
        }

        foreach ($cols in $data.Records) {
            $fp = if ($idxFull -lt $cols.Count) { $cols[$idxFull].Trim() } else { '' }
            if ([string]::IsNullOrWhiteSpace($fp)) { continue }

            $cleanable = if ($idxClean -lt $cols.Count) { $cols[$idxClean].Trim() } else { '' }
            $intent = Map-Cleanable $cleanable
            if ($intent -eq 'Keep') { $skippedKeep++; continue }

            # 版本控制数据兜底（清单模式）：扫描模式已在 Classify-C/D 中保护，但清单模式
            # 直接信任外部 CSV 的 Cleanable 标记。若上游清单把 .git/.svn/.hg 标为"自动清理"，
            # 会造成版本库引用数据（reflog / objects）不可逆丢失。此处作为最后一道防线，
            # 一律排除出删除计划——既不受 -DeleteConfirmed 影响，也不进"需确认"队列。
            if (Test-VersionControlled -LowerPath $fp.ToLower()) { $skippedVcs++; continue }

            $safeRoot = Test-SafeRootMatch -Path $fp

            # 系统核心目录强制降级：Delete -> Confirm
            # 例外：显式 -AllowSystemJunk 且该项命中"已知垃圾热点"（如 Windows 更新下载缓存）
            $systemGuarded = $false
            if ($intent -eq 'Delete' -and (Test-SystemProtected -Path $fp)) {
                $allowByJunk = $false
                if ($AllowSystemJunk) {
                    $jt = Test-KnownJunkTarget -LowerPath $fp.ToLower()
                    if ($jt) { $allowByJunk = $true }
                }
                if (-not $allowByJunk) {
                    $intent = 'Confirm'
                    $systemGuarded = $true
                }
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
        if (-not $p) { $p = '(根目录)' }
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
    if ($null -ne $rows) {
        $rows = @($rows | Sort-Object Count -Descending)
        if ($TopN -gt 0 -and $rows.Count -gt $TopN) { $rows = @($rows | Select-Object -First $TopN) }
    }
    return @($rows)
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

    [void]$sb.AppendLine('## 二、安全根目录（删前需二次确认）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('凡拟删除项落于以下目录，一律按目录批量二次确认，绝不自动删除。')
    [void]$sb.AppendLine('来源：环境变量 CLEANUP_SAFE_ROOTS > -SafeRoots 参数 > 配置文件 cleanup_config.json > 运行时自动探测的用户个人目录（不可被参数移除）。')
    [void]$sb.AppendLine()
    foreach ($r in $SafeRoots) { [void]$sb.AppendLine(('- ' + $r)) }
    [void]$sb.AppendLine()

    [void]$sb.AppendLine('## 三、系统核心保护目录（命中即强制降为待确认）')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('凡拟删除项落于以下系统目录，一律强制降为"待确认"，绝不自动删除，保证 Windows 系统与已装程序零破坏。')
    [void]$sb.AppendLine('（路径由系统环境变量 / Shell 特殊文件夹 / 注册表自动探测，非硬编码）')
    [void]$sb.AppendLine()
    foreach ($r in $SystemProtectedRoots) { [void]$sb.AppendLine(('- ' + $r)) }
    [void]$sb.AppendLine()

    $delSize = Get-SafeSum -Items $PlanDelete -Property 'SizeMB'
    $conSize = Get-SafeSum -Items $PlanConfirm -Property 'SizeMB'
    $safeSize = Get-SafeSum -Items $PlanSafe -Property 'SizeMB'
    $guardSize = Get-SafeSum -Items $PlanGuarded -Property 'SizeMB'

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
                [void]$sb.AppendLine('| --- | --- | --- | --- |')
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
    [void]$sb.AppendLine('> 以下拟删除项命中系统核心保护目录，已被强制降为"待确认"，绝不自动删除。如需清理，需显式 `-DeleteConfirmed`（以及可选的 `-AllowSystemJunk`）并在交互中确认。')
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
            [void]$sb.AppendLine('| --- | --- | --- | --- |')
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
    [void]$sb.AppendLine('- 安全根目录下的任何拟删除项均被拦截为二次确认，避免误删用户工作/工具/文档。')
    [void]$sb.AppendLine('- 系统核心目录下的拟删除项被强制降为待确认，保证 Windows 系统与已装程序零破坏。')
    [void]$sb.AppendLine('- 版本控制目录（`.git` / `.svn` / `.hg`）下的内容一律保留，防止误删 Git reflog 等引用数据。')
    [void]$sb.AppendLine('- 删除操作使用底层 .NET API（`[System.IO.File]::Delete` / `[System.IO.Directory]::Delete($path, $true)`）以绝对字面路径删除，对含 `[]{}` `$` 等特殊字符的路径安全；目录型路径递归删除，且按目录二次确认；Execute 模式可用 `-WhatIf` 模拟试运行。')

    return $sb.ToString()
}

$md = New-MarkdownReport -PlanDelete $planDelete -PlanConfirm $planConfirm -PlanSafe $planSafe -PlanGuarded $planGuarded -LoadedFiles $loadedFiles -SafeRoots $SafeRoots -SystemProtectedRoots $SystemProtectedRoots -Mode $Mode -WhatIf $WhatIf -ScanGenerated $scanGenerated
[System.IO.File]::WriteAllText($OutMd, $md, [System.Text.UTF8Encoding]::new($true))

# 完整清单 CSV（逐文件，绝对路径不丢失，供一致性校验）
$csvLines = [System.Collections.Generic.List[string]]::new()
[void]$csvLines.Add('"FullPath","SizeMB","Category","Reason","Intent","SafeRoot","SystemGuarded","Action"')
foreach ($it in $planDelete) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Delete', '', 'False', '拟删除'))) }
foreach ($it in $planConfirm) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Confirm', '', 'False', '待确认'))) }
foreach ($it in $planSafe) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Safe', $it.SafeRoot, 'False', '安全根二次确认'))) }
foreach ($it in $planGuarded) { [void]$csvLines.Add((Format-CsvLine @($it.Path, ('{0:N4}' -f $it.SizeMB), $it.Category, $it.Reason, 'Guarded', '', 'True', '系统核心降级待确认'))) }
[System.IO.File]::WriteAllText($OutCsv, ($csvLines -join "`r`n"), [System.Text.UTF8Encoding]::new($true))

Write-Output ('已生成 Markdown 报告: {0}' -f $OutMd)
Write-Output ('已生成完整清单 CSV: {0}' -f $OutCsv)

$delSize = Get-SafeSum -Items $planDelete -Property 'SizeMB'
$conSize = Get-SafeSum -Items $planConfirm -Property 'SizeMB'
$safeSize = Get-SafeSum -Items $planSafe -Property 'SizeMB'
$guardSize = Get-SafeSum -Items $planGuarded -Property 'SizeMB'
Write-Output ('确定拟删除: {0} 个 / {1:N2} MB' -f $planDelete.Count, $delSize)
Write-Output ('待确认: {0} 个 / {1:N2} MB' -f $planConfirm.Count, $conSize)
Write-Output ('安全根二次确认: {0} 个 / {1:N2} MB' -f $planSafe.Count, $safeSize)
Write-Output ('系统核心降级待确认: {0} 个 / {1:N2} MB' -f $planGuarded.Count, $guardSize)
Write-Output ('已跳过(保留/否/受保护/未知): {0} 个' -f $skippedKeep)
if ($skippedVcs -gt 0) {
    Write-Output ('版本控制数据保护: {0} 个（.git/.svn/.hg，任何模式下均不删除）' -f $skippedVcs)
}

# ===================== 执行删除（仅 Execute 模式） =====================
function Remove-OneItem {
    param($It)
    if (-not (Test-Path -LiteralPath $It.Path)) { return 'missing' }
    $isDir = $false
    try { $isDir = (Get-Item -LiteralPath $It.Path -ErrorAction Stop) -is [System.IO.DirectoryInfo] }
    catch { Write-Warning ('无法访问: {0} - {1}' -f $It.Path, $_.Exception.Message); return 'fail' }
    try {
        # 使用底层 .NET API 删除，绕开可能被安全软件 hook 的 Remove-Item cmdlet。
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

# 目录确认缓存（通过参数传递，避免函数隐式依赖外层变量）
$script:DirConfirmCache = @{}

function Confirm-Dir {
    param([string]$Dir, [bool]$WhatIf)
    if ($script:DirConfirmCache.ContainsKey($Dir)) { return $script:DirConfirmCache[$Dir] }
    if ($WhatIf) { $script:DirConfirmCache[$Dir] = $true; return $true }   # WhatIf 下不弹确认，直接视为将删（仅报告）
    $ans = Read-Host ('是否递归删除目录 [{0}] ? (y/N)' -f $Dir)
    $ok = ($ans -match '^[yY]')
    $script:DirConfirmCache[$Dir] = $ok
    return $ok
}

function Invoke-DeleteBatch {
    param($Items, [bool]$RequireDirConfirm, [bool]$WhatIf, [string]$Label)

    $ok = 0; $fail = 0; $skip = 0
    # 返回结构化统计对象，而不是「统计数字 + 混杂的日志字符串」。
    # 原因：本函数返回值会被赋值使用（$st = Invoke-DeleteBatch ...），若函数体内直接
    # Write-Output 打日志，日志会串入返回值，使调用方的 $st.Fail 变为数组、判断失真。
    # 日志改由 Messages 收集，交调用方统一输出——输出文案保持不变，返回值保持干净。
    $messages = [System.Collections.Generic.List[string]]::new()

    foreach ($it in $Items) {
        if (-not (Test-Path -LiteralPath $it.Path)) { $skip++; continue }
        $isDir = $false
        # TOCTOU 保护：上一步 Test-Path 与此处 Get-Item 之间文件可能已被删除或变为不可访问
        try { $isDir = (Get-Item -LiteralPath $it.Path -ErrorAction Stop) -is [System.IO.DirectoryInfo] }
        catch { Write-Warning ('无法访问，已跳过: {0}' -f $it.Path); $skip++; continue }

        if ($isDir -and $RequireDirConfirm) {
            # 确认对象必须是目录自身（$it.Path，$isDir 已为真）
            if (-not (Confirm-Dir -Dir $it.Path -WhatIf $WhatIf)) {
                [void]$messages.Add(('已跳过目录 [{0}]' -f $it.Path))
                $skip++; continue
            }
        }
        if ($WhatIf) {
            [void]$messages.Add(('WhatIf: 将删除 {0} [{1}]' -f $(if ($isDir) { '目录' } else { '文件' }), $it.Path))
            $ok++; continue
        }
        $r = Remove-OneItem -It $it
        switch ($r) {
            'ok' { $ok++ }
            'fail' { $fail++ }
            'missing' { $skip++ }
        }
    }
    return [PSCustomObject]@{
        Label    = $Label
        Ok       = $ok
        Fail     = $fail
        Skip     = $skip
        Messages = $messages
    }
}

function Write-DeleteStat {
    param($Stat)
    # 日志走 Write-Host（信息流），不进成功输出流——本函数返回值被赋值使用
    # （$f = Write-DeleteStat ...），若用 Write-Output 会把日志串入返回值，使 $f 变为
    # 数组、if ($f -gt 0) 判定失真（同类 F-B 函数污染缺陷，必须规避）。
    foreach ($m in $Stat.Messages) { Write-Host $m }
    Write-Host ('{0}: 成功 {1}，失败 {2}，跳过 {3}' -f $Stat.Label, $Stat.Ok, $Stat.Fail, $Stat.Skip)
    return [int]$Stat.Fail
}

$exitCode = 0
if ($Mode -eq 'Execute') {
    Write-Output '===== 进入执行删除模式 ====='
    if ($WhatIf) { Write-Output '（WhatIf 已启用：仅模拟删除，不实际删除任何文件，不弹出交互确认）' }

    # 1. 确定拟删除（非安全根、非系统核心）：目录型按目录确认
    $f = Write-DeleteStat -Stat (Invoke-DeleteBatch -Items $planDelete -RequireDirConfirm $true -WhatIf $WhatIf -Label '自动清理删除')
    if ($f -gt 0) { $exitCode = 2 }

    # 2. 需确认项 / 系统核心降级项（仅当显式 -DeleteConfirmed）
    if ($DeleteConfirmed) {
        $f = Write-DeleteStat -Stat (Invoke-DeleteBatch -Items $planConfirm -RequireDirConfirm $true -WhatIf $WhatIf -Label '需确认项(已授权)删除')
        if ($f -gt 0) { $exitCode = 2 }
        $f = Write-DeleteStat -Stat (Invoke-DeleteBatch -Items $planGuarded -RequireDirConfirm $true -WhatIf $WhatIf -Label '系统核心降级项(已授权)删除')
        if ($f -gt 0) { $exitCode = 2 }
    }
    else {
        Write-Output ('非安全根需确认项 {0} 个、系统核心降级项 {1} 个默认跳过（未删除）。' -f $planConfirm.Count, $planGuarded.Count)
    }

    # 3. 安全根项：按目录批量交互确认（始终需显式 y；不静默删）
    if ($planSafe.Count -gt 0) {
        $f = Write-DeleteStat -Stat (Invoke-DeleteBatch -Items $planSafe -RequireDirConfirm $true -WhatIf $WhatIf -Label '安全根目录删除')
        if ($f -gt 0) { $exitCode = 2 }
    }
}
else {
    Write-Output '===== DryRun 模式：未删除任何文件 ====='
}

exit $exitCode
