# Winapp2 全量规则集成说明（方案甲落地 · 全量转化）

> 本文档记录第三轮工作的延续：**把 FluentCleaner 内置的真实 Winapp2 规则库（3721 条）整套纳入本项目，并展开为本机可直接消费的清理候选清单**。
> 落地形态为「规则数据外置 + 脚本消费」——`cleanup_cd.ps1` 零改动，双层硬保护照常生效。

---

## 一、本次「全量转化」交付了什么

| 资产 | 文件 | 体量 | 说明 |
|------|------|------|------|
| 真实规则库（权威源） | `winapp2_full.ini` | 1,394,342 B（≈1.33 MB） | 3726 条规则（3721 基线 + 5 条 BleachBit 借鉴补入），可审计、可更新 |
| 全量候选清单（派生） | `winapp2_full_expanded.csv` | 6.73 MB / 32937 行 | 由扩展器从 ini 生成，`cleanup_cd` 可直接吃 |
| 扩展器（工具） | `winapp2_expand.ps1` | — | 把 ini 展开为同构 CSV，**零改动** `cleanup_cd` |
| 验证样例 | `winapp2_sample.ini` | — | 5 条专门构造的硬保护探针规则 |

> 注：`cleanup_plan_full.md` 并非随库交付的资产，而是由下方「日常用法」第 1 步 `cleanup_cd` 现场生成的 DryRun 报告，按需命名即可。

---

## 二、本机实测关键数据

- 规则总数：**3726**（3721 基线 + 5 条 BleachBit 借鉴补入）
- 已装应用（DetectFile 门控，依赖本机状态）：**160**（实时探测值，随已装软件浮动）
- 跳过 RegKey（默认未启用 `-IncludeReg`）：**283**（实时探测值，随环境浮动）
- 展开处置行：**155159**（实时探测值，随本机已装软件浮动）
- 候选清理总量：**随本机已装软件与文件体积浮动，以 DryRun 报告为准**（保守策略下零自动删除）
- 保守策略下确定拟删除：**0**（零自动删除，全部进入待确认）
- DryRun 全程文件删除：**0**

---

## 三、日常用法（先审后删）

```powershell
# 1) 演习：只生成报告，不删除任何文件
.\cleanup_cd.ps1 -CsvPaths .\winapp2_full_expanded.csv -Mode DryRun -OutMd cleanup_plan_full.md

# 2) 人肉审阅 cleanup_plan_full.md，确认无误后再真正执行
.\cleanup_cd.ps1 -CsvPaths .\winapp2_full_expanded.csv -Mode Execute
```

> 注意：`Execute` 前务必先 `DryRun` 审阅。默认保守策略下，即便执行也是「待确认」项需二次确认，不会无脑删除。

---

## 四、双层硬保护仍全程生效

- **安全根优先**：凡落在 `D:\ZW工作` / `D:\Tools` / `D:\Documents` 的路径，一律升为「二次确认」，优先于任何自动删除。
- **系统核心降级**：凡落在 `C:\Windows` 等的 Delete 项，强制降为「待确认」。
- **保守默认**：本扩展器默认输出「需确认」；即使用户日后开启 `-Winapp2AutoDelete`，上述两层仍优先拦截。

> **语义要点（F-3 修正）**：`-Winapp2AutoDelete` 开启后，仅当节内 `Default=False` 时仍标「需确认」，无 `Default` 键或 `Default=True` 的条目标「自动清理」——真正的禁用语义由 `Default=False` 键表达。节名末尾的 ` *`（空格+星号）仅是社区贡献条目的排版标记，由解析器静默剥离为显示名，**不参与禁用判定**；此前 F-1 误将其当作 `Default=False` 的判定，已在第二轮审计中撤销为 F-3。`[Winapp2]` / `[Version]` 等元数据节在解析时被精确跳过、不产出任何处置行。

---

## 五、如何重新生成（ini 是源，csv 可再生）

规则库更新后，一条命令即可重生候选清单：

