# 磁盘垃圾文件扫描 + 清理规划报告

> 生成时间: 2026-08-01 11:30:59
> 运行模式: **DryRun**（仅输出，未删除任何文件）

## 一、数据来源
- D:\System\UserTemp\winapp2_real_files.csv

## 二、安全根目录（删前需二次确认，硬编码兜底）

凡拟删除项落于以下目录，一律按目录批量二次确认，绝不自动删除（含硬编码兜底根，不可被参数移除）：

- D:\Documents
- D:\Tools
- D:\ZW工作

## 三、系统核心保护目录（命中即强制降为待确认）

凡拟删除项落于以下系统目录，一律强制降为"待确认"，绝不自动删除，保证 Win11 系统与已装程序零破坏：

- C:\Windows
- C:\Program Files
- C:\Program Files (x86)
- C:\ProgramData

## 四、处置统计

| 处置类别 | 文件数 | 总体积(MB) | 说明 |
| --- | --- | --- | --- |
| 确定拟删除（自动清理，非安全根、非系统核心） | 0 |  | 默认删除（DryRun 仅列出） |
| 待确认（需确认，非安全根） | 30312 | 1,256.28 | 默认不删，需用户决定 |
| 安全根二次确认 | 0 |  | 按目录批量确认后删除 |
| 系统核心降级待确认 | 0 |  | 命中系统核心目录，强制待确认，不自动删 |

## 五、确定拟删除清单（自动清理，非安全根、非系统核心）

> 以下文件经标签映射为"自动清理"，且不在任一安全根、也不在系统核心目录下，默认删除。

_无_

## 六、待确认清单（需确认，非安全根）

> 共 30312 个文件 / 1,256.28 MB，默认不删除。
> 以下按所在目录聚合展示；如需逐文件绝对路径，请运行脚本时加 `-FullList`，或查阅同目录完整清单 CSV。

