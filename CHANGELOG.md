# 变更日志（Changelog）

本文件为 Tier 1 发版门禁要求的交付物，记录每次发版的变更类型与内容。
历史版本标签见 `git tag`（v0.1.0 / v0.2.0 / v0.3.0）。

---

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
