---
title: 测试
description: Pester 3.4.0 测试套件（81 用例 / 42 个 Describe 块）的运行方式、A–F/Z 板块覆盖矩阵、内置六项 AST 静态审计、反证复现与变异测试验证方法，以及 PS 5.1 环境陷阱。
related:
  - architecture.md
  - configuration.md
  - winapp2-integration.md
  - upstream-tracking.md
  - ../README.md
updated: 2026-09-02
---

# 测试

本仓库用 **Pester 3.4.0**（PowerShell 5.1 自带版本）做**黑盒测试**：用受控 `.ini` / `.csv` 驱动脚本，
断言其产物（CSV / 标准输出 / 退出码 / 文件系统副作用），**不依赖脚本内部函数导出**，
避免为满足测试而改动业务脚本。

套件同时内置了 `powershell-audit-regression` 技能的**六项 AST 静态审计**（审计脚本随仓库分发在
`tests/tools/Invoke-PSAstAudit.ps1`，不依赖本机技能路径），因此一次运行 = **静态审计 + 动态行为**双轨。

> v0.5.1 曾短暂移除 `tests/`；v0.5.2 起按用户决策**重建并大幅扩充**（45 → 81 用例）。

## 一、运行方式

```powershell
# 必须在 PowerShell 5.1 下；运行器已内置环境块精简以兼容 Pester 3.4.0 的 Add-Type 子进程限制
.\tests\run_pester.ps1                                          # 默认跑 tests/cleanup_candd.tests.ps1
.\tests\run_pester.ps1 .\tests\cleanup_candd.tests.ps1          # 显式指定
```

- 退出码：`0`=全绿；`1`=有失败；`2`=测试文件不存在。
- 运行器 `tests/run_pester.ps1` 先裁剪非必要环境变量，再 `Import-Module Pester -RequiredVersion 3.4.0`，
  规避「环境块超 65535 字节导致 Add-Type 子进程失败」。
- 运行器用 `Invoke-Pester -PassThru` 取回结果对象后按 `FailedCount` 决定退出码——
  **不加 `-PassThru` 时退出码恒为 0**，会出现「Failed: 10 但 exit 0」的失真，CI 会误判为通过。

### 目录结构

| 路径 | 作用 |
|------|------|
| `tests/cleanup_candd.tests.ps1` | 主套件，1436 行 / 81 用例 / 42 个 Describe 块 |
| `tests/run_pester.ps1` | 运行器（环境块精简 + 退出码传递） |
| `tests/tools/Invoke-PSAstAudit.ps1` | 六项 AST 静态审计脚本（字节级复制自 `powershell-audit-regression` 技能） |

## 二、覆盖矩阵（v0.5.2，共 81 用例）

### A) 六项 AST 静态审计集成 + 反证（A1–A8，12 例）

| 审计项 | 检查内容 | 反证方式 |
|--------|---------|---------|
| A1 | 对 `cleanup_cd.ps1` / `winapp2_expand.ps1` 断言六项全 `NONE` + `PARSE_ERRORS=0` + UTF-8 BOM | — |
| A2 | **A 重复函数定义** | 构造含同名函数二次定义的临时 `.ps1` |
| A3 | **B 函数污染**（返回值被赋值消费且体内含 `Write-Output`） | 正向检出 + **负向用例**：函数未被赋值消费、仅用 `Write-Output` 打日志时**不误报** |
| A4 | **C param 名与 `$script:` 同名** | 构造 `param([string]$Config)` + `$script:Config` |
| A5 | **D 函数内写 `$script:` / `$global:`** | 构造函数内赋值外层作用域 |
| A6 | **E `return @(...)` 单元素拆包风险站点** | 构造 `return @($x)` |
| A7 | **F 自动变量遮蔽**（`$matches` / `$input` / `$args` …） | 构造 `function f { param($matches) ... }` |
| A8 | **编码检查**（UTF-8 BOM / 非 ASCII 风险） | 构造无 BOM 含中文的脚本，断言 `RISK` 非 `NONE` |

> 审计只**读**业务脚本、不改脚本，因此可以在 CI 里对任何快照反复跑。

### B) `winapp2_expand.ps1` 全功能/全场景/全边界（B1–B9 + F4，约 32 例）

