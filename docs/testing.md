---
title: 测试套件
description: Pester 3.4.0 冒烟测试的运行方式、39 用例的覆盖矩阵（全功能/全场景/全边界），以及 PS 5.1 环境约束。
related:
  - architecture.md
  - configuration.md
  - winapp2-integration.md
  - upstream-tracking.md
  - ../README.md
updated: 2026-09-01
---

# 测试套件

本仓库用 **Pester 3.4.0**（PowerShell 5.1 自带版本）做黑盒冒烟测试：用受控 `.ini` / `.csv` 驱动脚本，断言其产物（CSV / 标准输出），**不依赖脚本内部函数导出**，避免改动业务脚本。

## 一、运行方式

```powershell
# 必须在 PowerShell 5.1 下；专用运行器已内置环境块精简以兼容 Pester 3.4.0 的 Add-Type 子进程限制（环境块 ≤ 65535 字节）
.\tests\run_pester.ps1 .\tests\cleanup_candd.tests.ps1
```

- 退出码：`0`=全绿；`1`=有失败。
- 运行器 `tests/run_pester.ps1` 会裁剪非必要环境变量后再 `Import-Module Pester -RequiredVersion 3.4.0`，规避「环境块超过 65535 字节导致 Add-Type 子进程失败」。

## 二、覆盖矩阵（当前 39 用例）

### A) `winapp2_expand.ps1`

| 维度 | 覆盖点 |
|------|--------|
| F-3 核心 | `Default` 键语义（保守/AutoDelete）、`*` 显示名剥离、元数据节 `[Winapp2]`/`[Version]` 跳过 |
| 边界/过滤 | 空文件节过滤、有检测无 FileKey 过滤、RegKey 默认忽略 / `-IncludeReg` 备注、DetectFile 通配符、DetectFile 指向不存在文件（门控失败）、SpecialDetect 未知代码（门控失败） |
| 检测门控 | `Detect` 注册表键存在/不存在（OR 门控）、DetectFile 通配符判定 |
| 变量/递归 | `%Temp%` 变量展开为真实目录、RECURSE 递归进子目录、REMOVESELF 产出目录自身、多值 FileKey（FileKey1/FileKey2） |
| ExcludeKey | FILE 直接子项按名排除、PATH 整个子树排除 |
| 其它 | LangSecRef=3021 分类映射、MaxEntries=1 限速、注释行（`;`/`#`）跳过、输出 CSV 表头同构 |

### B) `cleanup_cd.ps1`

| 维度 | 覆盖点 |
|------|--------|
| 双层硬保护 | 安全根 / 系统核心降级 / 保留跳过 / DryRun 零删除、规划 CSV 的 `Intent` 列精确分类（Delete/Confirm/Safe/Guarded） |
| 标签映射 | Scheme C（是/否/谨慎）、未知标签一律 Keep、多 CSV 合并 |
| 版本控制兜底 | `.git/.svn/.hg` 清单模式强制排除 + `$skippedVcs` 计数 |
| 系统核心 | Delete→Guarded 降级、`-AllowSystemJunk` 命中已知垃圾热点恢复 Delete、非热点仍 Guarded |
| 受保护/安全根 | `.workbuddy` 经 `-Root` 扫描命中即保留、`-SafeRoots` 追加安全根提升为二次确认 |
| 现场扫描 | `-Root` 扫描临时目录：`.tmp`/`.log`→Delete、普通 `.txt`→保留跳过 |
| 编码/边界 | UTF-16 LE 编码 CSV 解析、缺必需列 CSV 跳过且 exit 1、仅表头无数据 exit 1、未提供 `-Root`/`-CsvPaths` exit 1 |

## 三、PS 5.1 陷阱（已在测试辅助函数中规避，新增用例时注意）

- **单元素数组被拆包**：函数返回结果用 `Write-Output -NoEnumerate` 保住数组契约；断言 `.Count` 前用 `@()` 包成数组。
- **`Where` 单匹配 `.Count` 为 `$null`**：用 `@(...)` 包裹后再取 `.Count`。
- **`Write-Output` 污染返回值**：被赋值使用的函数（扩展器/清理脚本）日志走 `Write-Verbose` 或交调用方输出，不在函数体内 `Write-Output` 打日志。
- **`2>&1` 捕获全流**：需断言警告/错误文案时，调用用 `& script @params 2>&1` 合并流后再 `Out-String`。
- **环境块限制**：必须经 `run_pester.ps1` 运行，不可直接 `Invoke-Pester`（会因 Add-Type 子进程环境块超限失败）。
