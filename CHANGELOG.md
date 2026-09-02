# 变更日志（Changelog）

本文件为 Tier 1 发版门禁要求的交付物，记录每次发版的变更类型与内容。
历史版本标签见 `git tag`（v0.1.0 / v0.2.0 / v0.3.0）。

---

## [v0.5.2] - 2026-09-02

### 新增（Feature）
- **重建 `tests/` 测试套件（81 用例 / 42 个 Describe 块，1436 行）**：按用户决策重建并大幅扩充
  （v0.5.0 为 45 用例），覆盖**全功能 / 全场景 / 全边界**：
  - **A 板块（12 例）**：内置 `powershell-audit-regression` 技能的**六项 AST 静态审计**
    （A 重复函数定义 / B 函数污染 / C param 与 `$script:` 同名 / D 函数内写外层作用域 /
    E `return @()` 拆包 / F 自动变量遮蔽）+ 编码检查；每项配「构造缺陷脚本 → 断言被抓住」的反证，
    并含 B 项的**不误报**负向用例。审计脚本随仓库分发于 `tests/tools/Invoke-PSAstAudit.ps1`，
    不依赖本机技能路径。
  - **B 板块（~32 例）**：`winapp2_expand.ps1` —— Detect 门控（含「裸 `SOFTWARE\` 缺根键」边界）、
    ExcludeKey 管道分隔格式、分类回退链、`-MaxEntries`、多模式 FileKey 等。
  - **C/F 板块（~30 例）**：`cleanup_cd.ps1` —— Execute 模式三种行为、GBK/UTF-16 编码回退、
    RFC4180 边界、`-MaxDepth`、DryRun 零副作用（哨兵文件内容与时间戳前后一致）。
  - **D 板块（7 例）**：v0.5.1 四处修复的回归锁定。
  - **E 板块（3 例）**：**反证复现**——构造修复前写法实测其错误行为并输出判词。
  - **Z 板块（2 例）**：测试**零残留自证**（产物统一走 `zw_pester_` 前缀，收尾断言残留为 0）。
- **运行器 `tests/run_pester.ps1` 修复退出码失真**：原实现未加 `-PassThru`，出现
  「Failed: 10 但退出码 0」——CI 会误判为通过。改用 `Invoke-Pester -PassThru` 取回结果对象后
  按 `FailedCount` 决定退出码（`0` 全绿 / `1` 有失败 / `2` 测试文件不存在）。

### 变更（Changelog）
- **文档同步**：`README.md`（文档索引表、Agent 自主闭环 SOP 第 4 步）与 `docs/testing.md`
  从「v0.5.1 起无内置测试套件」更新为当前 81 用例套件的运行方式、覆盖矩阵、
  **变异测试验证方法**与**写新用例的 6 条契约核对清单**。

### 验证
- 本地 Pester 3.4.0（PS 5.1）：**81/81 全绿**，退出码 `0`，`RESIDUE_AFTER_RUN=0`。
- **变异测试**：向 `cleanup_cd.ps1` 注入 v0.5.1 已修的 `Write-Output` 函数污染缺陷 →
  **7 个用例立刻变红**（`Passed=72 Failed=7`，横跨静态审计 / 回归锁定 / 反证对照 / Execute 行为四层）
  → 还原后 `MD5` 与基线一致，业务脚本**零净改动**。

## [v0.5.1] - 2026-09-01

### 修复（Fix）
- **`Write-DeleteStat` 函数污染**：该函数返回值被 `$f = Write-DeleteStat ...` 赋值使用，
  原实现用 `Write-Output` 打日志，日志串入成功输出流使返回值变为数组，导致 `if ($f -gt 0)`
  判定失真——零失败也会被误判为 exit 2。修复：日志改走 `Write-Host`（信息流，不进成功输出流），
  返回值保持干净 `[int]$Stat.Fail`。
- **`Get-ProgramFilesPaths` 环境变量名修正**：`'ProgramW6432Dir'` 并非环境变量名（正确为
  `'ProgramW6432'`），在 32 位宿主(WOW64)下会取空、丢掉真实的 64 位 Program Files，形成保护面缺口。
  注册表回退处的值名 `ProgramW6432Dir` 本就合法，未被误改。
- **`Parse-Winapp2` 换行分割健壮性**：`-split "`r|`n"` 对 CRLF 会分裂出空行，改为 `-split '\r?\n'`，
  CRLF / LF / 混合换行三种输入产出完全一致。
- **`Resolve-Recursive` 自动变量遮蔽**：局部变量 `$matches` 遮蔽 PowerShell 自动变量（`-match`
  的捕获组容器），一旦同作用域引入 `-match` 判断就会静默读到错值；改名为 `$hits`。

### 变更（Changelog）
- **移除 `tests/` 测试套件**：按用户决策，`tests/cleanup_candd.tests.ps1`、`tests/run_pester.ps1`、
  `tests/tools/scan_probe.ps1` 及 `tests/` 目录从仓库移除。v0.5.1 起本仓库不再自带 Pester 回归套件。
- **清理工区**：删除 `winapp2_full_expanded.csv`（43MB 展开过程产物，已 `.gitignore`、无任何引用）
  与 `D:\System\UserTemp\zw_pester_*`（Pester 测试临时/脚手架产物，OS 临时目录）。

### 注意
- 本版本起无内置回归测试，发版正确性依赖人工复核与外部审计（`powershell-audit-regression` 技能）。

## [v0.5.0] - 2026-09-01

### 新增（Feature）
- **目录级自动清理（清空内容、保留目录壳）**：`cleanup_cd.ps1` 在 `Scan-Dir` 枚举阶段新增
  `Test-AutoClearDirName` 三类命名规则判定 + `Clear-AutoDirChildren` 整批处置：
  - 规则1：目录名**恰好等于** `temp` / `tmp` / `cache` / `.temp` / `.tmp` / `.cache`；
  - 规则2：目录名**包含** `temp` / `tmp` / `cache`（如 `mytempdir`、`pipcache`、`templates`）；
  - 规则3：目录名**以** `.temp` / `.tmp` / `.cache` **开头**（如 `.cache2`、`.temp_build`、`.caches`）。
  - 命中且未例外时：把该目录的**直接子项（文件 + 子目录）整批判为 Delete、目录自身不进计划、
    不向下递归**；删除阶段子目录走 `Directory.Delete(子目录, $true)` 整棵移除，匹配目录壳保留。
  - 该能力是**目录级**（旧 `Test-AutoCleanDir` 仅对文件打标签、不删子目录壳），精确实现用户
    「删其下所有子目录与文件、文件夹自身不删除」的诉求。
- **`AI_Work_Temp` 整树例外**：新增 `Test-AutoClearExcluded`（默认例外目录 `AI_Work_Temp`），在
  两处双重豁免——`Scan-Dir` 目录清空判定（`AI_Work_Temp` 及其内部 temp/cache 子目录不再被清空）
  + `Classify-C` / `Classify-D` 文件分类（其下任何文件一律保留、不进自动清理）。满足用户
  「核查 `AI_Work_Temp` 目录已例外」要求；同时 `AI_Work_Temp` 父目录 `D:\Documents` 本就是自动探测的
  安全根，双重兜底。例外目录可通过 `cleanup_config.json` 的 `autoClearExcludeDirs` 追加。

### 修复（Fix）
- **移除旧 `Test-AutoCleanDir` 文件级判定**：旧逻辑用未锚定的「任意父目录名含 temp/tmp/cache」
  正则，会使 `AI_Work_Temp` 内的文件被旁路例外、误判为自动清理。现由目录级 `Clear-AutoDirChildren`
  + 文件级 `Test-AutoClearExcluded` 双重覆盖，彻底消除该旁路。
- 测试套件由 42 用例扩充至 **45 用例**，本地 Pester **45/45 全绿**（新增 3 例：规则1 名恰为 temp、
  规则3 以 `.cache` 开头、规则2 `AI_Work_Temp` 整树例外 + 同级普通 temp 仍清空）。

### 安全提示（重要）
- 规则2（目录名包含 temp/tmp/cache）较激进：如 `templates`、`temporary`、`pipcache` 等也会命中并被清空。
  若需保留此类目录，请加入 `cleanup_config.json` 的 `autoClearExcludeDirs`。
- 三层硬保护对「子项」逐条仍生效：安全根（二次确认）、系统核心（强制降级）、版本控制
  （`.git`/`.svn`/`.hg` 永不删，连清空目录内的 `.git` 子项也跳过）；默认 DryRun + 交互确认。
- 系统核心临时目录（如 `C:\Windows\Temp`）因位于系统核心排除根、扫描阶段即跳过，不会被自动清空，
  符合「系统核心目录零破坏」原则（需清理须显式 `-AllowSystemJunk`）。

### 文档
- `README.md` 功能点改为目录级自动清理语义；`docs/testing.md`、`docs/upstream-tracking.md`
  用例数 42 → 45、最新标签 v0.4.0 → v0.5.0。

## [v0.4.0] - 2026-09-01

### 新增（Feature）
- **临时/缓存目录自动清理分类**（用户决策）：`cleanup_cd.ps1` 的 `Classify-C` / `Classify-D`
  新增 `Test-AutoCleanDir` 判定函数——路径含 `\temp\` / `\tmp\` / `\cache\`（含 `.cache` / `.caches`
  变体）**或**任意父目录名包含 `temp` / `tmp` / `cache`（不区分大小写）的文件，一律判为
  「自动清理（需清空）/ 是（可清空）」。
  - 临时目录（temp）需清空：含普通 `.txt` 在内的所有文件一律 `Delete`，符合用户真实设计意图。
  - 缓存目录（cache）由原先的「需确认」提升为「自动清理」。
  - 日志/崩溃转储等其余 `cacheDirFragments`（`\logs\` / `\log\` / `\crashdumps\` / `\dumps\`）
    仍保持「需确认」（保守，避免误删可诊断数据）。

### 修复（Fix）
- **CI 红灯根因修正**：原失败用例断言「temp 目录下的普通 `.txt` 应保留」，与设计意图冲突；
  实际 temp 目录下所有文件应自动清理。修正测试期望（temp 目录 3 个文件全 `Delete`），并新增
  cache 目录、目录名含 temp 两组用例；扫描根改到 `$env:USERPROFILE` 下，消除 `%TEMP%`
  路径片段差异导致的环境脆弱性（本地假绿 / CI 真红）。
- 测试套件由 39 用例扩充至 **42 用例**，本地 Pester **42/42 全绿**。

### 安全提示（重要）
- 「目录名含 temp/tmp/cache」规则较激进：若扫描整块数据盘，父目录名含 `temp` 的项目文件夹
  （如本机工作区 `AI_Work_Temp`）也会被命中。但**分类 ≠ 删除**：规划阶段决策点仍有
  - 安全根（含自动探测的 Documents / Desktop / Downloads 等）二次确认兜底；
  - 系统核心目录强制降级（Delete → Confirm）；
  - 版本控制目录（`.git` / `.svn` / `.hg`）永不删；
  - 默认 DryRun + 交互确认，不会自动落盘删除。
  建议扫描时指定具体根目录，避免对整盘盲目 `-DeleteConfirmed`。
- 双层硬保护在本次变更中**未被削弱**，保持不变。

### 文档
- `README.md`、`docs/testing.md`、`docs/upstream-tracking.md` 同步用例数 39 → 42、最新标签
  v0.3.0 → v0.4.0，并补充临时/缓存目录自动清理语义说明。
- 新增本 `CHANGELOG.md` 作为 Tier 1 发版门禁交付物。
