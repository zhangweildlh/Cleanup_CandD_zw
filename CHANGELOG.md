# 变更日志（Changelog）

本文件为 Tier 1 发版门禁要求的交付物，记录每次发版的变更类型与内容。
历史版本标签见 `git tag`（v0.1.0 / v0.2.0 / v0.3.0）。

---

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
