# 方案甲（伴生扩展器）落地与 DryRun 验证报告

> 生成时间：2026-08-01
> 关联文档：`ANALYSIS_FluentCleaner_vs_CleanupCandD.md`（首轮对比）、`COST_ANALYSIS_Winapp2_Hybrid.md`（成本审计，推荐方案甲）
> 验证环境：Windows（PowerShell 5.1）、本机 `cleanup_cd.ps1`（v 现状，未改动）

## 一、目标与方案回顾

**方案甲（零改动伴生扩展器）** 的核心思想：不改动既有 `cleanup_cd.ps1`，而是新增一个独立的 `winapp2_expand.ps1`，把 Winapp2 / Winappx 规则库展开为与 `cleanup_cd.ps1` **同构**的处置清单 CSV（`FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason`），再交给 `cleanup_cd.ps1 -CsvPaths` 消费。由此：

- 复用 `cleanup_cd.ps1` 的全部**双层硬保护**（安全根 / 系统核心）与 **DryRun 默认零副作用**；
- 扩展器只"展开 / 列出"，绝不删除任何文件，删除决策完全交给既有脚本；
- 既能吸纳 FluentCleaner 的规则体系（数据驱动、应用检测、变量通配符、ExcludeKey、可审计），又对现状零侵入。

## 二、交付物

| 文件 | 说明 |
| --- | --- |
| `winapp2_expand.ps1` | 方案甲核心：Winapp2 规则解析 + 变量展开 + 递归通配符 + 检测门控 + ExcludeKey 豁免 + 同构 CSV 写出（约 470 行，含 UTF-8 BOM） |
| `winapp2_sample.ini` | 验证样例库（5 条规则，覆盖缓存清理 / 安全根探针 / 系统核心探针 / ExcludeKey / 真实应用检测四类机制） |
| `cleanup_plan_conservative.md` | 样例「保守策略」DryRun 报告 |
| `cleanup_plan_auto.md` | 样例「自动清理策略」DryRun 报告 |
| `cleanup_plan_real.md` | 真实 Winapp2.ini 全量扩展后的 DryRun 报告（聚合） |

## 三、样例 DryRun 验证（双层硬保护证明）

样例库含 5 条规则、6 个处置目标，专门构造了"会撞上硬保护"的探针：

