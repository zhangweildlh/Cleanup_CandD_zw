---
title: Winapp2 规则集成
description: Winapp2 变体裁决（保持 Non-CCleaner）、F-2/F-3 语义要点、扩展器用法与重新生成、已借鉴的 5 条 BleachBit 条目、版本管理与已知边界。
related:
  - architecture.md
  - configuration.md
  - upstream-tracking.md
  - testing.md
  - ../README.md
updated: 2026-09-01
---

# Winapp2 规则集成（方案甲：零改动伴生器）

把 MoscaDotTo/Winapp2 的真实规则库整套纳入本项目，展开为本机可直接消费的清理候选清单；
`cleanup_cd.ps1` 零改动，其双层硬保护照常生效。落地形态为「规则数据外置 + 脚本消费」。

## 一、本机实测关键数据（2026-09-01）

| 资产 | 文件 | 体量 | 说明 |
|------|------|------|------|
| 真实规则库（权威源） | `winapp2_full.ini` | ≈1.33 MB | **3726** 条（3721 基线 + 5 条 BleachBit 借鉴补入），可审计、可更新 |
| 全量候选清单（派生） | `winapp2_full_expanded.csv` | ≈6.7 MB / 32937 行 | 由扩展器从 ini 生成，`cleanup_cd` 可直接吃 |
| 扩展器（工具） | `winapp2_expand.ps1` | — | 把 ini 展开为同构 CSV，**零改动** `cleanup_cd` |
| 验证样例 | `winapp2_sample.ini` | — | 5 条专门构造的硬保护探针规则 |

- 规则总数：**3726**；已装应用（DetectFile 门控，依赖本机状态）：**160**；跳过 RegKey：**283**；展开处置行：**155159**（均为实时探测值，随本机浮动）。
- 保守策略下确定拟删除：**0**（零自动删除，全部进入待确认）；DryRun 全程文件删除：**0**。

## 二、变体裁决：保持 Non-CCleaner，不升级完整版

- **对比对象**：本地 `winapp2_full.ini`（Non-CCleaner 变体，3721 条，v260730） vs BleachBit `Winapp2-BleachBit.ini`（上游完整版，4066 条，v260730）。
- **差集**：本地缺失 367 条（BleachBit 独有）。分类核实：浏览器同步/缓存类 122 条、厂商专有工具（三星/Intel/HP/Lenovo/ASUS 等）约 214 条、设计/办公 5 条、游戏 2 条、缓存日志 24 条。**缺失项中无任何"本地漏掉的 Windows 系统级垃圾"**（仅 2 条含 `Windows` 字样，均为厂商/365 应用，非系统核心）。
- **裁决：保持 Non-CCleaner 变体，不升级完整版**。理由：第一安全原则"宁可少删不可误删"——367 条差集绝大多数是浏览器隐私数据与厂商专有缓存，自动清理既无收益又有误删/隐私风险，与本项目双层硬保护定位冲突；本地变体已覆盖全部 Windows 系统级清理。
- **版本状态**：本地与上游同为 v260730，版本未过时，无需因版本滞后升级。

## 三、语义要点（F-2 / F-3 修正）

- **F-2 元数据节跳过**：`[Winapp2]` / `[Version]` 为库自身元数据节，解析时精确跳过（按节名精确匹配，避免 `-like 'Winapp2*'` 误伤以 `Winapp2` 开头的应用节），不产出任何处置行。
- **F-3 的 `Default` 键语义**：`-Winapp2AutoDelete` 开启后，**仅当节内 `Default=False` 时仍标「需确认」，无 `Default` 键或 `Default=True` 的条目标「自动清理」**——真正的禁用语义由 `Default=False` 键表达。
- **F-3 的 `*` 显示名剥离**：节名末尾的 ` *`（空格+星号）只是 Winapp2 社区贡献条目的排版标记，由解析器静默剥离为显示名，**不参与禁用判定**；此前 F-1 误将其当作 `Default=False` 的判定，已在第二轮审计中撤销为 F-3。

## 四、扩展器用法与重新生成

规则库更新后，一条命令即可重生候选清单：

```powershell
# 重新生成全量候选清单（ini 是源，csv 可再生）
.\winapp2_expand.ps1 -Winapp2Path .\winapp2_full.ini -OutCsv .\winapp2_full_expanded.csv
```

可选参数：

- `-Winapp2AutoDelete`：默认关（保守）。开启后仅 `Default=False` 的条目仍标「需确认」，其余标「自动清理」（仍需双层硬保护拦截）。
- `-IncludeReg`：含注册表规则（仅备注，`cleanup_cd` 不删注册表）。
- `-MaxEntries N`：限速分批，每次只处理前 N 条规则（规模冒烟用）。

## 五、GitHub 借鉴（BleachBit/winapp2.ini）：已核验补入 5 条

- **来源**：`bleachbit/winapp2.ini` 的 `Winapp2-BleachBit.ini`（v260730，blob sha `ea6e076c`）。
- **筛选原则**：非浏览器 / 非厂商专有 / 带 `DetectFile` 门控 / 路径限定 `AppData` 或 `ProgramData`；保守默认下仅进「需确认」队列，不自动删除。
- **已补入**（见 `winapp2_full.ini` 尾部 `; BleachBit/winapp2.ini 借鉴补入` 注释块，2026-09-01）：
  `CefSharp`（嵌入式浏览器框架缓存）、`ImageGlass`（看图器缩略图缓存）、`Composer Dependency Manager for PHP`（Composer 旧包/缓存）、`Adobe Crash Reporter`（Adobe 崩溃日志）、`BreeZip`（商店版压缩工具临时/日志）。
- **已排除**：122 条浏览器同步类（Chrome/Edge/Firefox/Brave 等隐私数据）、全部厂商专有条目，以及 `Grammarly`/`Microsoft Clipchamp` 等极冗长的 WebView 缓存清理段（安全但价值低、徒增审阅噪声）。
- **验证**：补入后解析 3726 条，扩展器再生候选清单 155159 行，Pester 全绿（见 [testing.md](./testing.md)），无回归。

## 六、版本管理建议

- **建议纳入 git（源 + 工具）**：`winapp2_full.ini`、`winapp2_expand.ps1`、`winapp2_sample.ini`、本目录文档及 `tests/` 下的 Pester 测试套件。
- `winapp2_full_expanded.csv` 为**派生产物**（可由 ini 一键再生），加入 `.gitignore` 以免仓库膨胀 ≈6.7 MB；如需「成果快照」也可强纳入，请明示。

## 七、已知边界

- 默认跳过 RegKey（注册表清理）；启用 `-IncludeReg` 仅作备注，`cleanup_cd` 不删注册表。
- 真实库含 `DetectFile` 的「路径|子串」高级语法，扩展器已兼容兜底（取管道符前路径判定存在性）。
- 全量展开约 9 秒；超大库可用 `-MaxEntries` 分批。
