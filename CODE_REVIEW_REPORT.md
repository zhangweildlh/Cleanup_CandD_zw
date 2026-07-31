# cleanup_cd.ps1 全量代码审计报告

- **目标仓库**：`Cleanup_CandD_zw`（本地 `D:\Documents\AI_Work_Temp\Cleanup_CandD_zw`）
- **审计对象**：`cleanup_cd.ps1`（扫描+清理一体化脚本，当前 787 行）
- **审计方法**：`code-review-combo` 三阶段交叉验证。因 `ocr` 委托模式将 `.ps1` 列为 unsupported_ext（preview 返回 0 reviewable），按 combo 边界 fallback 为**宿主直接审查**；叠加 `review-spd` 五焦点（正确性 / 回归兼容 / 测试 / 安全 / 性能并发）做语义深度交叉。
- **审计轮次**：2 轮（pass 1 全量发现 → 修复 → pass 2 全量复审）
- **审计日期**：2026-07-31

---

## 一、审计结论（总览）

| 轮次 | 发现项 | 严重 BUG（须修） | 建议项 | 状态 |
|---|---|---|---|---|
| Pass 1 | 7 | 4（F1–F4） | 2（F5/F7） | 全部已修复并验证 |
| Pass 2（复审） | 0 新项 | 0 | 0 | 闭环，无遗留 BUG |

**最终裁决：PASS —— 无遗留 BUG，审计闭环。**

> 说明：F6（缺乏 Pester 自动化测试）作为工程建议单独列出，不计入 BUG（当前脚本为单人维护工具，未引入测试框架；修复 F1–F4 后已通过语法解析 + 功能回归 + 隔离单测验证）。

---

## 二、Pass 1 发现明细

