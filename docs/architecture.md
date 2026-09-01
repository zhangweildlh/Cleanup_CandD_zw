---
title: 架构总览
description: cleanup_cd 与 winapp2_expand 的双脚本工作流、双层硬保护、标签→处置映射、关键参数与编码健壮性。
related:
  - configuration.md
  - winapp2-integration.md
  - upstream-tracking.md
  - testing.md
  - ../README.md
updated: 2026-09-01
---

# 架构总览

本仓库是一个**本地 C/D 盘垃圾安全清理工具**，核心原则是「宁可少删、不可误删」：
**默认 DryRun（只预览不删除）**、**双层硬保护**、**配置外置、无本机硬编码**。

涉及两个脚本，彼此零耦合（扩展器只产出 CSV，`cleanup_cd` 只消费 CSV）：

| 脚本 | 角色 | 关键约束 |
|------|------|----------|
| `cleanup_cd.ps1` | 扫描 + 标签映射 + 规划 + 执行（删除） | DryRun 默认；删除走底层 .NET API（按字面路径，绕开 `Remove-Item` 的 safe-delete hook） |
| `winapp2_expand.ps1` | Winapp2 规则库「展开器」（方案甲伴生器） | 只展开/列出，绝不删除；产物 CSV 直接喂给 `cleanup_cd` |

## 一、工作流

```
[可选] -Root <目录> ──现场递归扫描──► 即时分类 ──┐
                                                  ├─► 合并 ─► 加载清单 ─► 标签→处置映射 ─► 规划
[可选] -CsvPaths <清单.csv> ──────────────────────┘        (FullPath,Cleanable,…)        │
                                                                                          ├─► DryRun：仅输出 Markdown + 完整 CSV（零删除）
                                                                                          └─► Execute：按二次确认删（可 -WhatIf 模拟）
```

- `-Root` 与 `-CsvPaths` 可同时提供（先扫描、再叠加既有清单）；二者皆无则 `exit 1`。
- 两类清单字段同构：`FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason`。

## 二、两套标签体系与「标签→处置映射层」

清单的 `Cleanable` 列取值来自两种分类口径，映射层统一归一为三类处置（未知取值一律 Keep，保守默认）：

| 来源口径 | 取值 | 映射为处置 |
|----------|------|-----------|
| 方案 C（默认用于系统盘） | `是` / `否` / `谨慎` | Delete / Keep / Confirm |
| 方案 D（默认用于其它盘） | `自动清理` / `需确认` / `保留` | Delete / Confirm / Keep |

- Delete 标签：`自动清理`、`是`
- Confirm 标签：`需确认`、`谨慎`
- 其余（`保留` / `否` / `受保护` / 未知）→ **Keep（永不删除）**

## 三、双层硬保护（保证系统 / 已装程序 / 工作目录 / 个人文档零破坏）

1. **安全根拦截**：拟删除项落在任一安全根目录下，一律提升为「按目录二次确认（Safe）」，即便原本是自动清理。
   来源优先级（全部可配置、无硬编码）：环境变量 `CLEANUP_SAFE_ROOTS` > `-SafeRoots` 参数 > 配置文件 `safeRoots` > **运行时自动探测的用户个人目录（桌面/文档/下载/图片/视频/音乐，经注册表 Known Folder 解析，不可被参数移除）**。
2. **系统核心降级**：拟删除项落在系统核心目录（自动探测的 `Windows` / `Program Files` / `Program Files (x86)` / `ProgramData`）下，强制降为「待确认（Guarded）」，绝不自动删除。
   例外：显式 `-AllowSystemJunk` 且该项命中「已知垃圾热点」（见 [configuration.md](./configuration.md) 的 `knownJunkTargets`）时才恢复 Delete。
3. **版本控制保护**：`.git` / `.svn` / `.hg` 目录下内容一律 Keep。
   **清单模式（决策点兜底，F-C 修复）**：扫描模式在 `Classify-C/D` 已保护；但清单模式直接信任外部 CSV 的 `Cleanable`，故在「决策点」再次兜底——命中即 `continue`，不进任何 plan 队列，连 `-DeleteConfirmed` 也无法解除；由 `$skippedVcs` 统计。

> 设计铁律：凡属「不可删」语义的保护，**必须在决策点（而非仅分类点）再落一道兜底**，否则在清单模式下会被外部 CSV 标记绕过。

## 四、关键参数

| 参数 | 作用 |
|------|------|
| `-Root` | 现场递归扫描根目录（可同时配合 `-Scheme C/D/Auto`） |
| `-CsvPaths` | 一个或多个既有处置清单 CSV |
| `-Scheme` | `C`/`D`/`Auto`（默认 Auto：系统盘用 C、其余用 D；仅对 `-Root` 生效） |
| `-Mode` | `DryRun`（默认，零副作用）/`Execute`（执行删除） |
| `-ConfigPath` / `-Config` | 外置配置 JSON 路径（默认脚本同目录 `cleanup_config.json`） |
| `-SafeRoots` | 追加安全根（无法移除配置与自动探测所定安全根） |
| `-ProtectedRoots` | 追加受保护片段（子串匹配） |
| `-DeleteConfirmed` | 仅 Execute：同时删除非安全根的「需确认」与「系统核心降级」项（默认关） |
| `-AllowSystemJunk` | 仅 Execute：命中已知垃圾热点时，系统核心项不降级 |
| `-WhatIf` | 仅 Execute：模拟删除，不实际删、不弹确认 |
| `-FullList` | Markdown 逐文件列出（默认按目录聚合 + 样本，防 MD 过大） |
| `-MaxDepth` | 扫描最大递归深度（0=不限；文件系统本身受 MAX_PATH 约束） |

## 五、编码健壮性

- **CSV 读取**：自研 `StreamReader` + BOM 探测 + RFC4180 引号解析，兼容 UTF-8（有/无 BOM）、UTF-16 LE/BE、GBK（无 BOM 时按字节特征回退）。
- **CSV 写出**：UTF-8 带 BOM 的 `StreamWriter`；表头大小写不敏感匹配，缺 `FullPath`/`Cleanable` 必需列的行被跳过并报警告。
- **扫描递归**：用显式栈代替递归，规避 PowerShell 脚本递归深度上限；跳过 NTFS 重解析点（junction/symlink），避免自指 junction 无限递归。
- **删除**：一律 `-LiteralPath` + 底层 .NET API（`[System.IO.File]::Delete` / `[System.IO.Directory]::Delete($path,$true)`），对含 `[]{}` `$` 等特殊字符的路径安全。

## 六、已知边界

- `cleanup_cd` 不删注册表；`winapp2_expand` 的 RegKey 默认忽略，开 `-IncludeReg` 仅作备注。
- 受保护片段（如 `.workbuddy`）**仅在 `-Root` 扫描的分类阶段生效**；纯清单模式依赖外部 CSV 标记，不在决策点二次校验（这是有意为之：清单模式信任上游分类）。
- 系统核心目录的误删防护始终生效；`-AllowSystemJunk` 仅放开「已知垃圾热点」这一类。
