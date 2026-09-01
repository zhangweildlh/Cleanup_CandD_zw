---
title: 上游追踪与规则演进跟进
description: 三个上游仓库的准确地址、检查命令（gh）、借鉴筛选原则，以及供「一无所知 Agent」自主闭环跟进上游演进的标准作业流程（SOP）与决策标准。
related:
  - architecture.md
  - configuration.md
  - winapp2-integration.md
  - testing.md
  - ../README.md
updated: 2026-09-01
---

# 上游追踪与规则演进跟进

本文档服务于两类读者：
1. **人类维护者**：了解上游在哪、何时该跟进、如何安全借鉴。
2. **一无所知的 Agent**：照「§四 自主闭环 SOP」逐步执行，即可独立完成「检查上游 → 评估 → 借鉴 → 再生 → 验证 → 提交」全链路，无需额外上下文。

## 一、上游仓库（已核实，2026-09-01）

| 仓库 | 地址 | 我们用到什么 | 备注 |
|------|------|--------------|------|
| `MoscaDotTo/Winapp2` | https://github.com/MoscaDotTo/Winapp2 | `non-CCleaner Winapp2.ini`（本地 `winapp2_full.ini` 即此 flavor） | 默认分支 `master`；库含 `Winapp2.ini`（base/CCleaner）与 `non-CCleaner Winapp2.ini` 两种 flavor |
| `bleachbit/winapp2.ini` | https://github.com/bleachbit/winapp2.ini | `Winapp2-BleachBit.ini`（完整版，借鉴来源） | 默认分支 `master`；本仓库已从中借鉴 5 条（见 [winapp2-integration.md](./winapp2-integration.md) §五） |
| `bleachbit/cleanerml` | https://github.com/bleachbit/cleanerml | CleanerML 规则范式（参考，不直接消费） | 仅作格式/分类参考，本工具不解析 CleanerML |

> 关键事实：本地 `winapp2_full.ini` = MoscaDotTo 的 **non-CCleaner** flavor。裁决保持此变体，不升级为 BleachBit 完整版（理由见 [winapp2-integration.md](./winapp2-integration.md) §二）。

## 二、检查上游是否更新（具体命令）

以下命令依赖 `gh` CLI 且已登录（`gh auth status` 确认）。所有 API 调用只读，不改动本仓库。

```bash
# 1) MoscaDotTo/Winapp2：non-CCleaner Winapp2.ini 的最近改动
gh api repos/MoscaDotTo/Winapp2/commits?path=non-CCleaner%20Winapp2.ini&per_page=1 \
  --jq '.[0] | {sha, date: .commit.committer.date, msg: .commit.message}'

# 2) BleachBit 完整版的最近改动
gh api repos/bleachbit/winapp2.ini/commits?path=Winapp2-BleachBit.ini&per_page=1 \
  --jq '.[0] | {sha, date: .commit.committer.date, msg: .commit.message}'

# 3) 概览仓库近期活跃（决定是否需要关注）
gh api repos/MoscaDotTo/Winapp2/commits?per_page=3 --jq '.[].commit.committer.date'
gh repo view bleachbit/winapp2.ini --json updatedAt,pushedAt
```

> 注：GitHub 的 `contents` API 对 >1MB 文件可能截断；`winapp2_full.ini` 约 1.33 MB，**不要**用 `gh api .../contents/...` 取全文，改用「按文件查 commits 看最近修改日期」+「`raw.githubusercontent.com` 拉取全文后本地 diff」的组合。

## 三、借鉴筛选原则（只借安全的）

纳入本地库前，候选条目**必须全部满足**：

1. **非浏览器隐私数据**（排除 Chrome/Edge/Firefox/Brave 等同步/缓存类）。
2. **非厂商专有工具**（排除三星/Intel/HP/Lenovo/ASUS 等只有该软件才产生的缓存）。
3. **带 `DetectFile` 门控**（未安装则不展开，零误伤）。
4. **路径限定** `AppData` / `ProgramData` / `LocalApplicationData`（不碰系统核心或用户文档）。
5. **保守默认**：补入后默认仅进「需确认」队列，不标 `Default=True` 自动清理。
6. 每条记录 `source`（上游 blob sha 或 commit）与补入日期，便于回溯。