| 维度 | 覆盖点 |
|------|--------|
| F-3 核心 | `Default` 键语义（保守/AutoDelete）、`*` 显示名剥离、元数据节 `[Winapp2]`/`[Version]` 跳过 |
| 边界/过滤 | 空文件节过滤、有检测无 FileKey 过滤、RegKey 默认忽略 / `-IncludeReg` 备注、DetectFile 通配符、DetectFile 指向不存在文件（门控失败）、SpecialDetect 未知代码（门控失败） |
| 检测门控 | `Detect=HKLM\...` 键存在/不存在（OR 门控）、**裸 `SOFTWARE\...`（缺根键）无法解析 hive → 门控失败** |
| 变量/递归 | `%Temp%` 变量展开为真实目录、RECURSE 递归进子目录、REMOVESELF 产出目录自身、多值 FileKey、多模式 FileKey（`*.tmp;*.log`） |
| ExcludeKey | `FILE\|<folder>\|<pattern>` 直接子项按名排除、`PATH\|<folder>\|<pattern>` 整个子树排除、非 FILE/PATH 类型（如 REG）不误伤 |
| 分类 | LangSecRef 命中映射表 > 显式 `Section=` 键 > `'Other Applications'`（**节名不参与回退**）、`Warning` 键拼接进 Reason |
| 其它 | `-MaxEntries` 限速、注释行（`;`/`#`）跳过、输出 CSV 表头同构 |
| REG-3 回归 | REG 换行分割健壮性 |

### C) `cleanup_cd.ps1` 全功能（C1–C9 + F1–F3，约 30 例）

| 维度 | 覆盖点 |
|------|--------|
| 双层硬保护 | 安全根 / 系统核心降级 / 保留跳过 / DryRun **零删除（含哨兵文件内容与时间戳前后一致）** |
| 标签映射 | Scheme A/B/C/D 全方案、未知标签一律 Keep、多 CSV 合并 |
| 版本控制兜底 | `.git/.svn/.hg` 清单模式**彻底排除**（一行都不写）+ `$skippedVcs` 计数 + 普通项不被误伤 |
| 系统核心 | Delete→Guarded 降级、`-AllowSystemJunk` 命中已知垃圾热点恢复 Delete、非热点仍 Guarded |
| 受保护/安全根 | `.workbuddy` 受保护片段（扫描 + 清单双模式）、`-SafeRoots` 追加安全根提升为二次确认 |
| 现场扫描 | `-Root` 临时目录：`.tmp`/`.log`→Delete、普通 `.txt`→保留跳过、`-MaxDepth 1` 更深层级不入计划 |
| 自动清理目录 | v0.5.0 三类命名规则（等于/包含/以…开头），清空内容保留壳 |
| Execute 模式 | `Execute -WhatIf` 不删不弹确认 exit 0；`Execute` 真实删除且文件消失；**「需确认」项未加 `-DeleteConfirmed` 时默认不删** |
| 编码/边界 | UTF-16 LE CSV 解析、**GBK（无 BOM 含中文）回退解码**、RFC4180（字段含逗号/双引号/换行）、空行与缺列行安全跳过、缺必需列 exit 1、仅表头 exit 1、未给 `-Root`/`-CsvPaths` exit 1 |
| 输出契约 | CSV 表头 `FullPath,SizeMB,Category,Reason,Intent,SafeRoot,SystemGuarded,Action`；**Keep 项不落盘**（决策点即 `continue`） |

### D) v0.5.1 四处修复的回归锁定（D1–D4，7 例）

`Write-DeleteStat` 返回干净 int、`Get-ProgramFilesPaths` 环境变量名与注册表值名各归其位、
`Parse-Winapp2` 换行分割源码级契约、`Resolve-Recursive` 已无 `$matches` 遮蔽。

### E) 反证复现（E1–E3，3 例）

不靠"我觉得不好"，而是**构造修复前的写法实测其错误行为**并输出判词：

| 用例 | 反证内容 |
|------|---------|
| E1 | 旧 `Write-DeleteStat` 用 `Write-Output` 打日志 → 返回 **4 元素数组**，`$ret -gt 0` 在**零失败**时也为真（误触 exit 2） |
| E2 | `ProgramW6432Dir` 作环境变量名取值为空，`ProgramW6432` 才能取到 |
| E3 | `"a\`rb\`nc\`r\`nd" -split "\`r|\`n"` 得 **5 段**（CRLF 被切两次产生空段），`'\r?\n'` 得 3 段 |