| 所在目录 | 文件数 | 总体积(MB) | 主要分类 |
| --- | --- | --- | --- |
| C:\Windows\System32\config\systemprofile\AppData\Local | 2882 | 0.00 | Windows |
| C:\ProgramData\Intel\GCC | 1107 | 0.60 | Utilities |
| C:\Windows\System32\config\systemprofile\AppData\Local\Intel\GCC | 460 | 0.06 | Utilities |
| C:\ProgramData\USOShared\Logs\System | 448 | 12.35 | Windows |
| C:\Windows\System32\winevt\logs | 385 | 149.88 | Windows |
| D:\System\UserTemp | 345 | 101.27 | Windows |
| C:\Windows\System32\SleepStudy | 329 | 12.55 | Windows |
| C:\Users\Administrator\AppData\LocalLow\Intel\ShaderCache | 278 | 29.31 | Utilities |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\img\flags-of-the-world | 255 | 0.12 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\v4\locales | 213 | 0.58 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\v4\locales | 213 | 0.58 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\v4\locales | 213 | 0.58 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500 | 202 | 151.21 | Windows |
| C:\Program Files\Microsoft Update Health Tools\Logs | 200 | 24.63 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\v4\locales | 171 | 0.58 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RRZSSW5 | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$R9H6E18\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$R4B6BES\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RZZEXPF | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$R205Z5D | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RAA4EVI\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RYCRTNF\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RVD92XV | 167 | 4.40 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$R11YKNQ\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RPTGAE0 | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RPBWOIX | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RPJYI90 | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$R6YBIBO\dist\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RYLFPF2\ci-30680360202\dist\assets | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RDFIRZK | 167 | 4.40 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RLYLLX5 | 167 | 4.41 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RPR3SH3 | 167 | 4.40 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\v4\locales | 160 | 0.44 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\v4\locales | 160 | 0.44 | Windows |
| C:\Windows\System32\SleepStudy\ScreenOn | 124 | 31.31 | Windows |
| D:\System | 115 | 0.00 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\js | 86 | 1.73 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v4\classic\tests | 79 | 0.72 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v4\classic\tests | 79 | 0.72 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v4\classic\tests | 79 | 0.72 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\v4\core | 69 | 0.73 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\v4\core | 69 | 0.73 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\v4\core | 69 | 0.73 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\v4\core | 64 | 0.60 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\v4\core | 64 | 0.60 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\src\v4\classic\tests | 64 | 0.48 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\src\v4\classic\tests | 64 | 0.48 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v3\tests | 61 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\src\v3\tests | 61 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v3\tests | 61 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v3\tests | 61 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\src\v3\tests | 61 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\server | 60 | 0.25 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\server | 60 | 0.26 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\server | 60 | 0.26 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\server | 60 | 0.25 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\server | 60 | 0.25 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\server | 60 | 0.26 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\server | 60 | 0.25 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\server | 60 | 0.26 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\v4\core | 57 | 0.64 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\vocabularies\applicator | 54 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\vocabularies\applicator | 54 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\vocabularies\applicator | 54 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\vocabularies\applicator | 54 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v4\locales | 53 | 0.24 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v4\locales | 53 | 0.24 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\vitest\dist\chunks | 53 | 1.67 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v4\locales | 53 | 0.24 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\postcss\lib | 52 | 0.20 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\web_accessible_resources | 50 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500 | 45 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\undici\types | 45 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@hono\node-server\dist | 44 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@hono\node-server\dist | 44 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@hono\node-server\dist | 44 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@hono\node-server\dist | 44 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\v4\classic | 41 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\v4\classic | 41 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\v4\classic | 41 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\server | 40 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\server | 40 | 0.28 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\server | 40 | 0.27 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RA84XI7 | 40 | 1.00 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\server | 40 | 0.28 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\server | 40 | 0.28 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\server | 40 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\pipenet\dist\server | 40 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\src\v4\locales | 40 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\server | 40 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\src\v4\locales | 40 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\examples\client | 40 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\server | 40 | 0.28 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\vocabularies\validation | 39 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\vocabularies\validation | 39 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\vocabularies\jtd | 39 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\vocabularies\jtd | 39 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\vocabularies\jtd | 39 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\vocabularies\jtd | 39 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\vocabularies\validation | 39 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\vocabularies\validation | 39 | 0.04 | Windows |
| C:\Users\Administrator\AppData\Local\..\LocalLow\Microsoft\CryptnetUrlCache\Content | 38 | 0.14 | Windows |
| C:\Users\Administrator\AppData\LocalLow\Microsoft\CryptnetUrlCache\Content | 38 | 0.14 | Windows |
| C:\Users\Administrator\AppData\LocalLow\Microsoft\CryptnetUrlCache\MetaData | 38 | 0.02 | Windows |
| C:\Users\Administrator\AppData\Local\..\LocalLow\Microsoft\CryptnetUrlCache\MetaData | 38 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\v4\classic | 36 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\v4\classic | 36 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\shared | 36 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\undici\docs\docs\api | 36 | 0.22 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\v4\classic | 35 | 0.24 | Windows |
| C:\Users\Administrator\AppData\Local\Microsoft\Edge\User Data | 35 | 0.00 | Microsoft Edge |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\axios\lib\helpers | 34 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\glob\dist\esm | 33 | 0.22 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\client | 32 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\client | 32 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\client | 32 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\client | 32 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\client | 32 | 0.29 | Windows |
| C:\Users\Administrator\AppData\Local\Google\Chrome\User Data | 32 | 0.00 | Google Chrome |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\client | 32 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\client | 32 | 0.29 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\client | 32 | 0.29 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\js\resources | 31 | 0.28 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\vitest\dist | 31 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod-to-json-schema\dist\esm\parsers | 30 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\math-intrinsics | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\math-intrinsics | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod-to-json-schema\dist\types\parsers | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod-to-json-schema\dist\esm\parsers | 30 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\math-intrinsics | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod-to-json-schema\dist\cjs\parsers | 30 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod-to-json-schema\dist\esm\parsers | 30 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\math-intrinsics | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod-to-json-schema\dist\types\parsers | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod-to-json-schema\dist\cjs\parsers | 30 | 0.04 | Windows |
| C:\Users\Administrator\AppData\Roaming\360se6\User Data | 30 | 0.00 | .360 Secure Browser Web Browser |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod-to-json-schema\dist\cjs\parsers | 30 | 0.04 | Windows |
| C:\Users\Administrator\AppData\Local\Microsoft\Windows\Explorer | 30 | 36.33 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod-to-json-schema\dist\types\parsers | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod-to-json-schema\dist\types\parsers | 30 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod-to-json-schema\dist\cjs\parsers | 30 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod-to-json-schema\dist\esm\parsers | 30 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\v4\mini | 29 | 0.15 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\v4\mini | 29 | 0.15 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\v4\mini | 29 | 0.15 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\glob\dist\commonjs | 29 | 0.19 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\v4\mini | 28 | 0.12 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\yargs\locales | 28 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\@vitest\mocker\dist | 28 | 0.18 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\v4\mini | 28 | 0.12 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\experimental\tasks | 28 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\rolldown\dist | 27 | 0.21 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\yargs\locales | 27 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\@vitest\utils\dist | 26 | 0.16 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\src\v4\classic\tests | 26 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\minimatch\dist\esm | 25 | 0.24 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\glob\node_modules\minimatch\dist\commonjs | 25 | 0.22 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\glob\node_modules\minimatch\dist\esm | 25 | 0.22 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\v3 | 25 | 0.39 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\minimatch\dist\commonjs | 25 | 0.25 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\v3 | 25 | 0.39 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\v3 | 25 | 0.39 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\v3\helpers | 24 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\runtime | 24 | 0.02 | Windows |
| C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs | 24 | 0.75 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\node_modules\jose\dist\webapi\lib | 24 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\diff\libcjs\diff | 24 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\runtime | 24 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\v3 | 24 | 0.39 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\v3\helpers | 24 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\jose\dist\webapi\lib | 24 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\pipenet\dist | 24 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\v4\mini | 24 | 0.12 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\css | 24 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\v3\helpers | 24 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\jose\dist\webapi\lib | 24 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\v3 | 24 | 0.39 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\runtime | 24 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\runtime | 24 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\v3\helpers | 24 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\jose\dist\webapi\lib | 24 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\v3\helpers | 24 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\diff\libesm\diff | 24 | 0.06 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN | 23 | 0.12 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\vitest | 23 | 0.05 | Windows |
| C:\Users\Administrator\AppData\Local\Microsoft\Edge | 23 | 0.00 | Microsoft Edge |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\rolldown\dist\shared | 22 | 0.56 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\utils | 21 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\compile\validate | 21 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\types\utils | 21 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\cjs\utils | 21 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\compile\validate | 21 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\compile | 21 | 0.07 | Windows |
| C:\Users\Administrator\AppData\Roaming\360se6 | 21 | 0.00 | .360 Secure Browser Web Browser |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\types\utils | 21 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\utils | 21 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\types\utils | 21 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\cjs\utils | 21 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\cjs\utils | 21 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\compile\validate | 21 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\utils | 21 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\compile | 21 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\compile\validate | 21 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\cjs\utils | 21 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\compile | 21 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\compile | 21 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\types\utils | 21 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\utils | 21 | 0.04 | Windows |
| C:\Users\Administrator\AppData\Local\Google\Chrome | 21 | 0.00 | Google Chrome |
| C:\Users\Administrator\AppData\Roaming\Opera Software | 21 | 0.00 | Opera |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\es-errors | 20 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\v3 | 20 | 0.33 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\es-errors | 20 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\es-errors | 20 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\es-errors | 20 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\handlers | 20 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\v3\helpers | 19 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v4\core | 19 | 0.36 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\call-bind-apply-helpers | 19 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\call-bind-apply-helpers | 19 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\call-bind-apply-helpers | 19 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\src\v3\tests | 19 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v4\core | 19 | 0.36 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v4\core | 19 | 0.36 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\call-bind-apply-helpers | 19 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\object-inspect\test | 18 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\vocabularies | 18 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\object-inspect\test | 18 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\vocabularies | 18 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\vocabularies | 18 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\vocabularies | 18 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\lib\vocabularies\applicator | 18 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\src\v4\core | 18 | 0.30 | Windows |
| C:\Users\Administrator\AppData\Local\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\AC\BackgroundTransferApi | 18 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\lib\vocabularies\applicator | 18 | 0.03 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$R1VZW9P | 18 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\object-inspect\test | 18 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\lib\vocabularies\applicator | 18 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\src\v4\core | 18 | 0.30 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\object-inspect\test | 18 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\strtok3\lib\stream | 18 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\lib\vocabularies\applicator | 18 | 0.03 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\js\scriptlets | 17 | 0.12 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\foreground-child\dist\esm | 17 | 0.03 | Windows |
| C:\Windows\Logs\MeasuredBoot | 17 | 1.10 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\foreground-child\dist\commonjs | 17 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\9833c18b2d85bc59\node_modules\playwright-core\bin | 17 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\fuse.js\dist | 17 | 0.37 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\@jridgewell\sourcemap-codec\types | 16 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\fastmcp\dist | 16 | 0.97 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\strtok3\lib | 16 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\validation | 16 | 0.02 | Windows |
| C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations | 16 | 0.05 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RQQYXSN\img | 16 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\undici\lib\dispatcher | 16 | 0.14 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\validation | 16 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\vocabularies\dynamic | 15 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ip-address\dist | 15 | 0.20 | Windows |
| C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations | 15 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\vocabularies\dynamic | 15 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\.bin | 15 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\vocabularies\dynamic | 15 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v4\mini\tests | 15 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\mcp-proxy\src | 15 | 0.15 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\9833c18b2d85bc59\node_modules\playwright-core\lib\vite\traceViewer | 15 | 0.39 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\diff\libesm\patch | 15 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist | 15 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\vocabularies\dynamic | 15 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist | 15 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\diff\libcjs\patch | 15 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v4\mini\tests | 15 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ip-address\dist | 15 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist | 15 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist | 15 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ip-address\dist | 15 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ip-address\dist | 15 | 0.20 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v4\mini\tests | 15 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\execa\lib\ipc | 14 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\es-object-atoms | 14 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\9833c18b2d85bc59\node_modules\playwright | 14 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\es-object-atoms | 14 | 0.01 | Windows |
| C:\Users\Administrator\AppData\Local\cache\qtshadercache-x86_64-little_endian-llp64 | 14 | 0.16 | Applications |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\es-object-atoms | 14 | 0.01 | Windows |
| C:\Windows\System32\LogFiles\WMI | 14 | 196.96 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\es-object-atoms | 14 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\signal-exit\dist\cjs | 13 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\signal-exit\dist\mjs | 13 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\lib\vocabularies\validation | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\lib\vocabularies\validation | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\lib\vocabularies\validation | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\src\__tests__\unit\v2 | 13 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm | 13 | 0.59 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm | 13 | 0.59 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs | 13 | 0.60 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs | 13 | 0.60 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\lib\vocabularies\jtd | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\lib\vocabularies\validation | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\get-proto | 13 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\get-proto | 13 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\lib\vocabularies\jtd | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs | 13 | 0.60 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\get-proto | 13 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs | 13 | 0.60 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\lib\vocabularies\jtd | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\lib\vocabularies\jtd | 13 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\signal-exit\dist\mjs | 13 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm | 13 | 0.59 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\get-proto | 13 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\signal-exit\dist\cjs | 13 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\source-map-js\lib | 13 | 0.10 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm | 13 | 0.59 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\middleware | 12 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\jsx | 12 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\cjs\jsx | 12 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\types\jsx | 12 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\middleware | 12 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\node_modules\zod\src\v4\mini\tests | 12 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\eventsource-parser\dist | 12 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\types\jsx | 12 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\middleware | 12 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\middleware | 12 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\types\jsx | 12 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\jsx | 12 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\middleware | 12 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\eventsource-parser\dist | 12 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\@modelcontextprotocol\sdk\dist\cjs\server\auth\middleware | 12 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\types\jsx | 12 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\middleware | 12 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\cjs\jsx | 12 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\node_modules\zod\src\v4\mini\tests | 12 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\eventsource-parser\dist | 12 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\@modelcontextprotocol\sdk\dist\esm\server\auth\middleware | 12 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\cjs\jsx | 12 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\undici\lib\web\fetch | 12 | 0.27 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\jsx | 12 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\undici\lib\mock | 12 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\eventsource-parser\dist | 12 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\cjs\jsx | 12 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\diff\libcjs\util | 12 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\jsx | 12 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\diff\libesm\util | 12 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\cf8a3eed63dd3749\node_modules\@alibaba-group\open-code-review\imgs | 11 | 1.96 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\has-symbols | 11 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v4\core\tests\locales | 11 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\has-symbols | 11 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\side-channel-list | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\dunder-proto | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\has-tostringtag | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\tslib | 11 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod\src\v4\locales | 11 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\side-channel-list | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\has-symbols | 11 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\side-channel-list | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\has-symbols | 11 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v4\core\tests\locales | 11 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\fast-uri\test | 11 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\fast-uri\test | 11 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\side-channel-list | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\dunder-proto | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v4\core\tests\locales | 11 | 0.05 | Windows |
| C:\Windows\System32\sru | 11 | 9.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\fast-uri\test | 11 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\dunder-proto | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\fast-uri\test | 11 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\dunder-proto | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\lightningcss\node | 11 | 0.47 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\asynckit\lib | 11 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\@mendable\firecrawl-js\src\v2\methods | 11 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\iconv-lite\encodings | 10 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\side-channel-map | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\nanoid | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\types | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\undici\lib\core | 10 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\cjs\jsx\dom | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\types | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\jsx\dom | 10 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\side-channel-weakmap | 10 | 0.01 | Windows |
| D:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RXTCQ5R.dompurify-bIaRYsTx\dist | 10 | 0.74 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\gopd | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\yargs\build\lib | 10 | 0.15 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\jsx\dom | 10 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\cjs\jsx\dom | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\pipenet\src\server | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\side-channel-map | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\9833c18b2d85bc59\node_modules\playwright-core\lib\tools\cli-client\skill\references | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\iconv-lite\encodings | 10 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\expect-type\dist | 10 | 0.08 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\types\jsx\dom | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\gopd | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\tldjs\lib | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\axios\lib\core | 10 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod\src\v4\classic | 10 | 0.13 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\yargs\build\lib | 10 | 0.14 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\side-channel | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod-to-json-schema\dist\cjs | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\object-inspect | 10 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\execa\lib\verbose | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\9833c18b2d85bc59\node_modules\playwright-core | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\gopd | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\9833c18b2d85bc59\node_modules\playwright\lib\agents | 10 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\iconv-lite\encodings | 10 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod\src\v4\classic | 10 | 0.13 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\cjs\jsx\dom | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\jsx\dom | 10 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\types | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\gopd | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\object-inspect | 10 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\cjs\jsx\dom | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod-to-json-schema\dist\cjs | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod\src\v4\classic | 10 | 0.13 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\types | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\jsx\dom | 10 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\cjs | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\zod-to-json-schema\dist\esm | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\object-inspect | 10 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\cjs | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\side-channel | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod-to-json-schema\dist\cjs | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\side-channel-map | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\side-channel | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\hono\dist\types\jsx\dom | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist\types\jsx\dom | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\side-channel-weakmap | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\iconv-lite\encodings | 10 | 0.09 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist\cjs | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\object-inspect | 10 | 0.06 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\tldjs | 10 | 0.80 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\side-channel-map | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod-to-json-schema\dist\esm | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\zod-to-json-schema\dist\esm | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\types\jsx\dom | 10 | 0.02 | Windows |
| C:\ProgramData\Intel\GFXInstaller | 10 | 4.05 | Utilities |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\hono\dist\cjs | 10 | 0.04 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\get-stream\source | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\side-channel-weakmap | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\side-channel-weakmap | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\side-channel | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\zod-to-json-schema\dist\esm | 10 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\hono\dist | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod-to-json-schema\dist\cjs | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\hono\dist | 10 | 0.11 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\22a37d7f6d01a684\node_modules\pathe\dist | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\execa\lib\methods | 10 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\es-define-property | 9 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\emoji-regex | 9 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv-formats\dist | 9 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\es-define-property | 9 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\call-bound | 9 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\call-bound | 9 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ip-address\dist\v6 | 9 | 0.02 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\compile\jtd | 9 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\15b07286cbcc3329\node_modules\ajv\dist\vocabularies\core | 9 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\zod-to-json-schema\dist\types | 9 | 0.01 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\ajv\dist\compile\jtd | 9 | 0.05 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\de2bd410102f5eda\node_modules\ajv\dist\compile\codegen | 9 | 0.07 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\12b05d58670d8359\node_modules\firecrawl\src\v2\methods | 9 | 0.03 | Windows |
| C:\$Recycle.Bin\S-1-5-21-3741613311-3992306682-4178824845-500\$RHOWZ5V\a3241bba59c344f5\node_modules\ajv\dist\vocabularies\core | 9 | 0.01 | Windows |