**决策标准（何时采纳 / 何时拒绝）**：
- 上游新增「Windows 系统级垃圾」（更新缓存、错误报告、缩略图/图标缓存、预读取等）→ **采纳**，按上述 6 条登记。
- 上游新增浏览器/厂商专有条目 → **拒绝**（与"宁可少删"原则冲突，且隐私风险高）。
- 上游仅为版本号/措辞调整、无新增清理目标 → **忽略**。
- 任何会导致本地规则数偏离「Non-CCleaner 变体」定位的批量升级 → **拒绝**。

## 四、自主闭环 SOP（Agent 可直接照做）

> 目标：让一个对仓库毫无了解的 Agent，也能安全、可验证地跟进上游演进。每步都有明确成功/失败信号；失败即停、不擅自放宽保护。

**步骤 0 — 环境核验**
```bash
gh auth status                                  # 必须已登录，否则停止并报错
pwsh -File ./tests/run_pester.ps1 ./tests/cleanup_candd.tests.ps1   # 基线须全绿（当前 42/42）
```
信号：登录成功 + 测试全绿，方可继续；否则中止。

**步骤 1 — 取上游最近修改日期**
执行 §二 命令，记录 `MoscaDotTo/Winapp2` 与 `bleachbit/winapp2.ini` 的 `date`/`sha`。

**步骤 2 — 判断是否真有更新**
比较上游 `date` 与本地 `winapp2_full.ini` 文件 `LastWriteTime`（或上次补入注释块记录的日期）。
- 上游无新提交 → **结束**（无需动作）。
- 上游有更新 → 进入步骤 3。

**步骤 3 — 拉取全文并 diff**
```bash
# 拉取 non-CCleaner flavor（注意空格编码为 %20）
curl -L -o /tmp/upstream_noncc.ini https://raw.githubusercontent.com/MoscaDotTo/Winapp2/master/non-CCleaner%20Winapp2.ini
# 若 curl 在沙箱不可用，改用：
#   gh api repos/MoscaDotTo/Winapp2/git/blobs/<sha> --jq '.content' | base64 -d > /tmp/upstream_noncc.ini
diff <(grep -i '^\[' winapp2_full.ini) <(grep -i '^\[' /tmp/upstream_noncc.ini)   # 对比节名集合，找新增/删除
```
信号：明确列出「上游有而本地无」的节名清单。

**步骤 4 — 按 §三 筛选，只保留安全候选**
对步骤 3 的新增节逐条套用 6 条筛选原则，产出「拟借鉴清单」。

**步骤 5 — 补入本地库**
在 `winapp2_full.ini` 尾部追加注释块（含来源 sha/日期），逐条追加条目；格式与现有 5 条 BleachBit 借鉴一致（见文件尾部 `; BleachBit/winapp2.ini 借鉴补入` 块）。

**步骤 6 — 再生候选清单**
```powershell
.\winapp2_expand.ps1 -Winapp2Path .\winapp2_full.ini -OutCsv .\winapp2_full_expanded.csv
```
信号：解析条数 = 本地基线 + 新增条数；处置行随新增增长但无异常报错。

**步骤 7 — 回归验证（硬门槛）**
```bash
pwsh -File ./tests/run_pester.ps1 ./tests/cleanup_candd.tests.ps1   # 必须 42/42 全绿
```
信号：全绿才可提交；任一失败 → 回退步骤 5 的改动，重复，不得带红提交。

**步骤 8 — 提交（遵循仓库 Git 纪律）**
- 仅推自有 fork（`origin`），**绝不推 upstream**；禁强推/删 `main`。
- 提交消息注明：上游 sha、日期、新增条数、测试结论。
- 同步更新本文件 §一 的「最近核验日期」与 [winapp2-integration.md](./winapp2-integration.md) 的实测数据。

**中止条件（任一触发即停）**：`gh` 未登录 / 测试非全绿 / 候选无法全部满足 §三 6 条 / 需放宽双层硬保护才能并入。前两条直接中止；后两条拒绝该候选并写明理由，不动其它已验证内容。

## 五、节奏建议

- 常规：每月一次「步骤 1–2」轻量检查；仅当上游确有更新才走完整 SOP。
- 重大 Windows 版本/补丁季后可主动检查（系统级垃圾热点常随更新涌现）。
