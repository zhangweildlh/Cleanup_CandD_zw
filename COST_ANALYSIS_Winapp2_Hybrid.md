# 第二次分析 + 审计：混合架构「保守兜底 + 可插拔 Winapp2 规则库」实现成本评估

- **分析日期**：2026-08-01（第二轮）
- **审计对象**：`ANALYSIS_FluentCleaner_vs_CleanupCandD.md`（首份报告）
- **本轮新增焦点**：对首份报告做准确性审计，并**全面评估实现成本**（首份报告仅给出路线图，未量化工作量/风险/测试/性能）。
- **方法**：复读首份报告 + 复核对本地 `cleanup_cd.ps1`（784 行）的集成切入点（主流程 366–478、硬保护 441–468、`Map-Cleanable` 264–269、执行 760–783）+ 复核对 FluentCleaner 引擎源码（Winapp2Parser / PathExpander / DetectionService / CategoryResolver）的移植可行性。

---

## 1. 对首份报告的审计结论

**总体判定：技术结论基本正确，但「成本维度缺失、两处表述需修正、三处低估」。** 具体如下：

| # | 审计项 | 结论 | 修正/补充 |
| --- | --- | --- | --- |
| A1 | 「Winapp2 规则库可被**直接采用**」（首报 4/问题二） | ⚠️ 略高估完整性 | Winapp2 是「文件 + 注册表」双库；本地仅清文件，故实为**文件侧（FileKey）采用、RegKey 侧暂不采用**，实际覆盖约 **40–60%** 条目的有用价值，并非整体「整库直接采用」。 |
| A2 | 路线图未量化成本（首报第 5 节） | ❌ 缺失 | 本轮补全：组件级工作量 + 三档方案 + 风险/测试/性能成本。 |
| A3 | PowerShell 通配符语义差异 | ⚠️ 低估 | C# 用 `Directory.GetFileSystemEntries(base, wildcard)`（Win32 语义）；PowerShell `Get-ChildItem -Filter` 的 glob 语义不同（不匹配隐藏、`*` 跨扩展名行为不同）。移植须**直接复用 .NET API** 才能对齐，否则正确性风险。 |
| A4 | `Default` 字段与本地 `Confirm/Delete` 映射 | ⚠️ 未明确 | 须显式规定：`Default=False`（社区「谨慎」项）→ 本地 `需确认(Confirm)`；`Default` 省略/True → 仍建议默认 `Confirm`，仅当用户显式 `-Winapp2AutoDelete` 才降为 `Delete`。保守优先。 |
| A5 | **零改动伴生扩展器路径**（最大遗漏） | ❌ 未提出 | 现有 `cleanup_cd.ps1 -CsvPaths` 已能消费 `FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason` 同构 CSV。可写**独立** `winapp2_expand.ps1` 把 Winapp2 展开为该 CSV，**不改一行现有脚本**即复用全部硬保护。这是成本/风险最低的切入点（见第 2 节方案甲）。 |
| A6 | 性能/规模风险一笔带过（首报 6） | ⚠️ 低估 | Winapp2 数千条目 ×（检测：注册表/文件探测）×（展开：目录枚举）全量运行耗时可观，且会大量触发 `UnauthorizedAccessException`（C# 静默捕获）。需 profiling + 复刻静默容错，属真实成本。 |

> 首报在「优点可吸纳（问题一）」「双层硬保护对齐（4.2）」「RegKey 暂不采纳（4.3）」三处表述准确，予以确认，本轮不再赘述。

---

## 2. 三档实现方案的成本对比

