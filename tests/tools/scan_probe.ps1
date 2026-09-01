#Requires -Version 5.1
<#
.SYNOPSIS
   全盘目录级复扫描探针（只读，零删除）。
.DESCRIPTION
   目的：验证 cleanup_cd.ps1 的分类规则是否存在「遗漏的垃圾」。

   与 v1 相比的关键改进（v1 在 C:\ 全盘规模下崩溃）：
     1) 用 DirectoryInfo.EnumerateFileSystemInfos() 一次性拿到目录下的全部条目
        （含 Length / LastWriteTime），避免对每个文件单独 new FileInfo 造成的
        重复系统调用——这是 v1 慢到崩溃的主因。
     2) 垃圾判定用字符串 IndexOf / 相等比较代替正则，逐文件开销从 11 次正则
        降到常数次字符串比较。
     3) 样本全局限额（每模式最多 SamplePerPattern 条），杜绝内存无限增长。
     4) 迭代式遍历（显式栈），彻底规避 PS 脚本递归深度上限。
     5) 分盘输出，单盘失败不影响另一盘。

   只读保证：全脚本不出现任何删除调用（Remove-Item / ::Delete）。
   编码：本文件必须以 UTF-8 BOM 保存（PS 5.1 按 GBK 读取无 BOM 脚本会中文乱码）。

.PARAMETER Roots
   扫描根，默认 C:\ 与 D:\。
.PARAMETER Out
   输出前缀，默认 $env:TEMP\scan_probe。产物为 <Out>_<盘符>_dirs.csv / _hits.csv / _junk.csv。
.PARAMETER SamplePerPattern
   每个标签全局最多记录的样本条数，默认 300。
.PARAMETER TopDirs
   目录统计保留的 Top N（按总大小降序），默认 3000。
