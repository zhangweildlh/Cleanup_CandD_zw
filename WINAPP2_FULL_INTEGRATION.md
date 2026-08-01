# Winapp2 全量规则集成说明（方案甲落地 · 全量转化）

> 本文档记录第三轮工作的延续：**把 FluentCleaner 内置的真实 Winapp2 规则库（3721 条）整套纳入本项目，并展开为本机可直接消费的清理候选清单**。
> 落地形态为「规则数据外置 + 脚本消费」——`cleanup_cd.ps1` 零改动，双层硬保护照常生效。

---

## 一、本次「全量转化」交付了什么

| 资产 | 文件 | 体量 | 说明 |
|------|------|------|------|
| 真实规则库（权威源） | `winapp2_full.ini` | 1,392,621 B（≈1.33 MB） | 3721 条规则，可审计、可更新 |
| 全量候选清单（派生） | `winapp2_full_expanded.csv` | 6.73 MB / 32937 行 | 由扩展器从 ini 生成，`cleanup_cd` 可直接吃 |
| 扩展器（工具） | `winapp2_expand.ps1` | — | 把 ini 展开为同构 CSV，**零改动** `cleanup_cd` |
| 验证样例 | `winapp2_sample.ini` | — | 5 条专门构造的硬保护探针规则 |

> 注：`cleanup_plan_full.md` 并非随库交付的资产，而是由下方「日常用法」第 1 步 `cleanup_cd` 现场生成的 DryRun 报告，按需命名即可。

---

## 二、本机实测关键数据

- 规则总数：**3721**
- 已装应用（通过 `DetectFile`/`Detect` 门控）：**167**
- 跳过 RegKey（默认未启用 `-IncludeReg`）：**311**
- 展开处置行：**32936**
- 候选清理总量：**1,534.58 MB（约 1.5 GB）**
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