```powershell
.\winapp2_expand.ps1 -Winapp2Path .\winapp2_full.ini -OutCsv .\winapp2_full_expanded.csv
```

可选参数：

- `-Winapp2AutoDelete`：默认关闭（保守）。开启后，仅节内 `Default=False` 的条目仍标「需确认」，无 `Default` 键或 `Default=True` 的条目标「自动清理」（仍需双层硬保护拦截）。节名末尾的 ` *` 仅是排版标记，不影响此判定。
- `-IncludeReg`：含注册表规则（仅备注，`cleanup_cd` 不删注册表）。
- `-MaxEntries N`：限速分批，每次只处理前 N 条规则。

---

## 六、版本管理建议

- **建议纳入 git（源 + 工具）**：`winapp2_full.ini`、`winapp2_expand.ps1`、`winapp2_sample.ini`、本说明文档及 `tests/` 下的 Pester 测试套件。
- `winapp2_full_expanded.csv` 为**派生产物**（可由 ini 一键再生），建议加入 `.gitignore` 以免仓库膨胀 6.7 MB；如需「成果快照」也可强纳入，请明示。

---

## 七、已知边界

- 默认跳过 RegKey（注册表清理）；启用 `-IncludeReg` 仅作备注，`cleanup_cd` 不删注册表。
- 真实库含 `DetectFile` 的「路径|子串」高级语法，扩展器已兼容兜底。
- 全量展开约 9 秒；超大库可用 `-MaxEntries` 分批。

---

## 八、变体裁决与 GitHub 借鉴（2026-09-01）

### 8.1 Winapp2 变体裁决：保持 Non-CCleaner，不升级完整版

- **对比对象**：本地 `winapp2_full.ini`（Non-CCleaner 变体，3721 条，v260730） vs BleachBit `Winapp2-BleachBit.ini`（上游完整版，4066 条，v260730）。
- **差集**：本地缺失 367 条（BleachBit 独有）。分类核实：浏览器同步/缓存类 122 条、厂商专有工具（三星/Intel/HP/Lenovo/ASUS 等）约 214 条、设计/办公 5 条、游戏 2 条、缓存日志 24 条。**缺失项中无任何"本地漏掉的 Windows 系统级垃圾"**（仅 2 条含 `Windows` 字样，均为厂商/365 应用，非系统核心）。
- **裁决：保持 Non-CCleaner 变体，不升级完整版**。理由：第一安全原则"宁可少删不可误删"——367 条差集绝大多数是浏览器隐私数据与厂商专有缓存，自动清理既无收益又有误删/隐私风险，与本项目双层硬保护定位冲突；本地变体已覆盖全部 Windows 系统级清理。
- **版本状态**：本地与上游同为 v260730，版本未过时，无需因版本滞后升级。

### 8.2 GitHub 借鉴（BleachBit/winapp2.ini）：经核验补入 5 条

- **来源**：`bleachbit/winapp2.ini` 的 `Winapp2-BleachBit.ini`（v260730，blob sha `ea6e076c`）。
- **筛选原则**：非浏览器 / 非厂商专有 / 带 `DetectFile` 门控 / 路径限定 `AppData` 或 `ProgramData`；保守默认下仅进"需确认"队列，不自动删除。
- **已补入**（见文件尾部 `; BleachBit/winapp2.ini 借鉴补入` 注释块，2026-09-01）：`CefSharp`（嵌入式浏览器框架缓存）、`ImageGlass`（看图器缩略图缓存）、`Composer Dependency Manager for PHP`（Composer 旧包/缓存）、`Adobe Crash Reporter`（Adobe 崩溃日志）、`BreeZip`（商店版压缩工具临时/日志）。
- **已排除**：122 条浏览器同步类（Chrome/Edge/Firefox/Brave 等隐私数据）、全部厂商专有条目，以及 `Grammarly`/`Microsoft Clipchamp` 等极冗长的 WebView 缓存清理段（安全但价值低、徒增审阅噪声）。
- **验证**：补入后解析 3726 条（原 3721 + 5），扩展器再生候选清单 155159 行，Pester 10/10 全绿，无回归。
