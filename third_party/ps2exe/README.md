# PS2EXE 1.0.18 构建源码

来源：<https://github.com/MScholtes/PS2EXE/tree/9d6cc14363639ccecf4571842ef6cd4518781ae8/Module>

保存 `ps2exe.ps1`、`ps2exe.psd1`、`ps2exe.psm1` 原始字节，不包含上游 GUI EXE、示例或本机安装元数据。这三个文件用于本项目构建，无需安装系统级模块。

版权所有者与原声明见源文件；包括 Ingo Karstein、Markus Scholtes。它们不受本项目 MIT LICENSE 重新授权。

上游固定提交 LICENSE 为 Microsoft Limited Public License 1.1：见 `../../licenses/PS2EXE-Ms-LPL-1.1.txt`。核心脚本头部另标 Microsoft Public License，见 `../../licenses/PS2EXE-Ms-PL.txt`。保留两种声明，未自行消除差异；Ms-LPL 1.1 包含 Windows 平台限制。

构建时显式加载本目录模块，避免 PATH 中另一个 PS2EXE 版本影响结果。完整文件哈希见 `../../compliance/materials-sha256.json`。
