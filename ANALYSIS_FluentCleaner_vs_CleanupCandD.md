# FluentCleaner 与 Cleanup_CandD_zw 清理规则对比分析报告

- **分析日期**：2026-08-01
- **分析方法**：使用 browser-skill 打开并阅读 `github.com/builtbybel/FluentCleaner` 仓库的清理规则文件；同时通读本地 `D:\Documents\AI_Work_Temp\Cleanup_CandD_zw` 的脚本与文档。
- **核心结论**：FluentCleaner 在「**数据驱动规则 + 应用级检测门控 + 变量/通配符跨树解析 + 细粒度豁免 + 可审计**」五方面的工程实践，可被本地项目吸纳；其 `Winapp2.ini`/`Winappx.ini` 规则库**本身即可被直接采用**，但需与本地既有的「双层硬保护」对齐，并审慎处理注册表规则（RegKey）。

---

## 0. 信息来源清单

| 对象 | 来源 | 用途 |
| --- | --- | --- |
| `Winapp2-Format_EN.md` | 仓库根目录（格式规范文档） | 理解规则字段语义 |
| `FluentCleaner.Core/Services/Winapp2Parser.cs` | 核心引擎 | 解析逻辑 |
| `FluentCleaner.Core/Services/PathExpander.cs` | 核心引擎 | 变量展开 + 通配符解析 |
| `FluentCleaner.Core/Services/DetectionService.cs` | 核心引擎 | 应用检测门控 |
| `FluentCleaner.Core/Services/CategoryResolver.cs` | 核心引擎 | 分类映射 |
| `FluentCleaner.Core/Models/*` | 核心引擎 | 数据模型 |
| `Winapp2.ini`（前 4 条真实规则样本） | 仓库根目录 | 印证规则结构 |
| `README.md` | 仓库根目录 | 设计理念与特性 |
| 本地 `cleanup_cd.ps1`（784 行）、`README.md`、`CODE_REVIEW_REPORT.md` | 本地仓库 | 剖析现状 |

---

## 1. FluentCleaner 清理规则体系剖析

### 1.1 规则格式：Winapp2.ini（INI 分节 + 编号多值键）

规则以 INI 段落组织，每段描述「一个应用/一类清理项」，字段含义如下：

| 字段 | 格式 | 作用 |
| --- | --- | --- |
| `[App Name *]` | 区块头 | 规则名；结尾 `*` 表示社区条目 |
| `LangSecRef` | 数字（如 3029） | 分类编号（见 1.2） |
| `Detect` | `HKLM\Software\Foo[\|Value]` | 注册表键/值存在 → 应用已装 |
| `DetectFile` | `%LocalAppData%\MyApp` | 文件/文件夹存在 → 应用已装 |
| `SpecialDetect` | `DET_CHROME` 等 | 知名应用的检测速记 |
| `FileKeyN` | `<path>\|<pattern>[|RECURSE\|REMOVESELF]` | 文件清理目标 |
| `RegKeyN` | `<HIVE>\<path>[\|<value>]` | 注册表清理目标 |
| `ExcludeKeyN` | `FILE\|PATH\|REG\|<path>\|[pattern]` | 白名单豁免 |
| `Warning` | 文本 | 清理前向用户提示风险 |
| `Default` | `True/False` | 是否默认勾选 |

**真实样本（仓库 Winapp2.ini 前 4 条）**：

```
[Google Chrome Autofill Data & Search Engine Preferences *]
LangSecRef=3029
Default=False
DetectFile=%LocalAppData%\Google\Chrome*
FileKey1=%LocalAppData%\Google\Chrome*\User Data\*|*Web Data
FileKey2=%LocalAppData%\Google\Chrome*\User Data\AutoFill*|*|REMOVESELF
```

### 1.2 引擎架构（高度模块化，`FluentCleaner.Core`）

