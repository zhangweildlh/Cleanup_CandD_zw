# 代码审计报告 — code-review-combo 交叉验证

> 目标仓库：D:\Documents\AI_Work_Temp\Cleanup_CandD_zw（Git / main）
> 审查对象（全库代码文件，用户要求全库扫描）：
> - `cleanup_cd.ps1`（784 行，磁盘清理主脚本）
> - `winapp2_expand.ps1`（476 行，Winapp2 规则扩展器）
> 方法：code-review-combo 三阶段（open-code-review-delegate 委托 + review-spd 五焦点 + 宿主合并）
> 环境：无 LLM 配置，ocr scan/review 不可用；`ocr delegate preview` 与 `review-context.py` 均确认工作区无未提交改动（0 文件）；按「整文件即待审查代码」精神，由宿主直接审查两个 `.ps1` 整文件（委托模式本质：OCR 做确定性，宿主做判断）。

---

## 第一轮审计发现

### 报告 A（委托宿主审查：PowerShell 规则 + 正确性/安全）

- **F-1**：`winapp2_expand.ps1` 条目名解析（第 344 行附近）——Winapp2 约定条目名末尾 `*` 表示**默认禁用**（等价于 `Default=False`）；代码仅 `TrimEnd('*')` 作显示名，未设 `Default=$false`。后果：开启 `-Winapp2AutoDelete` 时，此类默认禁用条目被错误标为「自动清理」（第 425 行 `$e.Default -ne $false` 为真）。严重度 **high**。经实读代码核实。
- **F-2**：`winapp2_expand.ps1` 第 342 行 `if ($name -like 'Winapp2*' ...)`——意图跳过 `[Winapp2]`/`[Version]` 元数据节，但 `-like 'Winapp2*'` 会误伤任何以 "Winapp2" 开头的应用节名（如 `[Winapp2 Chrome]`），合法规则被丢弃不展开。严重度 **medium**。经实读核实。
- `cleanup_cd.ps1`：结构稳健，双层硬保护（安全根 / 系统核心）逻辑正确，CSV 解析（`Read-CsvRecords` RFC4180 + BOM 探测）鲁棒，删除使用 `.NET LiteralPath` API + DryRun 默认 + 交互确认，无严重缺陷。

### 报告 B（review-spd 五焦点语义审查）

- **正确性 / Correctness**：确认 F-1、F-2 为真实逻辑缺陷（非误报）。
- **回归 / 兼容性**：新脚本，无既有 API 契约需兼容。
- **测试 / 验证（gap，非 bug）**：两脚本均无自动化测试（无 Pester），解析 / 展开 / 分类逻辑缺回归覆盖——最大隐性风险。
- **安全 / 数据**：`winapp2_expand` 仅「列出」不删；`cleanup_cd` 删除路径设计安全。F-1 在 AutoDelete 模式下过度标「自动清理」，但被 `cleanup_cd` 硬保护（安全根 / 系统核心）兜底，不直接误删系统 / 工作文件，风险可控。
- **性能 / 并发**：全量展开 3721 条 / 9s，可接受；单线程无并发问题。

### 合并唯一报告（findings + JSON）

| ID | 文件:行 | 类别 | 严重度 | verified_by | cross_check | 描述 |
|----|---------|------|--------|-------------|-------------|------|
| F-1 | winapp2_expand.ps1:344/425 | bug | high | both | confirmed | 名带 `*` 默认禁用条目未识别为 `Default=$false`，AutoDelete 模式误标「自动清理」 |
| F-2 | winapp2_expand.ps1:342 | bug | medium | both | confirmed | `-like 'Winapp2*'` 误伤以 Winapp2 开头的应用节 |

（cleanup_cd.ps1 无严重缺陷）

