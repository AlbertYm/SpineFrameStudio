# 2026.9.15 许可与来源档案

核查日期：2026-09-21。项目自身源码和文档采用根目录 MIT LICENSE；第三方文件保留原许可。本目录是可核验的材料索引，不是所有第三方义务已经满足的证明。

## 已核实材料

- 原始便携 ZIP：`SpineFrameStudio_2026.9.15.zip`，44,279,353 字节，SHA-256 `733906FC864FB71FD7BEB333CBD9EB31D108348119945BEA5B2AA65FBEEEC650`。
- FFmpeg 二进制：SHA-256 `C645BC5CC56BE1FDB46A84B72C292B6EE80008E81C6791AB7B2CBDF23F67C9C6`；实际 `-version` 与 `-L` 输出见同目录文本。
- FFmpeg 主代码 commit：`63b2b0f47df420007c53888ce0e8383d24b8fb06`，GitHub API 确认提交日期为 2021-04-26。此 commit 由二进制内版本字符串推导，不证明没有额外补丁。
- FFmpeg GPLv3 原文取自该固定提交的 `COPYING.GPLv3`，保存在 `licenses/FFmpeg-GPL-3.0.txt`。二进制自述为 GPL 第 3 版或更新版本。
- PS2EXE 当前本机模块为 1.0.18；`third_party/ps2exe/` 保存上游 commit `9d6cc14363639ccecf4571842ef6cd4518781ae8` 的三个构建源文件。核心脚本 SHA-256 `94613E703FA2EC67A01255E5917A056A9406FD31C557685B7AE76417F706A09A` 与本机模块逐字节一致。未据此声称历史 EXE 的编译环境已经完全重现。
- PS2EXE 上游 LICENSE 原文为 Microsoft Limited Public License 1.1，含平台限制；脚本头部却标注 Microsoft Public License。两种文本分别归档，不擅自判定较宽松文本优先。Ms-LPL 原始文件为 Windows-1252 编码，保留原字节；如编辑器显示引号乱码，请按该编码打开。

## 源码快照附件

已下载并校验 FFmpeg 主代码归档，包含 7602 个 tar 条目，内含 COPYING.GPLv3 与归档的许可文本一致。文件名、固定提交、来源、大小与 SHA-256 见 `source-origins.json`；快照放入 Release 的独立材料包，避免大文件进入 Git 历史。此快照明确不包含所有静态依赖的对应源码。

## FFmpeg 尚缺的材料

旧 FFmpeg 静态构建含 x264、x265、xvid、libass、freetype、gnutls 等大量组件。`ffmpeg-version.txt` 是实际启用参数清单，不是完整 SBOM；未列出每个组件的版本、许可证和传递依赖。

尚缺：实际构建仓库/运行编号、全部依赖的确切源码版本、补丁、构建脚本和工具链说明、对应许可/版权声明，以及能够与二进制对应的完整源码交付。`rdp/ffmpeg-windows-build-helpers` 和与路径同名的构建项目只能作为追溯线索，不能当作已经证实的构建来源。

即使取得上述 FFmpeg 主代码快照，也不能将其称为这个静态二进制的完整 Corresponding Source。不能通过新增 MIT、单独附 GPL 文本或增加免责声明消除这些缺项。

## 后续公开二进制发布条件

当前 `dependency-manifest.json` 的 `redistributionReady` 为 false。`tools/build.ps1 -ForPublicRelease` 会拒绝打包；普通本地构建允许调试，不代表可以上传该输出。

要解除阻止，必须选择下面一种已完成的方案，并更新档案与清单：

1. 找回历史 FFmpeg 的完整对应源码和所有许可材料，核对确切二进制及构建关系；或
2. 替换为来源和完整对应源码可核验的 FFmpeg 构建，执行真实视频、GIF、透明 PNG、缩放、预览 GIF 和错误恢复回归，以新发布号交付；或
3. 发布不含 FFmpeg 的程序包，明确要求用户独立获取并放入依赖；这会改变开箱即用体验，需在下载入口与说明中清楚标注。

PS2EXE 的两种许可表述也需在重新分发其源码/生成宿主时保留并说明，不能声称整个二进制包只受 MIT 约束。

本次不删除或覆盖历史发布包。旧 Release 的公开分发问题仍需按上述方案处理；本档案本身不代表旧发布包已完成合规整改。