#>
[CmdletBinding()]
param(
    [string[]]$Roots = @('C:\', 'D:\'),
    [string]$Out = '',
    [int]$SamplePerPattern = 300,
    [int]$TopDirs = 3000
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

if (-not $Out) { $Out = Join-Path $env:TEMP 'scan_probe' }

# ---------------- 垃圾模式定义（目录片段 / 扩展名 / 文件名前缀）----------------
$JunkDirs = @('\temp\', '\tmp\', '\cache\', '\caches\', '\logs\', '\log\',
              '\crashdumps\', '\dumps\', '\softwaredistribution\download\',
              '\node_modules\', '\.git\', '\wer\')
$JunkExts = @('.tmp', '.temp', '.bak', '.old', '.dmp', '.etl', '.log', '.chk', '.gid', '.fts', '.nch')
$JunkNames = @('thumbs.db', 'ehthumbs.db', 'desktop.ini', '.ds_store', 'iconcache_', 'thumbcache_')

function Get-JunkTag {
    param([string]$lp, [string]$ln, [string]$lx)
    foreach ($d in $JunkDirs) {
        if ($lp.IndexOf($d, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return 'Dir:' + $d.Trim('\') }
    }
    if ($lx) { foreach ($x in $JunkExts) { if ($lx -eq $x) { return 'Ext:' + $x } } }
    foreach ($n in $JunkNames) {
        if ($ln.StartsWith($n, [System.StringComparison]::OrdinalIgnoreCase)) { return 'Name:' + $n }
    }
    return ''
}

function Invoke-DriveScan {
    param([string]$Root, [string]$Prefix)

    $size    = [System.Collections.Generic.Dictionary[string, long]]::new()
    $count   = [System.Collections.Generic.Dictionary[string, int]]::new()
    $maxSize = [System.Collections.Generic.Dictionary[string, long]]::new()
    $hits    = [System.Collections.Generic.Dictionary[string, int]]::new()
    $samples = [System.Collections.Generic.List[string]]::new()
    $sampleUsed = [System.Collections.Generic.Dictionary[string, int]]::new()

    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    $files = [long]0; $dirs = [long]0; $errs = [long]0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $dirs++
        try {
            $di = [System.IO.DirectoryInfo]::new($dir)
            $infos = @($di.EnumerateFileSystemInfos())
        } catch { $errs++; continue }

        foreach ($info in $infos) {
            try {
                if ($info -is [System.IO.DirectoryInfo]) {
                    if (($info.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) { continue }
                    $stack.Push($info.FullName)
                    continue
                }
                $files++
                $len = $info.Length

                if (-not $count.ContainsKey($dir)) { $count[$dir] = 0; $size[$dir] = [long]0; $maxSize[$dir] = [long]0 }
                $count[$dir]++
                $size[$dir] += $len
                if ($len -gt $maxSize[$dir]) { $maxSize[$dir] = $len }

                $lp = $info.FullName.ToLowerInvariant()
                $ln = $info.Name.ToLowerInvariant()
                $lx = if ($info.Extension) { $info.Extension.ToLowerInvariant() } else { '' }
                $tag = Get-JunkTag -lp $lp -ln $ln -lx $lx
                if ($tag) {
                    $key = $dir + '|' + $tag
                    if (-not $hits.ContainsKey($key)) { $hits[$key] = 0 }
                    $hits[$key]++
                    if (-not $sampleUsed.ContainsKey($tag)) { $sampleUsed[$tag] = 0 }
                    if ($sampleUsed[$tag] -lt $SamplePerPattern) {
                        $sampleUsed[$tag]++
                        $samples.Add(('"{0}","{1}","{2}","{3}"' -f
                            ($info.FullName -replace '"', '""'),
                            [math]::Round($len / 1MB, 4),
                            $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'),
                            $tag))
                    }
                }
            } catch { $errs++ }
        }

        if (($dirs % 2000) -eq 0) {
            Write-Progress -Activity ('复扫描 ' + $Root) -Status ("目录 {0} / 文件 {1} / 异常 {2}" -f $dirs, $files, $errs) -CurrentOperation $dir
        }
    }
    $sw.Stop()
    Write-Progress -Activity ('复扫描 ' + $Root) -Completed

    # 目录级统计：按总大小降序，只保留 Top N
    $ordered = foreach ($k in $size.Keys) {
        [PSCustomObject]@{
            Path = $k; Files = $count[$k]
            SizeMB = [math]::Round($size[$k] / 1MB, 4)
            MaxFileMB = [math]::Round($maxSize[$k] / 1MB, 4)
        }
    }
    $top = @($ordered | Sort-Object SizeMB -Descending | Select-Object -First $TopDirs)

    $dirLines = [System.Collections.Generic.List[string]]::new()
    $dirLines.Add('"Path","Files","SizeMB","MaxFileMB"')
    foreach ($t in $top) {
        $dirLines.Add(('"{0}","{1}","{2}","{3}"' -f ($t.Path -replace '"', '""'), $t.Files, $t.SizeMB, $t.MaxFileMB))
    }
    [System.IO.File]::WriteAllLines(($Prefix + '_dirs.csv'), $dirLines, [System.Text.UTF8Encoding]::new($true))

    # 垃圾命中聚合（目录|标签 -> 计数），按计数降序
    $hitObjs = foreach ($k in $hits.Keys) {
        $p = $k.Split('|')
        [PSCustomObject]@{ Dir = $p[0]; Tag = $p[1]; Count = $hits[$k] }
    }
    $hitLines = [System.Collections.Generic.List[string]]::new()
    $hitLines.Add('"Dir","Tag","Count"')
    foreach ($h in @($hitObjs | Sort-Object Count -Descending | Select-Object -First 5000)) {
        $hitLines.Add(('"{0}","{1}","{2}"' -f ($h.Dir -replace '"', '""'), $h.Tag, $h.Count))
    }
    [System.IO.File]::WriteAllLines(($Prefix + '_hits.csv'), $hitLines, [System.Text.UTF8Encoding]::new($true))

    $junkLines = [System.Collections.Generic.List[string]]::new()
    $junkLines.Add('"Path","SizeMB","LastWriteTime","Tag"')
    foreach ($s in $samples) { $junkLines.Add($s) }
    [System.IO.File]::WriteAllLines(($Prefix + '_junk.csv'), $junkLines, [System.Text.UTF8Encoding]::new($true))

    Write-Output ("[{0}] 目录 {1} / 文件 {2} / 访问异常 {3} / 耗时 {4:N1}s" -f $Root, $dirs, $files, $errs, $sw.Elapsed.TotalSeconds)
    Write-Output ("[{0}] 产物: {1}_dirs.csv, {1}_hits.csv, {1}_junk.csv" -f $Root, $Prefix)
}

foreach ($r in $Roots) {
    if (-not (Test-Path -LiteralPath $r)) { Write-Warning ('根不存在，跳过: ' + $r); continue }
    $resolved = (Resolve-Path -LiteralPath $r).Path
    $drive = $resolved.Substring(0, 1).ToUpper()
    Invoke-DriveScan -Root $resolved -Prefix ($Out + '_' + $drive)
}