| 方案 | 做法 | 改动现有脚本 | 工作量 | 风险 | 复用硬保护 | 推荐度 |
| --- | --- | --- | --- | --- | --- | --- |
| **甲：伴生扩展器（零改动）** | 新增独立 `winapp2_expand.ps1`，解析+检测+展开 Winapp2 → 输出**既有 CSV 同构文件** → `cleanup_cd.ps1 -CsvPaths` 消费 | **0 行** | 中（≈1 个新文件） | 低 | ✅ 100% 自动继承（加载期 441–468 仍生效） | ⭐⭐⭐ 起步首选 |
| **乙：原生内嵌（`-RulePaths`）** | 在 `cleanup_cd.ps1` 内新增解析/展开阶段，并入 `planDelete/planConfirm/planSafe/planGuarded`；报告增加「规则来源」列 | 中（改主流程 366–478 + 参数 + 报告） | 中-高 | 中（回归现有 CSV 路径） | ✅ 仍经同一硬保护 | ⭐⭐ 二期 |
| **丙：替换 Classify-C/D** | 用 Winapp2 完全取代内置正则分类 | 高（重写核心分类） | 高 | 高（丢失内置兜底、回归面大） | ✅ 仍生效但兜底变弱 | ✅ 不推荐初期 |

**关键结论**：方案甲即可交付约 80% 的价值（数千应用的文件级覆盖），且**不碰已通过审计的 784 行脚本**，是当前性价比与安全性最优的落地形态。

---

## 3. 组件级工作量与风险拆解（方案甲/乙的共享内核）

| 组件 | C# 原型行数 | PowerShell 预估行数 | 工作量 | 风险 | 移植要点 |
| --- | --- | --- | --- | --- | --- |
| `Winapp2Parser` | ~70 | 80–120 | S | 低 | INI 分节；`\r`-only 行分割；编号键正则 `^FileKey\d+$`；`IsValid` 校验「检测+目标」齐备 |
| `PathExpander` | ~160 | 120–200 | M | 中 | 变量映射（~20 个 `Environment.GetFolderPath`）；递归通配符跨树；`%ProgramFiles%` 补试 x86；`%SystemDrive%` 根级陷阱修正；**须用 `[System.IO.Directory]::GetFileSystemEntries` 而非 PS glob**（见 A3） |
| `DetectionService` | ~120 | 100–160 | M | 低-中 | 注册表只读探测（安全）；`SpecialDetect` 速记 ~7 码；`Detect/DetectFile` 的 OR 逻辑；权限异常静默返回 false |
| `CategoryResolver` | ~50 | 40 | S | 低 | `LangSecRef`→名称 的哈希表，未知回退 `Section`→`Other` |
| `ExcludeKey` 应用 | 模型+应用 | 80–120 | M | 中 | 必须在展开**之后**作最高优先级豁免（FILE 仅直接子项 / PATH 递归子树）；否则可能误删白名单文件 |
| 伴生器 CSV 输出（甲） | — | 60–100 | S | 低 | 复用既有 7 列 schema；`Cleanable` 按 A4 策略赋值 |
| 原生集成粘合（乙） | — | 150–250 | M | 中 | 主流程插入解析阶段；参数 `-RulePaths`/`-Winapp2AutoDelete`；报告增「规则来源/LangSecRef/Warning」列 |
| **Pester 测试** | — | 200–400 | M-H | — | 本地**无测试框架**（首报 F6）；此为最大隐性成本，约等于甚至超过实现本身 |

**汇总量级（相对估算，非精确人日）**：
- 方案甲内核 ≈ **1 个新文件 / 500–750 行实现 + 等额测试**，定性「**中**」。
- 方案乙 = 甲 + **150–250 行集成 + 回归测试**，定性「**中-高**」。

---

## 4. 首报遗漏的关键成本项（细化）

1. **PowerShell 通配符语义坑（A3）**：这是移植 `PathExpander` 最易翻车处。必须调用 .NET `Directory.GetFileSystemEntries(base, wildcard)` 以复刻 Win32 `*`/`?` 行为，不能用 PowerShell 的 `-Filter`/通配符参数。
2. **`Default` 字段映射（A4）**：规则未声明或 `Default=True` 不代表「对你安全」，社区库默认保守；映射策略须代码化并写进报告。
3. **性能与规模（A6）**：建议实现「先检测、后展开」（C# 即如此：未安装则不展开），并缓存环境变量映射；对 `UnauthorizedAccessException`/`IOException` 静默跳过（与 C# 一致），避免单条规则异常中断全量。
4. **零改动伴生扩展器（A5）**：首报最大遗漏。它把「枚举/展开」责任完全隔离到新文件，现有 `cleanup_cd.ps1` 的 `Map-Cleanable`、双层硬保护、`-LiteralPath` 删除、reparse 跳过、RFC4180 解析**全部无需改动即自动生效**——这是把风险降到最低的工程杠杆。

