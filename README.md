# Cleanup_CandD_zw

本地清理与暂存工作区（Cleanup & staging workspace）。

## 用途

本仓库用于在本机 `D:\Documents\AI_Work_Temp\Cleanup_CandD_zw` 目录下，
集中管理临时清理、归档与暂存类的文件与脚本，便于在本地与 GitHub 远端之间同步与回溯。

## 目录约定

- 仓库根目录即本地工作区根目录。
- `.workbuddy/` 与 `.mimocode/` 为智能体工作数据目录，已被 `.gitignore` 忽略，不会纳入版本控制。
- 具体清理任务产生的产物、脚本、清单等，按任务在根目录下自行建立子目录存放。

## 当前内容

- `cleanup_cd.ps1`：**磁盘垃圾文件「扫描 + 清理」一体化脚本**（默认 DryRun、零副作用）。支持两种入口：
  - `-Root <目录>`：现场递归扫描并即时分类，生成与 `cleanup_cd` 同构的处置清单 CSV（字段 `FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason`），随后直接规划处置；
  - `-CsvPaths <清单...>`：直接读取既有处置清单（兼容任意同构 CSV 产物）。
  - 经「标签→处置映射层」规划三类处置（自动清理 / 需确认 / 保留），含安全根拦截与系统核心目录保护双层硬保护。`-Mode Execute` 才真正删除（底层 .NET API，绕开本机 safe-delete 对 `Remove-Item` 的 hook）；`-WhatIf` 可模拟。
  - 分类规则：方案 C（默认用于 C:，Cleanable∈{是,否,谨慎}）/ 方案 D（默认用于其它盘，Cleanable∈{自动清理,需确认,保留}），由路径片段 / 扩展名 / 文件大小 / 修改时间判定。
- （`scan_inventory.ps1` 的扫描能力已并入本脚本，原独立扫描脚本已移除。）
- **v0.3.0 健壮性加固**：扫描递归跳过 NTFS 重解析点（junction/symlink），避免 `-Root` 现场扫描遇自指 junction 无限递归崩溃；目录删除确认对象统一为目录自身（提示与实际删除一致）；扫描清单 CSV 默认写入系统临时目录（`$env:TEMP`）并被 `.gitignore` 忽略，避免污染仓库；CSV 表头大小写不敏感匹配。

## Winapp2 规则集成（方案甲：零改动伴生器）

把 FluentCleaner 内置的真实 Winapp2 规则库整套纳入本项目，展开为本机可直接消费的清理候选清单；`cleanup_cd.ps1` 零改动，其双层硬保护照常生效。

- `winapp2_full.ini`：真实规则库（权威源，3726 条：3721 基线 + 5 条 BleachBit 借鉴补入），可审计、可更新。
- `winapp2_full_expanded.csv`：全量候选清单（派生，由扩展器从 ini 生成，`cleanup_cd` 可直接吃）。
- `winapp2_expand.ps1`：扩展器，把 ini 展开为与 `cleanup_cd` 同构的 CSV。
- `winapp2_sample.ini`：5 条专门构造的硬保护探针规则。

### 语义要点（F-3 修正）

- **`-Winapp2AutoDelete` 开关**：默认关闭（保守），所有衍生项标记「需确认」；开启后，**仅当节内 `Default=False` 时仍标「需确认」，无 `Default` 键或 `Default=True` 的条目标「自动清理」**（仍需过 `cleanup_cd` 的硬保护）。
- **节名末尾的 ` *`（空格+星号）不是禁用标记**：它只是 Winapp2 社区贡献条目的排版标记，由解析器静默剥离为显示名，**不参与禁用判定**；真正的禁用语义由 `Default=False` 键表达。此前 F-1 误将其当作 `Default=False` 的判定，已在第二轮审计中撤销为 F-3。
- **元数据节跳过**：`[Winapp2]` / `[Version]` 为库自身的元数据节，解析时被精确跳过、不产出任何处置行（避免 `-like 'Winapp2*'` 误伤以 `Winapp2` 开头的应用节）。

## 测试

- `tests/cleanup_candd.tests.ps1`：Pester 3.4.0 黑盒测试（10 用例全绿），覆盖 `winapp2_expand.ps1` 的 `Default` 键语义与 `*` 显示名剥离、F-2 元数据节跳过、RegKey 处理（默认忽略 / `-IncludeReg` 备注）、空文件节过滤、DetectFile 通配符检测，以及 `cleanup_cd.ps1` 的双层硬保护 + DryRun 零删除 + 规划汇总 `Intent` 精确分类计数。
- `tests/run_pester.ps1`：专用运行器，已内置环境块精简逻辑以兼容 Pester 3.4.0 的 `Add-Type` 子进程限制（环境块 ≤ 65535 字节）。

```powershell
# 运行全部测试（需在 PowerShell 5.1 下）
.\tests\run_pester.ps1 .\tests\cleanup_candd.tests.ps1
```

## 快速使用

```powershell
# 1) 现场扫描 D 盘并产出规划报告（仅列出，不删）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode DryRun

# 2) 现场扫描并真正删除"自动清理类"垃圾（需确认类默认保留）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode Execute

# 3) 模拟删除（WhatIf，不实际删，不弹确认）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode Execute -WhatIf

# 4) 读取既有清单 CSV 做清理规划（如 Winapp2 全量候选清单）
.\cleanup_cd.ps1 -CsvPaths .\winapp2_full_expanded.csv -Mode DryRun
```

## 仓库状态

- 远端：`zhangweildlh/Cleanup_CandD_zw`（public）
- 默认分支：`main`
- 最新标签：`v0.3.0`

## 基本操作

```bash
git pull origin main      # 拉取最新
git add <文件>            # 暂存
git commit -m "描述"       # 提交
git push -u origin main   # 推送
```
