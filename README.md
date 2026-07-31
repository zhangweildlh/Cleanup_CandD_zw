# Cleanup_CandD_zw

本地清理与暂存工作区（Cleanup & staging workspace）。

## 用途

本仓库用于在本机 `D:\Documents\AI_Work_Temp\Cleanup_CandD_zw` 目录下，
集中管理临时清理、归档与暂存类的文件与脚本，便于在本地与 GitHub 远端之间同步与回溯。

## 目录约定

- 仓库根目录即本地工作区根目录。
- `.workbuddy/` 与 `.mimocode/` 为智能体工作数据目录，已被 `.gitignore` 忽略，不会纳入版本控制。
- 具体清理任务产生的产物、脚本、清单等，按任务在根目录下自行建立子目录存放。

## 仓库状态

- 远端：`zhangweildlh/Cleanup_CandD_zw`（public）
- 默认分支：`main`

## 基本操作

```bash
git pull origin main      # 拉取最新
git add <文件>            # 暂存
git commit -m "描述"       # 提交
git push -u origin main   # 推送
```