```json
{
  "tool": "code-review-combo",
  "mode": "dual-cross-validation",
  "repository": "D:\\Documents\\AI_Work_Temp\\Cleanup_CandD_zw",
  "target": { "type": "workspace", "from": "HEAD", "to": "working tree" },
  "files": [
    { "path": "cleanup_cd.ps1", "status": "reviewed", "insertions": 0, "deletions": 0 },
    { "path": "winapp2_expand.ps1", "status": "reviewed", "insertions": 0, "deletions": 0 }
  ],
  "findings": [
    { "path": "winapp2_expand.ps1", "start_line": 344, "end_line": 344, "category": "bug", "severity": "high",
      "comment": "Winapp2 条目名末尾 * 表示默认禁用，应设 Default=$false；当前仅 TrimEnd 显示名，导致 -Winapp2AutoDelete 时误标自动清理",
      "suggestion": "解析 Name 时若原 name 以 * 结尾则 Default=$false", "verified_by": "both", "cross_check": "confirmed" },
    { "path": "winapp2_expand.ps1", "start_line": 342, "end_line": 342, "category": "bug", "severity": "medium",
      "comment": "-like 'Winapp2*' 误伤以 Winapp2 开头的应用节名，合法规则被丢弃",
      "suggestion": "改为精确匹配 $rawName -eq 'Winapp2' -or $rawName -eq 'Version'", "verified_by": "both", "cross_check": "confirmed" }
  ],
  "summary": { "files_reviewed": 2, "critical": 0, "high": 1, "medium": 1, "low": 0, "ocr_only": 0, "review_spd_only": 0 }
}
```

### 残留风险 / 测试缺口

- 两脚本均无 Pester 测试；建议后续补充解析 / 展开单测以防回归（非当前阻塞 bug）。
- F-1 在默认保守模式（不开 AutoDelete）下不影响分类（全部需确认），仅 AutoDelete 模式受影响。

---

## 第二轮审计（修复后重审 + 联网核验语义）

### 关键语义核验（联网取证）

重审阶段对 Winapp2 `*` 后缀的真实语义做了权威核验，结论推翻了第一轮对 F-1 的前提假设：

- **FluentCleaner 官方格式规范（zread.ai）**：「a trailing `*` marker (the Winapp2 convention for community-contributed entries) is **silently stripped** by the parser」——`*` 仅是社区贡献条目的**排版标记**，被解析器静默剥离，**不是禁用语义**。
- **CCleaner 社区原帖**：「The `*` Is just a **formatting thing**, to denote that the entry is not part of the regular program」。
- **MoscaDotTo/Winapp2 规范**：真正的禁用标记是 `Default` 键——`Default=False` 表示默认不清理；`Default=True` 表示默认清理；且「CCleaner assumes `Default=False` by default」。

> 结论：**节名末尾 ` *`（空格+星号）纯属排版标记，禁用语义只由 `Default=False` 键表达。**

### F-3（修正 F-1 的错误前提 —— high，本轮新发现）

- **问题**：第一轮 F-1「修复」建立在错误前提上——误把排版标记 `*` 当作「默认禁用」语义，给所有名尾带 `*` 的条目标 `Default=$false`。但真实库（MoscaDotTo 格式）**每个**节名都以 ` *` 结尾（3721/3721），且无 `Default` 键的常规启用条目（3287 条）本应可在 `-Winapp2AutoDelete` 下标「自动清理」。F-1 修复导致真实库全部 3721 条被误判为禁用，AutoDelete 模式**无一可自动清理**（回归）。原始代码（`Default=$null` + 下游 `$e.Default -ne $false`）反而正确。
- **修复**：撤销 `*$` → `Default=$false` 逻辑；保留 `*` 仅从**显示名**剥离（对齐 FluentCleaner 规范）；分类逻辑维持 `$Winapp2AutoDelete -and $e.Default -ne $false`（即：仅 `Default=False` 键 → 需确认；无键/`Default=True` → 自动清理）。
- **验证**：
  - `test_fix.ini` 三用例（默认保守 / AutoDelete）：`Default=False` → 需确认；无键 → 自动清理；`Default=True` → 自动清理。全部符合预期。
  - 真实库 `winapp2_full.ini`：解析 3721 条无回归；保守模式 34309 行全「需确认」；AutoDelete 34146「自动清理」+ 165「需确认」（165 = 已装应用中 `Default=False` 条目数，符合预期）；显示名 ` *` 剥离生效（抽样 `Google Chrome Caches`，残留 0）。