---

## 5. 风险场景与缓解（含与本地硬保护的衔接验证）

| 场景 | 风险 | 缓解（方案甲下） |
| --- | --- | --- |
| 某 FileKey 带 `REMOVESELF`，展开后落于 `D:\ZW工作` 子树 | 误删工作文件 | 扩展器输出 CSV 的 `FullPath` 在 `cleanup_cd.ps1` 加载期经 `Test-SafeRootMatch`（441–468）拦截为「安全根二次确认」；即便扩展器漏判，本地硬保护仍兜底 |
| `ExcludeKey` 未正确应用 | 删白名单文件 | 扩展器内先应用 ExcludeKey；本地硬保护为第二道闸门（双重安全） |
| 通配符语义偏差 → 过匹配 | 误删范围扩大 | 保守偏向「漏匹配」（少删）更安全；且硬保护兜底 |
| 检测用注册表键无读取权限 | 该规则被跳过（覆盖降低） | 安全副作用，仅减覆盖不增风险 |
| Winapp2 库版本更新引入激进条目 | 清理意外内容 | 库文件纳入版本控制、变更可审；DryRun 默认 + `Confirm` 默认 |

**衔接验证结论**：方案甲下，Winapp2 衍生项与现有 CSV 项走**同一条** `Map-Cleanable` + 安全根 + 系统核心保护流水线，信任模型不降级；唯一新增信任面是「扩展器本身的正确性」，可通过 Pester 单测 + DryRun 人工复核控制。

---

## 6. 修正后的路线图（带 effort / risk 标注）

| 阶段 | 内容 | Effort | Risk | 备注 |
| --- | --- | --- | --- | --- |
| 0 | 落库 `Winapp2.ini`（版本固定、纳入 git 或放 `$env:TEMP`） | S | 低 | 规则文件不涉密 |
| 1 | 写 `winapp2_expand.ps1`：Parser + PathExpander + DetectionService + CategoryResolver | M | 中 | 方案甲内核 |
| 2 | ExcludeKey 应用 + `Default`→`Confirm/Delete` 映射（A4） | S | 中 | 关键安全策略 |
| 3 | 输出既有 CSV → `cleanup_cd.ps1 -CsvPaths` 跑 DryRun 验证 | S | 低 | **零改动现有脚本** |
| 4 | Pester 单测（解析/展开/检测/豁免各一组样例） | M-H | — | 填首报 F6 缺口 |
| 5（可选） | 升级为方案乙：内嵌 `-RulePaths`，报告增「规则来源」列 | M | 中 | 二期 UX 增强 |
| 6（不建议初期） | RegKey 注册表清理（需独立审批闸门 + 显式授权） | H | 高 | 与本地哲学一致地暂缓 |

---

## 7. 成本结论与推荐切入点

- **总实现成本定性为「中」**：核心是一个独立 PowerShell 扩展器（≈500–750 行）+ 等额测试；**不强制改动已审计的 784 行脚本**即可获得数千应用的文件级覆盖。
- **最大隐性成本是测试**：本地无 Pester 框架（首报 F6），建立测试本身是约等于实现的投入，但能固化回归防护、降低误删风险，建议与实现同步进行。
- **最大技术风险是通配符语义对齐**（A3）与 ExcludeKey 应用时机（第 3 节），二者均有明确缓解（用 .NET API、展开后应用豁免）。
- **推荐路径**：先落地**方案甲（伴生扩展器，零改动）**，用 DryRun 验证后视需要再升级为方案乙。避免方案丙（替换 Classify-C/D）。

**一句话成本结论**：从「硬编码正则全盘扫描器」演进为「保守兜底 + 可插拔 Winapp2 规则库」，通过「伴生扩展器产出既有 CSV」的零改动路径，可用**中等工作量、低风险**实现，且完整保留本地既有的三道误删闸门（DryRun 默认 + 安全根 + 系统核心保护）。