> 注：仅展示文件数前 500 的目录；完整 30312 项见同目录清单 CSV。

## 七、安全根目录待二次确认清单

> 以下拟删除项落在安全根目录下，执行删除前将按目录批量请求确认。DryRun 模式下仅列出。

_无（安全根目录下当前无拟删除项，已验证未误伤）_
## 八、系统核心目录强制待确认清单

> 以下拟删除项命中系统核心保护目录（C:\Windows / Program Files / ProgramData 等），已被强制降为"待确认"，绝不自动删除。如需清理，需显式 `-DeleteConfirmed` 并在交互中确认。

_无（系统核心目录下当前无拟删除项，已验证未误伤）_

## 九、安全声明

- 本脚本 DryRun 模式**不删除任何文件**，仅生成规划报告。
- 所有删除决策来源于清单（现场扫描或既有 CSV）的 `Cleanable` 字段，经"标签→处置映射层"统一处理（兼容 scan2 描述性标签与 scan3 三值标签），未硬编码任何具体文件。
- 安全根目录（D:\ZW工作、D:\Tools、D:\Documents 等，含硬编码兜底）下的任何拟删除项均被拦截为二次确认，避免误删用户工作/工具/文档。
- 系统核心目录（C:\Windows、C:\Program Files、C:\ProgramData 等）下的拟删除项被强制降为待确认，保证 Win11 系统与已装程序零破坏。
- 删除操作使用底层 .NET API（`[System.IO.File]::Delete` / `[System.IO.Directory]::Delete($path, $true)`）以绝对字面路径删除，对含 `[]{}` `$` 等特殊字符的路径安全；目录型路径递归删除，且按目录二次确认；Execute 模式可用 `-WhatIf` 模拟试运行。
