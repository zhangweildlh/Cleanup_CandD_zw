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

- `cleanup_cd.ps1`：C+D 盘垃圾文件清理规划/执行脚本（默认 DryRun、零副作用；含安全根拦截与系统核心目录保护双层硬保护）。消费下方清单 CSV 并规划处置。
- `full_inventory2.csv`：C 盘完整文件清单（字段 `FullPath,Extension,SizeMB,LastWriteTime,Category,Cleanable,Reason`）。
- `full_inventory3.csv`：D 盘完整文件清单，字段同上。

> 说明：两个清单 CSV 含本机文件目录结构信息，仓库当前为 public，请按需评估是否公开。

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