- `ZW Demo App Cache` → `%Temp%\zw_demo_app\a.tmp`/`b.tmp`（普通临时文件）
- `ZW Demo SafeRoot Probe` → `D:\ZW工作\zw_saferoot_probe`（**安全根**目录，REMOVESELF）
- `ZW Demo SystemCore Probe` → `C:\Windows\Temp\zw_systemcore_probe`（**系统核心**目录，REMOVESELF）
- `ZW Demo ExcludeKey` → `%Temp%\zw_exclude_app` 下 `drop.tmp` 待清、`keep.db` 经 ExcludeKey 豁免
- `ZW Demo Installed Edge` → `%LocalAppData%\Microsoft\Edge\User Data\*\Cache`（真实应用检测 + `\*\` 通配段 + REMOVESELF）

扩展器默认输出 `需确认`，开启 `-Winapp2AutoDelete` 时输出 `自动清理`。对两份 CSV 分别做 `cleanup_cd.ps1 -CsvPaths -Mode DryRun`，得到 A/B 对照：

| 处置类别 | 保守策略（默认 `需确认`） | 自动清理策略（`-Winapp2AutoDelete`） |
| --- | --- | --- |
| 确定拟删除 | **0** | **4**（a.tmp / b.tmp / drop.tmp / Edge Cache，均在 Temp 或 LocalAppData，非保护） |
| 待确认 | 5（含系统核心探针） | 0 |
| 安全根二次确认 | **1**（`D:\ZW工作\zw_saferoot_probe`） | **1**（同左——即便 Winapp2 标"自动删除"仍被升为二次确认） |
| 系统核心降级待确认 | 0（本就是 Confirm，不触发降级） | **1**（`C:\Windows\Temp\zw_systemcore_probe` 被强制降级） |
| 实际删除文件 | **0（DryRun）** | **0（DryRun）** |

**结论（双层硬保护均成立）：**

1. **安全根优先于自动删除**：`D:\ZW工作` 下的探针在两种策略下都落入"安全根二次确认"，绝不自动删除。
2. **系统核心强制降级**：`C:\Windows` 下的探针即便 Winapp2 标"自动删除"，也被强制降为"待确认"，绝不自动删除。
3. **ExcludeKey 豁免生效**：`keep.db` 未出现在任何清单中（扩展器 `ExcludeKey 豁免命中: 1`）。
4. **真实应用检测 + 通配段**：Edge 的 `%LocalAppData%\Microsoft\Edge\User Data\*\Cache` 正确解析为 `...\TestProfile\Cache`（`\*\` 通配段 + REMOVESELF 组合路径通过验证）。
5. **DryRun 零副作用**：两次运行均明确输出"未删除任何文件"。

## 四、本轮修复记录（规模测试暴露的真实问题）

规模测试不仅验证了吞吐，还暴露并修复了两个真实集成缺陷：

1. **`Test-DetectFile` 健壮性（真实库必需）**：真实 Winapp2.ini 中存在 `DetectFile=C:\Windows|SIGVERIF.TXT` 这类"路径|子串"高级语法，原代码直接把整串喂给 `Test-Path -LiteralPath` 触发"非法字符"异常。已改为像 `Test-Registry` 一样按 `|` 拆分、仅校验文件路径、并加 `try/catch` 兜底返回 `$false`（保守判定为"未安装"）。修复后真实库全量解析零报错。
2. **`-IncludeReg` 的 `REG::` 前缀崩溃**：原实现给注册表规则行加 `REG::` 前缀，导致 `cleanup_cd.ps1` 的 `Split-Path` 误判为 PowerShell 提供程序而崩溃（"找不到名为 REG 的提供程序"）。因 RegKey 本就是"仅备注、cleanup_cd 不删注册表"，已去掉 `REG::` 前缀改用纯注册表路径串 + 明确 Reason 标记。复跑 `-IncludeReg` 不再崩溃。

（历史已修复项见前序记录：PowerShell 5.1 UTF-8 无 BOM 中文乱码 → 加 BOM；`Join-Path` 三段参数 → 嵌套；固定大小数组 `.Add()` → `ArrayList`；`Expand-FileKey` 文件分支处理。）

## 五、规模冒烟测试

| 测试 | 规则数 | 耗时 | 通过检测 | ExcludeKey 命中 | 输出行 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 真实 Winapp2.ini（文件级，默认） | 3721 | 4.6s | 167 | 1 | 30312 | 311 个 RegKey 跳过；全量解析无报错 |
| 真实 Winapp2.ini（`-IncludeReg`） | 3721 | 4.4s | 167 | 1 | 30625 | REG:: 崩溃修复后正常 |
| 合成 2000 条（全通过检测，真实枚举） | 2000 | 1.5s | 2000 | 200 | 3800 | 单条平均 ~0.75ms，吞吐充足 |
| 合成库 `-MaxEntries 100` 限速 | 2000 | 0.1s | 100 | 10 | 190 | 节流生效，适合大库分批 |

**吞吐结论**：解析 + 检测 + 展开管道约 **800–1300 条目/秒**（真实库偏 I/O 密集，因 167 个已装应用实际枚举了约 3 万文件；合成库偏 CPU）。`-MaxEntries` 提供可控分批入口，避免全库一次性枚举过久。

## 六、真实库集成结果（实际价值）

真实 Winapp2.ini 经扩展器产出 **30312** 行处置清单，交由 `cleanup_cd.ps1` DryRun 消费，**无崩溃**，结果为：

- 待确认：**30312 项 / 1,256.28 MB（约 1.23 GB）**
- 确定拟删除：0（默认保守，全部 `需确认`）
- 安全根二次确认 / 系统核心降级：0（本机 167 个已装应用的缓存均未落入安全根或系统核心）

即：方案甲在本机可一次性识别出约 **1.2 GB** 的已装应用缓存清理候选，且默认全部保守待确认、零误删风险。用户可在 `cleanup_cd.ps1` 的 DryRun 报告中逐项审阅，必要时再显式进入 Execute。

## 七、结论与后续建议

1. **方案甲可行且低风险**：零改动 `cleanup_cd.ps1`，独立扩展器复用其全部保护与 DryRun 语义，A/B 两策略均验证双层硬保护生效、零误删。
2. **默认保守策略推荐**：日常使用保持默认（输出 `需确认`），把所有 Winapp2 候选先列为待确认，经 DryRun 报告人工审阅后再决定。
3. **RegKey 仅备注**：`-IncludeReg` 为可选开关，注册表清理不在文件清理范围内，仅作备注列出。
4. **大库分批**：对完整 Winapp2.ini 建议配合 `-MaxEntries` 分批、或先人工裁剪规则子集，控制单次枚举规模。
5. **后续可选项**：可把"用户选定的规则子集"固化为本地 `.ini` 纳入版本管理，使清理规则可审计、可回滚（呼应首轮报告"可审计 / 数据驱动"优点）。

## 八、已知限制

- 扩展器忠实移植了 FluentCleaner.Core 的核心组件（Parser / PathExpander / DetectionService / CategoryResolver / ExcludeKey），但**未**实现其全部边界（如 DetectFile 的"文件内容子串匹配"仅做存在性校验、`SpecialDetect` 仅覆盖主流浏览器、LangSecRef 分类表为节选）。真实库全量解析已无报错，但个别冷门规则的分类/检测可能不精确——在"保守 + DryRun"策略下不影响安全性。
- 真实库 30k 行清单的"实际可清理量"依赖本机已装应用；未安装应用因检测门控不通过，不会产生处置行（符合预期）。