### F) 补充场景（F1–F5，18 例）与 Z) 零残留自证（2 例）

- **Z1**：`-Root` 扫描产物落在 `zw_pester_` 前缀路径，不写脚本默认名 `scan_inventory_<盘符>.csv`
  （默认名无前缀、不可按名清理，实测曾留下 336 个残留）；
- **Z2**：跑完后 TEMP 下 `zw_pester*` 残留数为 0（用内置 cmdlet 全限定名
  `Microsoft.PowerShell.Management\Remove-Item` 回收，绕开宿主自定义 `Remove-Item` 包装函数）。

## 三、测试有效性验证：变异测试

套件不只是"曾经绿过"。用变异测试证明它能抓住回归：

```text
BASELINE_MD5 = 71787B9CCC9883ADC1B5C7DC9BECA968        # 备份 cleanup_cd.ps1
注入缺陷：Write-DeleteStat 两处 Write-Host 改回 Write-Output
重跑结果：Passed=72  Failed=7  PESTER_EXIT=1
  → 7 个用例立刻变红，横跨三个层次：A1 静态审计 B 项、D1 回归锁定 ×2、E1 反证对照、F1 Execute 行为 ×3
还原后：MATCH_BASELINE=True；git status 仅 ?? tests/（业务脚本零净改动）
```

判读：**任一层被绕过都会被抓到**——静态层、回归锁定层、行为层互为交叉验证。

## 四、PS 5.1 陷阱（已在测试辅助函数中规避，新增用例时注意）

- **单元素数组被拆包**：函数返回结果用 `Write-Output -NoEnumerate` 保住数组契约；断言 `.Count` 前用 `@()` 包成数组。
- **`Where` 单匹配 `.Count` 为 `$null`**：用 `@(...)` 包裹后再取 `.Count`。
- **`Write-Output` 污染返回值**：被赋值使用的函数日志走 `Write-Verbose` 或交调用方输出。
- **`2>&1` 捕获全流**：需断言警告/错误文案时用 `& script @params 2>&1` 合并流再 `Out-String`。
- **环境块限制**：必须经 `run_pester.ps1` 运行，不可直接 `Invoke-Pester`。
- **含非 ASCII 的 `.ps1` 必须 UTF-8 带 BOM**：PS 5.1 按系统 GBK 读无 BOM 文件会乱码并引发语法解析失败。
- **`$PSScriptRoot` 在 param 块默认值求值时可能为空字符串**：默认值解析要移到脚本体内，否则 `Join-Path` 抛参绑错误。
- **宿主自定义 `Remove-Item`**：本机 `Remove-Item` 被安全删除钩子包装（非 OS 临时路径强制走回收站），
  测试内清理须用全限定名 `Microsoft.PowerShell.Management\Remove-Item`。
- **审计输出 `RISK=` 位于行尾**（与 `ENCODING_UTF8_BOM=` 同行），解析只能按行内 `\bRISK=(\S+)` 捕获，行首正则匹配不到。

## 五、写新用例的契约核对清单

历史教训：本轮 10 处失败**全部源于测试臆想了错误契约**，业务脚本零缺陷。
新增断言前务必先读源码确认以下契约：

1. **Keep 项不落盘**——决策点 `if ($intent -eq 'Keep') { ...; continue }`，计划 CSV 只有 Delete/Confirm/Safe/Guarded 四类。
2. **清单全为 Keep 时脚本 `exit 1`**——所以测"未知标签→Keep"必须加陪跑行，否则被 exit 1 掩盖真实断言。
3. **`.git/.svn/.hg` 是彻底排除**（连一行都不写），不是降级为其他 Intent。
4. **`Detect` 值必须带注册表根键**（`HKLM\` / `HKCU\` …），裸 `SOFTWARE\...` 无法解析 hive。
5. **ExcludeKey 是管道分隔的 `Type\|Folder\|Pattern`**，不是 `FILE:<name>` 冒号格式。
6. **`Resolve-Category` 回退链不含节名**：LangSecRef 映射 → `Section=` 键 → `'Other Applications'`。
