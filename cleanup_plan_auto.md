# 磁盘垃圾文件扫描 + 清理规划报告

> 生成时间: 2026-08-01 11:25:50
> 运行模式: **DryRun**（仅输出，未删除任何文件）

## 一、数据来源
- D:\System\UserTemp\winapp2_sample_expanded_auto.csv

## 二、安全根目录（删前需二次确认，硬编码兜底）

凡拟删除项落于以下目录，一律按目录批量二次确认，绝不自动删除（含硬编码兜底根，不可被参数移除）：

- D:\Documents
- D:\Tools
- D:\ZW工作

## 三、系统核心保护目录（命中即强制降为待确认）

凡拟删除项落于以下系统目录，一律强制降为"待确认"，绝不自动删除，保证 Win11 系统与已装程序零破坏：

- C:\Windows
- C:\Program Files
- C:\Program Files (x86)
- C:\ProgramData

## 四、处置统计

| 处置类别 | 文件数 | 总体积(MB) | 说明 |
| --- | --- | --- | --- |
| 确定拟删除（自动清理，非安全根、非系统核心） | 4 | 0.00 | 默认删除（DryRun 仅列出） |
| 待确认（需确认，非安全根） | 0 |  | 默认不删，需用户决定 |
| 安全根二次确认 | 1 | 0.00 | 按目录批量确认后删除 |
| 系统核心降级待确认 | 1 | 0.00 | 命中系统核心目录，强制待确认，不自动删 |

## 五、确定拟删除清单（自动清理，非安全根、非系统核心）

> 以下文件经标签映射为"自动清理"，且不在任一安全根、也不在系统核心目录下，默认删除。

| 绝对路径 | 体积(MB) | 分类 | 说明(Reason) |
| --- | --- | --- | --- |
| D:\System\UserTemp\zw_demo_app\a.tmp | 0.0000 | Applications | Winapp2规则: ZW Demo App Cache |
| D:\System\UserTemp\zw_demo_app\b.tmp | 0.0000 | Applications | Winapp2规则: ZW Demo App Cache |
| D:\System\UserTemp\zw_exclude_app\drop.tmp | 0.0000 | Applications | Winapp2规则: ZW Demo ExcludeKey |
| C:\Users\Administrator\AppData\Local\Microsoft\Edge\User Data\TestProfile\Cache | 0.0000 | Google Chrome | Winapp2规则: ZW Demo Installed Edge |

## 六、待确认清单（需确认，非安全根）

> 共 0 个文件 /  MB，默认不删除。
> 以下按所在目录聚合展示；如需逐文件绝对路径，请运行脚本时加 `-FullList`，或查阅同目录完整清单 CSV。

_无_

## 七、安全根目录待二次确认清单

> 以下拟删除项落在安全根目录下，执行删除前将按目录批量请求确认。DryRun 模式下仅列出。

### 安全根：D:\ZW工作

| 所在子目录 | 文件数 | 总体积(MB) |
| --- | --- | --- |
| D:\ZW工作 | 1 | 0.00 |

## 八、系统核心目录强制待确认清单

> 以下拟删除项命中系统核心保护目录（C:\Windows / Program Files / ProgramData 等），已被强制降为"待确认"，绝不自动删除。如需清理，需显式 `-DeleteConfirmed` 并在交互中确认。

| 所在目录 | 文件数 | 总体积(MB) |
| --- | --- | --- | ---
| C:\Windows\Temp | 1 | 0.00 |

## 九、安全声明

- 本脚本 DryRun 模式**不删除任何文件**，仅生成规划报告。
- 所有删除决策来源于清单（现场扫描或既有 CSV）的 `Cleanable` 字段，经"标签→处置映射层"统一处理（兼容 scan2 描述性标签与 scan3 三值标签），未硬编码任何具体文件。
- 安全根目录（D:\ZW工作、D:\Tools、D:\Documents 等，含硬编码兜底）下的任何拟删除项均被拦截为二次确认，避免误删用户工作/工具/文档。
- 系统核心目录（C:\Windows、C:\Program Files、C:\ProgramData 等）下的拟删除项被强制降为待确认，保证 Win11 系统与已装程序零破坏。
- 删除操作使用底层 .NET API（`[System.IO.File]::Delete` / `[System.IO.Directory]::Delete($path, $true)`）以绝对字面路径删除，对含 `[]{}` `$` 等特殊字符的路径安全；目录型路径递归删除，且按目录二次确认；Execute 模式可用 `-WhatIf` 模拟试运行。