### 第二轮全库重审结论（findings + JSON）

| ID | 文件:行 | 类别 | 严重度 | 状态 | 描述 |
|----|---------|------|--------|------|------|
| F-1 | winapp2_expand.ps1:344-348 | bug(误判) | high | **已撤销/纠正为 F-3** | 原「`*`=禁用」前提错误，已改为仅剥离显示名 |
| F-2 | winapp2_expand.ps1:342-343 | bug | medium | 已修复(保持) | `-like 'Winapp2*'` → 精确匹配元数据节，正确保留 |
| F-3 | winapp2_expand.ps1:344-348 | bug(回归修正) | high | 已修复 | 撤销 `*`→`Default=$false` 误判，恢复 `Default` 键语义 |

（cleanup_cd.ps1 第二轮复核：安全根/系统核心双层硬保护、Map-Cleanable 保守默认、删除执行 DryRun 默认 + LiteralPath + 交互确认，均无缺陷。）

```json
{
  "tool": "code-review-combo",
  "mode": "dual-cross-validation-round2",
  "repository": "D:\\Documents\\AI_Work_Temp\\Cleanup_CandD_zw",
  "reaudit": {
    "verified_by": "web-semantic-check + host re-audit",
    "f1_premise_overruled": true,
    "f3_corrected": "reverted *->Default=$false; kept * display-name strip; classification unchanged"
  },
  "files": [
    { "path": "winapp2_expand.ps1", "status": "reaudited", "insertions": 0, "deletions": 0 },
    { "path": "cleanup_cd.ps1", "status": "reaudited", "insertions": 0, "deletions": 0 }
  ],
  "findings": [
    { "path": "winapp2_expand.ps1", "start_line": 344, "end_line": 348, "category": "bug", "severity": "high",
      "comment": "F-1 前提错误：Winapp2 节名末尾 * 是排版标记(社区贡献条目)，非禁用语义；禁用语义仅由 Default=False 键表达。原 F-1 给全库 3721 条误标 Default=$false，致 AutoDelete 无一可自动清理（回归）。",
      "suggestion": "撤销 *->Default=$false；保留 * 仅作显示名剥离；分类维持 $e.Default -ne $false", "verified_by": "web+host", "status": "fixed-as-F3" },
    { "path": "winapp2_expand.ps1", "start_line": 342, "end_line": 343, "category": "bug", "severity": "medium",
      "comment": "F-2 元数据节精确跳过，修复正确且保留", "verified_by": "host", "status": "fixed-kept" }
  ],
  "summary": { "files_reviewed": 2, "critical": 0, "high": 1, "medium": 1, "low": 0, "new_bugs_round2": 1, "resolved": 1, "remaining": 0 }
}
```

### 残留风险 / 测试缺口（仍有效）

- 两脚本仍无 Pester 自动化测试；本轮仅用手工探针 `test_fix.ini` + 真实库做了分类回归验证（非持续集成）。建议后续补 Pester 单测以防回归（非当前阻塞 bug）。
- `Winapp2AutoDelete` 在真实库下会标 34146 条「自动清理」——该模式为显式信任开关，且仍过 cleanup_cd 双层硬保护 + 默认 DryRun；日常推荐保守模式（不开 AutoDelete），审阅 CSV 后再决定。

### 审计循环终止判定

第二轮重审未发现 F-3 之外的新 BUG；F-1/F-2/F-3 均已修复/纠正并验证。按用户指令「直到审计不出 BUG」，本轮循环可终止，代码库当前状态：**零已知 BUG**。
