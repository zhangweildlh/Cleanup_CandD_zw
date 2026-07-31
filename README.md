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
  - `-Root <目录>`：现场递归扫描并即时分类，生成与 `full_inventory2/3.csv` 同构的清单 CSV，随后直接规划处置；
  - `-CsvPaths <清单...>`：直接读取既有处置清单（兼容原 scan2/scan3 产物）。
  - 经「标签→处置映射层」规划三类处置（自动清理 / 需确认 / 保留），含安全根拦截与系统核心目录保护双层硬保护。`-Mode Execute` 才真正删除（底层 .NET API，绕开本机 safe-delete 对 `Remove-Item` 的 hook）；`-WhatIf` 可模拟。
  - 分类规则：方案 C（默认用于 C:，Cleanable∈{是,否,谨慎}）/ 方案 D（默认用于其它盘，Cleanable∈{自动清理,需确认,保留}），由路径片段 / 扩展名 / 文件大小 / 修改时间判定。
- `full_inventory2.csv`：C 盘完整文件清单（字段 `FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason`）。
- `full_inventory3.csv`：D 盘完整文件清单，字段同上。
- （`scan_inventory.ps1` 的扫描能力已并入本脚本，原独立扫描脚本已移除。）

> 说明：两个清单 CSV 含本机文件目录结构信息，仓库当前为 public，请按需评估是否公开。

## 快速使用

```powershell
# 1) 现场扫描 D 盘并产出规划报告（仅列出，不删）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode DryRun

# 2) 现场扫描并真正删除"自动清理类"垃圾（需确认类默认保留）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode Execute

# 3) 模拟删除（WhatIf，不实际删，不弹确认）
.\cleanup_cd.ps1 -Root D:\ -Scheme D -Mode Execute -WhatIf

# 4) 读取既有清单 CSV 做清理规划
.\cleanup_cd.ps1 -CsvPaths .\full_inventory3.csv -Mode DryRun
```

## 仓库状态

- 远端：`zhangweildlh/Cleanup_CandD_zw`（public）
- 默认分支：`main`
- 最新标签：`v0.1.0`

## 基本操作

```bash
git pull origin main      # 拉取最新
git add <文件>            # 暂存
git commit -m "描述"       # 提交
git push -u origin main   # 推送
```