- **`Winapp2Parser`**：把 INI 解析为 `CleanerEntry` 对象；用正则识别 `FileKey\d+`/`RegKey\d+`/`ExcludeKey\d+`/`Detect\d*`。关键校验 `IsValid`：**必须同时具备「检测条件」与「清理目标」**才保留该条目；纯检测无目标、纯目标无检测的都被丢弃。
- **`PathExpander`**：把 `%AppData%`/`%LocalAppData%`/`%ProgramFiles%` 等约 20 个变量映射到本机真实路径；并递归解析路径段中的 `*`/`?` 通配符，跨目录树展开为具体路径；对 `%ProgramFiles%` **自动补试 x86 变体**。还专门修正「`%SystemDrive%` 展开为 `C:` 仅表示驱动器的当前工作目录而非根」的陷阱。
- **`DetectionService`**：回答「该应用是否真的已安装」。多条 `Detect`/`DetectFile` 用 **OR 逻辑**（命中任一即成立）；`SpecialDetect` 速记（如 `DET_CHROME`）直接映射为已知路径检测。
- **`CategoryResolver`**：`LangSecRef` 数字 → 分类名（如 `3029→Google Chrome`、`3021→Applications`），未知码回退到 `Section` 字段，再回退到 `Other Applications`。
- **`Models`**：`CleanerEntry`/`FileKeyEntry`/`RegKeyEntry`/`ExcludeKeyEntry`/`ScanResult`，职责清晰。

### 1.3 设计理念（README 明确表述）

1. **具体、可检视、可审计**：每条规则只清理它显式声明的目标，「无全盘广通配符、无盲目删除」。
2. **选择优先 ≈ 等效 DryRun**：不勾选不运行；`winapp2.ini` 条目只清理被明确指定的内容。
3. **刻意不做注册表清理**：认为注册表清理风险/收益倒挂（误删可破坏系统），仅清理「明确是垃圾」的缓存/临时/日志。
4. **刻意不做安全删除多遍覆写**：认为对 SSD + 缓存/日志类文件属「安全剧场」。
5. **多数据库可插拔**：支持自定义 `winapp2.ini`（设置→数据库→自定义），官方库来自社区维护的 Winapp2 项目（数千条目、15+ 年积累）。
6. **无界面/自动化**：`FluentCleaner.exe /AUTO` 静默清理并写详细日志（`auto.log`：时间戳 + 每路径 + 总清理体积）。

---

## 2. 本地 Cleanup_CandD_zw 现状剖析

### 2.1 架构

- **入口**：`cleanup_cd.ps1`（PowerShell，默认 DryRun、零副作用）。支持 `-Root` 现场扫描或 `-CsvPaths` 读既有清单。
- **规则载体**：`Classify-C`（C 盘）与 `Classify-D`（其它盘）两个函数，**规则以正则路径片段硬编码在代码里**（如 `\\\$recycle\.bin\\`、`\\cache\\`、`.tmp/.log` 等）。
- **处置映射**：`Map-Cleanable` 把 `Cleanable` 标签（是/否/谨慎 或 自动清理/需确认/保留）统一为 `Delete/Confirm/Keep`。
- **双层硬保护**：① 安全根拦截（`D:\ZW工作`、`D:\Tools`、`D:\Documents` 硬编码兜底）；② 系统核心目录（`C:\Windows` 等）强制降为待确认。
- **其它**：自研 RFC4180 CSV 解析（BOM/UTF-16 兼容）、扫描跳过 NTFS 重解析点、底层 .NET API 删除（绕开本机 safe-delete 对 `Remove-Item` 的钩子）、目录删除确认对象统一为目录自身。

### 2.2 优点（应保留）

- **保守优先、零误删风险**：双层硬保护 + DryRun 默认，对系统/工作目录零破坏。
- **零外部依赖**：纯 PowerShell + .NET，无需编译器/运行时。
- **健壮的 CSV 工程**：自研解析兼容多种编码，表头大小写不敏感。
- **已通过严格代码审查**：`CODE_REVIEW_REPORT.md` 显示 4 个严重 BUG（重解析点崩溃、确认/删除路径不一致、注释不符、误提交）已全部修复闭环。

### 2.3 局限（相对 FluentCleaner）

| 维度 | 本地现状 | 短板 |
| --- | --- | --- |
| 规则载体 | 硬编码于 `Classify-C/D` 函数 | 规则与代码强耦合，新增/维护需改代码、重测 |
| 应用检测 | 无 | 不验证「某应用是否真的存在」，纯按路径片段匹配，可能列无效项 |
| 路径变量 | 无 | 不识别 `%AppData%` 等语义变量，靠正则硬编码 `\\users\\[^\\]+\\...`，覆盖不全且难维护 |
| 通配符跨树 | 无 | 无法表达「某应用目录下递归的所有 `*.log`」 |
| 细粒度豁免 | 仅「安全根前缀」 | 缺少文件级精确白名单（如「保留 config.db」） |
| 可审计性 | DryRun 报告较粗 | 规则本身不可读、不可逐条检视 |
| 规则库规模 | 仅自研少量规则 | 无现成应用级覆盖（数千应用） |
| 多数据库/自定义 | 无 | 无法插拔第三方规则库 |

