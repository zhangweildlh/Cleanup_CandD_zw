---
title: Cleanup_CandD_zw
description: 本地 C/D 盘垃圾安全清理工具（默认 DryRun、双层硬保护、配置外置）。面向人类用户与未知 Agent 的入口文档，含功能/用法与文档地图、上游追踪自主闭环指引。
related:
  - docs/architecture.md
  - docs/configuration.md
  - docs/winapp2-integration.md
  - docs/upstream-tracking.md
  - docs/testing.md
updated: 2026-09-01
---

# Cleanup_CandD_zw

本地 C 盘 / D 盘**垃圾安全清理**工具。核心原则：**默认 DryRun（只预览不删除）、双层硬保护、配置外置无硬编码、宁可少删不可误删**。

由两个零耦合脚本组成：

- `cleanup_cd.ps1`：扫描 + 标签映射 + 规划 + 执行（删除）。默认 DryRun，删除走底层 .NET API。
- `winapp2_expand.ps1`：把 Winapp2 规则库展开为本机可直接消费的清理候选清单（只列出、不删除），产物 CSV 直接喂给 `cleanup_cd`。

---

## 一、文档地图（沿此找到全部技术文档）

> 任一用户或 Agent 阅读本文件后，应按下表定位技术文档；文档间用相对路径互链，可逐级深入。

| 文档 | 路径 | 用途 |
|------|------|------|
| 架构总览 | [docs/architecture.md](docs/architecture.md) | 双脚本工作流、双层硬保护、标签→处置映射、关键参数、编码健壮性 |
| 配置说明 | [docs/configuration.md](docs/configuration.md) | `cleanup_config.json` 全部字段、安全根/受保护片段/已知垃圾热点、环境变量 |
| Winapp2 集成 | [docs/winapp2-integration.md](docs/winapp2-integration.md) | 变体裁决、F-2/F-3 语义、扩展器用法、已借鉴的 5 条 BleachBit 条目 |
| 上游追踪 | [docs/upstream-tracking.md](docs/upstream-tracking.md) | 三个上游仓库地址、检查命令、借鉴筛选原则、**Agent 自主闭环 SOP** |
| 测试套件 | [docs/testing.md](docs/testing.md) | Pester 运行方式、45 用例覆盖矩阵、PS 5.1 陷阱 |

---

## 二、功能与用途

- **安全扫描**：`-Root` 现场递归扫描并即时分类；或 `-CsvPaths` 读取既有同构清单 CSV（兼容任意来源）。
- **保守规划**：经「标签→处置映射层」归一为三类处置——`Delete`（自动清理）/ `Confirm`（需确认）/ `Keep`（保留）；未知标签一律保留。
- **双层硬保护**：安全根二次确认、系统核心目录强制降级、版本控制目录（`.git`/`.svn`/`.hg`）永不删。
- **临时/缓存目录自动清理（目录级，清空内容保留壳）**：扫描枚举阶段，目录名**恰好等于** `temp`/`tmp`/`cache`/`.temp`/`.tmp`/`.cache`、**包含** `temp`/`tmp`/`cache`、或**以** `.temp`/`.tmp`/`.cache` **开头**的目录，其下「所有子目录与文件」整批判为自动清理（目录自身保留、不删除、不递归）；删除阶段子目录整棵移除。实际删除仍受安全根/系统核心/版本控制三层硬保护兜底，且默认 DryRun + 交互确认。`AI_Work_Temp` 及其整棵子树默认例外（详见 CHANGELOG v0.5.0 的安全提示）。
- **先审后删**：默认 DryRun 只生成 Markdown 报告 + 完整 CSV；显式 `-Mode Execute` 才删，可用 `-WhatIf` 模拟。

---

## 三、快速使用

```powershell
# 1) 现场扫描 D 盘并产出规划报告（仅列出，不删）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode DryRun

# 2) 读取 Winapp2 全量候选清单做清理规划（DryRun）
.\winapp2_expand.ps1 -Winapp2Path .\winapp2_full.ini -OutCsv .\winapp2_full_expanded.csv
.\cleanup_cd.ps1 -CsvPaths .\winapp2_full_expanded.csv -Mode DryRun

# 3) 真正删除"自动清理类"垃圾（需确认类默认保留，仍要二次确认）
.\cleanup_cd.ps1 -CsvPaths .\winapp2_full_expanded.csv -Mode Execute

# 4) 模拟删除（WhatIf，不实际删、不弹确认）
.\cleanup_cd.ps1 -CsvPaths .\winapp2_full_expanded.csv -Mode Execute -WhatIf

# 运行测试（PowerShell 5.1 下）
.\tests\run_pester.ps1 .\tests\cleanup_candd.tests.ps1
```

> 完整参数表见 [docs/architecture.md](docs/architecture.md) §四；配置字段见 [docs/configuration.md](docs/configuration.md)。

---

## 四、上游追踪与「自主闭环」指引

本工具的 Winapp2 规则库来自三个上游仓库（地址与核实日期见 [docs/upstream-tracking.md](docs/upstream-tracking.md) §一）：

- `MoscaDotTo/Winapp2`（我们用其 **non-CCleaner** flavor，对应本地 `winapp2_full.ini`）
- `bleachbit/winapp2.ini`（借鉴来源，已纳入 5 条）
- `bleachbit/cleanerml`（仅作格式参考）

**对人类维护者**：何时该跟进、如何安全借鉴，见 [docs/upstream-tracking.md](docs/upstream-tracking.md) §二–§三。

**对「一无所知的 Agent」**：照 [docs/upstream-tracking.md](docs/upstream-tracking.md) §四 的「自主闭环 SOP」逐步执行，即可独立完成
「检查上游 → 评估 → 借鉴 → 再生候选清单 → 跑测试回归 → 提交」全链路，无需额外上下文。SOP 含：

1. 环境核验（`gh auth status` + 测试基线须全绿）；
2. 取上游最近修改日期（`gh api .../commits`）并与本地比对；
3. 拉取全文 diff，按 6 条筛选原则只借安全候选；
4. 补入本地库 → 再生 CSV → 跑 Pester 必须 45/45 全绿（硬门槛）；
5. 仅推自有 fork（`origin`），禁强推/删 `main`，提交消息注明上游 sha/日期。

> 决策铁律：保持 Non-CCleaner 变体，不升级完整版；任何需放宽双层硬保护才能并入的改动一律拒绝。

---

## 五、仓库状态与基本操作

- 远端：`zhangweildlh/Cleanup_CandD_zw`（public）；默认分支：`main`；最新标签：`v0.5.0`。
- 派生产物 `winapp2_full_expanded.csv` 已被 `.gitignore` 忽略（可由 ini 一键再生）。

```bash
git pull origin main      # 拉取最新
git add <文件>            # 暂存
git commit -m "描述"       # 提交
git push -u origin main   # 推送（仅自有 fork）
```
