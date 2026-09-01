---
title: 配置说明
description: cleanup_config.json 的全部字段语义、安全根/受保护片段/已知垃圾热点的取值，以及 CLEANUP_SAFE_ROOTS 环境变量。
related:
  - architecture.md
  - winapp2-integration.md
  - upstream-tracking.md
  - testing.md
  - ../README.md
updated: 2026-09-01
---

# 配置说明

所有环境特定目录与规则**都外置在 `cleanup_config.json`**，脚本本身不含任何本机专属硬编码。
配置文件缺失时回退内置默认规则（安全根仅由自动探测与 `-SafeRoots` 决定）。

## 一、顶层字段

| 字段 | 含义 | 本仓库当前值 |
|------|------|--------------|
| `safeRoots` | 安全根目录：其下任何拟删除项一律提升为「按目录二次确认」，永不自动删除 | `D:\ZW工作` / `D:\Tools` / `D:\codebase-memory-mcp` / `D:\Backup` / `D:\Documents` |
| `workRoots` | 工作区根：命中受保护扩展名的文件强制保留 | `D:\ZW工作` |
| `protectedRoots` | 受保护片段（子串匹配，大小写不敏感）：命中即 Keep | `.workbuddy` / `.mimocode` / `$Recycle.Bin.Safe` |
| `extraExcludeRoots` | 扫描时额外跳过的目录（叠加在系统核心目录之上） | `[]` |
| `recentDays` | 近期缓存阈值（天）：超过则不再以「近期缓存」为由保留 | `180` |
| `classification` | 分类规则（扩展名 / 目录片段） | 见下 |
| `knownJunkTargets` | 已知垃圾热点（微软/业界公认可安全清理的位置） | 14 条，见下 |

> 环境变量 `CLEANUP_SAFE_ROOTS`（分号分隔）优先级**最高**，可临时覆写安全根集合，便于 CI / 一次性场景。

## 二、classification 子项

| 子项 | 作用 | 当前取值要点 |
|------|------|--------------|
| `tempExtensions` | 临时扩展名 → 自动清理 | `.tmp .temp .bak .old .dmp .etl .chk .gid .fts .nch` |
| `logExtensions` | 日志扩展名 → 自动清理 | `.log .log1 .log2 .log.bak` |
| `cacheDirFragments` | 缓存目录片段（子串）→ 自动清理 | `\cache\ \caches\ \temp\ \tmp\ \logs\ \log\ \crashdumps\ \dumps\` |
| `keepExtensions` | 可执行/库扩展名 → 保留 | `.exe .dll .sys .msi .ocx .drv .efi` |
| `workKeepExtensions` | 工作目录受保护类型 → 保留 | Office / 图片 / 音视频 / TXT / MD / PDF / 网页 / 压缩 |
| `versionControlDirs` | 版本控制目录 → 保留（禁止删除） | `\.git\ \.svn\ \.hg\` |

## 三、knownJunkTargets（已知垃圾热点，14 条）

每条含 `name` / `fragment`（路径子串，用于判定命中）/ `category` / `cleanable` / `reason` / `source`（权威来源）/ `serviceStop`（删除前需停的服务/进程，空表示无需）。

要点（按 `cleanable` 区分处置）：

- **自动清理**（命中即 Delete，仍过系统核心降级/安全根）：
  `Windows 更新下载缓存`(`\softwaredistribution\download\`)、`传递优化缓存`(`\deliveryoptimization\cache\`)、`Windows 缩略图缓存`(`\explorer\thumbcache_`)、`Windows 图标缓存`(`\explorer\iconcache_`)、`CBS 组件日志`(`\logs\cbs\`)、`Windows 错误报告队列`(`\microsoft\windows\wer\`)、`Windows 错误报告临时`(`\windows\wer\`)、`字体缓存`(`\local\fontcache\`)、`崩溃转储`(`\crashdumps\`)、`预读取缓存`(`\prefetch\`)、`Windows 诊断 ETL 日志`(`\etllogs\`)、`Windows Update 日志`(`\logs\windowsupdate\`)。
- **需确认**（命中但保守，需用户决定）：`系统全量崩溃转储`(`\memory.dmp`)、`系统小转储目录`(`\minidump\`)。

> 这些 `fragment` 同时是 `cleanup_cd` 的 `-AllowSystemJunk` 放行依据：当系统核心目录下的 Delete 项命中上述片段时，才允许恢复为自动删除。

## 四、修改配置的安全约束

- 改 `safeRoots` / `protectedRoots` 前先评估误删风险；任何放宽保护的改动都必须在项目记忆（`.workbuddy/memory/MEMORY.md`）显式记录裁决理由。
- 配置对象经 `Import-CleanupConfig` 加载后赋值给 `$script:Config`；因 PS 5.1 同作用域类型约束陷阱，参数名须用 `$ConfigPath`（保留 `-Config` 别名），**不可**命名为 `[string]$Config`，否则配置被静默字符串化导致安全根/阈值全部失效。