---

## 3. 问题一：FluentCleaner 的优点可否被本地吸纳？

**结论：多数优点可吸纳，且吸纳成本低、与本地「保守安全」哲学不冲突。** 逐条如下：

| # | FluentCleaner 优点 | 可否吸纳 | 本地落地方式 | 价值 |
| --- | --- | --- | --- | --- |
| A | **数据驱动规则**：规则外置为 ini，与代码解耦 | ✅ 强烈建议 | 新增「规则层」解析 `Winapp2.ini`；`Classify-C/D` 改为「内置保守兜底 + 外置规则库叠加」 | 规则可维护、可版本化、可社区共享 |
| B | **应用级检测门控**（Detect/DetectFile/SpecialDetect） | ✅ 建议 | 扫描/规划前先判定应用是否安装，未安装则跳过该规则 | 避免列出无效项、降低误报 |
| C | **变量 + 通配符跨树解析**（PathExpander） | ✅ 建议 | 在 PowerShell 中实现等价的变量映射与递归通配符展开 | 覆盖更全、路径表达力强 |
| D | **ExcludeKey 细粒度豁免** | ✅ 建议 | 作为「白名单豁免层」叠加在本地双层硬保护之上 | 比安全根前缀更精确（保留某具体文件/子树） |
| E | **可审计/可检视**（RawText、Warning、Default） | ✅ 建议 | DryRun 报告增加「规则来源 + Warning 提示」列 | 用户清理前可逐条审查 |
| F | **CategoryResolver 分类体系** | ✅ 可选 | 用 `LangSecRef` 给清单条目分大类（浏览器/多媒体/工具…） | 报告分组更清晰 |
| G | **多数据库可插拔**（CustomEntryService） | ✅ 可选 | 支持 `-RulePaths` 指定自定义 ini | 复用社区/个人规则库 |
| H | **/AUTO 静默 + 结构化日志** | ⚠️ 部分 | 本地已可脚本化；可增加「每路径 + 体积」结构化日志 | 便于 Task Scheduler 定时清理 |
| ❌ | WinUI 3 图形界面 | 否 | 本地是 CLI 工具，无 UI 需求 | 不适用 |
| ❌ | 注册表清理（RegKey） | 否（见 4.3） | 本地当前仅清文件；注册表清理风险高 | 与本地哲学一致地审慎 |
| ❌ | 安全删除多遍覆写 | 否 | FluentCleaner 本人也认为属安全剧场 | 一致地不采纳 |

---

## 4. 问题二：FluentCleaner 的清理规则可否被本地吸纳？

**结论：可以，且收益显著。** `Winapp2.ini`/`Winappx.ini` 是格式标准、社区维护（数千条目、15+ 年）的现成规则库，本地无需从零自研应用级覆盖。

### 4.1 吸纳的技术路径

1. **解析器**：在 PowerShell 中实现 `Winapp2Parser` 等价逻辑——按 `[区块]` 分节，用正则识别编号多值键 `FileKeyN/RegKeyN/ExcludeKeyN/DetectN*`，校验「检测条件 + 清理目标」齐备才保留。
2. **变量映射**：实现 `PathExpander`——把 `%AppData%`/`%LocalAppData%`/`%ProgramFiles%`/`%Temp%` 等约 20 个变量映射到本机实际路径（复用 `Environment.GetFolderPath` 等价 API），并对 `%ProgramFiles%` 自动补试 x86 变体。
3. **检测门控**：先跑 `DetectionService` 等价逻辑，仅当应用确实安装时才把该规则的 `FileKey` 展开为待清理清单。
4. **规则落地为处置项**：将展开后的具体路径经本地 `Map-Cleanable` 映射为 `Delete/Confirm/Keep`，并入现有 DryRun 报告与执行流程。
5. **注册表规则处理**（关键决策）：见 4.3。

### 4.2 与本地「双层硬保护」的对齐

这是吸纳时必须处理的核心安全点，二者**互补而非冲突**：

