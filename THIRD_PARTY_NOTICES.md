# 第三方组件与许可范围

项目自身 `src/`、`tools/` 和项目文档采用根目录 MIT LICENSE。MIT 不替代以下第三方许可，不为第三方权利提供担保，也不覆盖用户处理的素材或 Spine 商标。

| 组件 | 用途 | 已核实许可 | 归档与状态 |
|---|---|---|---|
| FFmpeg N-102062-g63b2b0f47d | 独立进程解码、抽帧、GIF 等 | 二进制自述 GPL-3.0-or-later，启用 GPL/version3 | `licenses/FFmpeg-GPL-3.0.txt` 与实际构建参数；静态依赖完整对应源码尚缺 |
| PS2EXE 1.0.18 | PowerShell EXE 宿主构建 | 上游 LICENSE 为 Ms-LPL 1.1；脚本头部另标 MS-PL | 两种许可原文均保留，固定提交源码位于 `third_party/ps2exe/`；差异未解决 |
| Windows PowerShell / .NET Framework | 操作系统运行环境 | Microsoft 各自许可 | 本项目不分发系统组件 |

## FFmpeg

版权所有者为 FFmpeg developers 及相关贡献者，依赖库各有自己的版权所有者。完整 `ffmpeg -version`、`ffmpeg -L` 输出保存在 `compliance/`。主代码提交为 `63b2b0f47df420007c53888ce0e8383d24b8fb06`：<https://github.com/FFmpeg/FFmpeg/tree/63b2b0f47df420007c53888ce0e8383d24b8fb06>。官方许可说明：<https://ffmpeg.org/legal.html>。

此主代码提交不能代表整套静态构建的完整 Corresponding Source。所有缺项详见 [许可与来源档案](compliance/README.md)；历史包不能因本次增加 MIT 和 GPL 文本就被称为已完成整改。后续公开打包处于阻止状态。

## PS2EXE

Ingo Karstein、Markus Scholtes 的原版权和源文件头部声明予以保留。归档来自 <https://github.com/MScholtes/PS2EXE/tree/9d6cc14363639ccecf4571842ef6cd4518781ae8>。

`licenses/PS2EXE-Ms-LPL-1.1.txt` 是该提交的原始 LICENSE；保留原 Windows-1252 字节。它含 Windows 平台限制，不可称作本项目 MIT 授权的一部分。`licenses/PS2EXE-Ms-PL.txt` 是用于解释源文件头部声明的标准 MS-PL 文本，不表示覆盖或取代上游 LICENSE。对生成宿主的进一步分发，应结合上游澄清处理这个差异。

## 素材与品牌

用户素材不随仓库分发。本项目不含 Spine 编辑器或 Spine Runtime，也不是 Esoteric Software 的官方产品；使用者应自行确认素材和相关商标权利。