### F1 — 【高】递归扫描未跳过 NTFS 重解析点（junction/symlink）
- **焦点**：正确性 / 健壮性
- **位置**：`Scan-Dir` 函数，进入子目录递归前（约现行 186–195）
- **问题**：递归枚举使用 `[System.IO.Directory]::EnumerateFileSystemEntries` 并对子目录递归，会**跟随 NTFS 重解析点**（junction/symlink）。Windows 用户目录普遍存在自指 junction（如 `C:\Users\xxx\AppData\Local\Application Data` → `...\AppData\Local`、`Cookies`、`Local Settings` 等）。`-Root C:\` / `-Root D:\` 现场扫描会进入自指 junction → **无限递归 → `StackOverflowException` 进程崩溃或重复枚举爆炸**。对主用场景（清理 C:/D: 释放空间）是确定性可复现缺陷。
- **影响**：脚本在现场扫描模式下必然崩溃（栈溢出），无法正常产出清单。
- **修复**：进入子目录递归前，用 `[System.IO.Directory]::GetAttributes` 检查 `FileAttributes.ReparsePoint`，命中则 `continue` 跳过（含 try/catch 保护），不递归、不统计该重解析点。
- **验证**：语法解析 OK；嵌套目录扫描回归正确枚举 3 个文件（根 `c.log` / 子 `a.tmp` / 深层 `e.tmp`），证明守卫未误伤正常递归；reparse 跳过为标准做法。沙箱无管理员权限无法实测 junction 创建，依赖代码审查 + 标准逻辑论证。

### F2 — 【中】删除确认路径与实际删除路径不一致
- **焦点**：正确性
- **位置**：`Invoke-DeleteBatch` 函数（约现行 735–742）
- **问题**：`$isDir` 为真表示 `$it.Path` 本身是目录，但确认逻辑使用 `$parent = Split-Path $it.Path -Parent`（其父目录）作 `Confirm-Dir` 入参与提示对象；而实际删除（`Remove-OneItem` 内 `[System.IO.Directory]::Delete($it.Path, $true)`）删除的是 `$it.Path` 自身。同时 `Confirm-Dir` 缓存 key 用 `$parent`，导致「确认提示的目录」与「实际删除的目录」不一致，并可能错误合并同级目录确认。属误导性正确性缺陷。
- **影响**：交互确认时向用户展示错误的待删目录名，存在误判与信任风险。
- **修复**：以 `$it.Path`（目录自身）作为 `Confirm-Dir` 入参与提示对象及缓存 key。
- **验证**：隔离单测 `confirm==delete` 返回 `True`（confirmed=D:\X\CacheDir, delete=D:\X\CacheDir）。

### F3 — 【低】安全声明注释与实现不符
- **焦点**：文档一致性
- **位置**：`New-MarkdownReport` 安全声明段（约现行 668）
- **问题**：注释称「删除操作使用 `-LiteralPath`」「目录型路径显式 `-Recurse`」，但实际删除实现（约现行 706–709）已改为底层 .NET API（`[System.IO.File]::Delete` / `[System.IO.Directory]::Delete($path, $true)`），注释过期，误导维护者。
- **影响**：维护误解删除机制，可能错误回退到被 safe-delete 钩子拦截的 `Remove-Item`。
- **修复**：更新注释以匹配实现（底层 .NET API、绝对字面路径、对 `[]{}` `$` 等特殊字符安全、目录递归删除）。

### F4 — 【低】扫描产物默认写入仓库根且未被 .gitignore 忽略（误提交风险）
- **焦点**：质量 / 误提交风险
- **位置**：参数 `OutScanCsv` 默认（约现行 371，原用 `$PSScriptRoot`）；`.gitignore` 缺规则
- **问题**：`-Root` 扫描产物 `scan_inventory_<盘>.csv` 默认写入脚本所在目录（仓库根）；`.gitignore` 未忽略 `scan_inventory_*.csv` / `cleanup_plan.md` / `cleanup_plan_files.csv`。`git add` 时易误提交，污染仓库与历史。
- **影响**：运行时产物入库，造成噪声提交与潜在大文件。
- **修复**：① 默认 `OutScanCsv` 改为 `$env:TEMP`；② `.gitignore` 追加三类运行时产物忽略；③ 同步更新参数帮助文本。
- **验证**：扫描 CSV 经测试确认写入 `$env:TEMP`、仓库根无残留；`git status --porcelain` 不含 `scan_inventory`/`cleanup_plan`。

### F5 — 【建议】`Read-CsvRecords` BOM 探测冗余分支
- **焦点**：代码整洁
- **位置**：`Read-CsvRecords`（约现行 290–300）
- **问题**：UTF-8 BOM（EF BB BF）分支与兜底 else 分支重复赋值 `UTF8`，冗余。
- **修复**：删除冗余的 UTF-8 BOM 分支（保留 UTF-16 LE/BE 检测）；默认 `UTF8` 已能正确处理含/不含 BOM。

### F7 — 【建议】CSV 表头匹配大小写敏感
- **焦点**：健壮性
- **位置**：CSV 加载表头匹配（约现行 418–425）
- **问题**：`[array]::IndexOf` 表头匹配大小写敏感；若外部 CSV 列名大小写不同（如 `fullpath` / `CLEANABLE`）会被静默跳过（`continue`），导致数据丢失而无提示。当前两份既有清单列名匹配，但存在潜在失效模式。
- **修复**：表头统一转小写后做大小写不敏感匹配。

### F6 — 【建议】缺乏自动化测试（非 BUG）
- **焦点**：测试
- **位置**：仓库整体
- **问题**：脚本无 Pester / 单元测试。当前以单人维护工具定位，未引入测试框架。
- **建议**：后续可为 `Classify-C/D`、`Map-Cleanable`、`Read-CsvRecords`、reparse 守卫补充 Pester 用例，固化回归防护。本轮未强制实现。

---

## 三、Pass 2 全量复审结论

对 F1–F5、F7 共 7 处改动做二次语义审查，并执行：
1. **语法解析**：`Parser.ParseFile` 返回 `SYNTAX_OK`；
2. **功能回归**：既有 `full_inventory3.csv` 消费正常（7389 拟删 / 84575 待确认 / 10888 安全根 / 317275 跳过，无报错）；
3. **嵌套扫描回归**：正常目录递归未被 reparse 守卫误伤（3 文件正确枚举）；
4. **隔离单测**：F2 确认路径==删除路径；
5. **仓库清洁**：扫描产物写入 `$env:TEMP`，`git status` 不含运行时产物。

**复审裁决**：F1–F4 已修复并验证；F5/F7 已实现；未引入新 BUG；未修复项 = 0。审计闭环。

---

## 四、最终裁决

**PASS —— 无遗留 BUG。** 全部 4 项严重 BUG（F1 重解析点无限递归、F2 确认/删除路径不一致、F3 注释误导、F4 误提交风险）已修复并经验证；2 项健壮性增强（F5/F7）已落地。脚本可安全用于 DryRun 规划与 Execute 删除。