- **`ExcludeKey`（白名单豁免）** → 作为「规则级豁免层」，优先级最高：规则想删的，只要命中 ExcludeKey 就跳过。
- **本地安全根 + 系统核心保护** → 作为「全局兜底层」：无论规则如何声明，落于 `D:\ZW工作`/`D:\Tools`/`D:\Documents` 或 `C:\Windows` 等的拟删项，依旧被本地硬保护拦截/降级。
- **要点**：本地硬保护是「最后闸门」，绝不被 Winapp2 规则绕过。Winapp2 规则解决「清什么」，本地硬保护解决「绝不误伤工作/系统目录」。

### 4.3 不建议照搬的部分

1. **注册表规则（RegKey）**：Winapp2.ini 含大量 `RegKeyN`（注册表清理）。FluentCleaner 自身也**刻意弱化注册表清理**并明确其风险/收益倒挂；本地是 PowerShell 文件清理工具，新增注册表删除能力风险高。**建议**：初期只采纳 `FileKey`/`Detect`/`ExcludeKey`，`RegKey` 默认忽略；若确有需要，单独评估并加审批闸门。
2. **过于激进的社区条目**：Winapp2 个别条目可能清理你希望保留的内容（如某些 `Default=False` 的「谨慎」项）。应延续本地「保守默认」——社区条目默认归入 `Confirm`（待确认），而非直接 `Delete`。
3. **`%SystemDrive%` 类根级通配**：PathExpander 已修正该陷阱，本地实现须同样处理，否则可能误扫整个 `C:`。

---

## 5. 吸纳路线图（若决定实现，建议以新分支 + PR 推进）

1. **阶段一**：新增 `winapp2_parser.ps1`（解析 INI 分节 + 编号多值键 + 校验）。
2. **阶段二**：新增 `path_expander.ps1`（变量映射 + 递归通配符展开 + x86 补试 + 根级陷阱修正）。
3. **阶段三**：新增 `detect_service.ps1`（Detect/DetectFile/SpecialDetect 门控）。
4. **阶段四**：把 `Classify-C/D` 改造为「**内置保守兜底 + 外置 Winapp2 规则库叠加**」并行运行；`ExcludeKey` 接入为最高优先级豁免层。
5. **阶段五**：DryRun 报告增加「规则来源 / LangSecRef 分类 / Warning 提示」；可选支持 `-RulePaths` 自定义库。
6. **阶段六**：注册表规则（RegKey）保持忽略，或在独立审批闸门下可选开启。

> 以上改动属于对本地 GitHub 仓库（`zhangweildlh/Cleanup_CandD_zw`）的代码修改，若实施可走 `github-personal-manager` 技能的标准流程（新分支 → 提交 → 推 origin → 开 PR / 直接合并），并遵循「禁止强推/删除 main」「注册表等破坏性能力需显式授权」等既有约束。

---

## 6. 风险与注意事项

- **规则库体积**：`Winapp2.ini` 数千条目、展开后路径极多，现场扫描须复用本地已有的「NTFS 重解析点跳过」「ExcludeRoots 跳过系统目录」等守卫，防止枚举爆炸。
- **编码/性能**：PowerShell 解析大 INI 需控制内存；建议先解析为对象再展开，避免一次性 `Get-Content` 巨文件。
- **公开仓库敏感性**：本地 `full_inventory2/3.csv` 含本机目录结构（README 已提示），吸纳更通用的 Winapp2 规则后，规则文件本身不涉密，但**运行产物仍可能含本机路径**，须保持 `.gitignore` 忽略运行时产物（已通过 F4 修复）。
- **误删闸门**：无论吸纳多少规则，本地「DryRun 默认 + 双层硬保护 + 安全根不可被参数移除」三道闸门必须保留为最高优先级。

---

## 7. 总结

- **问题一（优点吸纳）**：FluentCleaner 的「数据驱动规则、应用检测门控、变量/通配符跨树解析、ExcludeKey 细粒度豁免、可审计、多数据库可插拔」六项工程优点，均可在不破坏本地「保守安全」哲学的前提下吸纳；图形界面、注册表清理、安全覆写三类不建议照搬。
- **问题二（规则吸纳）**：`Winapp2.ini`/`Winappx.ini` 规则库**可被直接采用**——其格式标准、社区维护、覆盖数千应用，能一举补足本地「应用级覆盖不足、规则硬编码」的短板；采纳时须以本地「双层硬保护」为全局兜底、将 `ExcludeKey` 作为规则级豁免、并审慎忽略注册表规则（RegKey）。

**一句话建议**：把本地脚本从「硬编码正则的全盘扫描器」演进为「保守兜底 + 可插拔 Winapp2 规则库」的混合架构，是性价比最高、风险可控的吸纳方向。
