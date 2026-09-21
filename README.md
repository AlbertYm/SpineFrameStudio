# Spine Frame Studio

Windows 本地视频 / GIF 抽帧素材工作台，当前发布版本 **2026.9.15**。支持按张数或 FPS 抽帧、纯色背景抠图、透明 PNG、画布缩放、Spine 前缀命名、预览 GIF 与描边。

## 下载与启动

1. 打开 [2026.9.15 发布页](https://github.com/AlbertYm/SpineFrameStudio/releases/tag/v2026.9.15)，下载 `SpineFrameStudio_2026.9.15.zip`。
2. 完整解压到可写文件夹，不要在 ZIP 内直接运行。
3. 双击 `SpineFrameStudio_2026.9.15.exe`。全部同目录文件必须保留；不能只复制 EXE。
4. 添加视频 / GIF，选择抽帧模式与输出目录，点击“开始导出”。第一次建议用短素材导出 4 张，检查透明度及尺寸。

**GitHub 的 Source code ZIP 是源码，不是开箱即用便携包。** 详细操作见 [使用说明](docs/使用说明.md)，协作见 [上传与修改规则](CONTRIBUTING.md)。

## 运行要求

- Windows x64；Windows PowerShell 5.1 与 .NET Framework（Windows 自带组件）。
- 便携包包含 FFmpeg；不需要 Python、Node、.NET SDK、管理员权限、网络或 AI 服务。
- EXE 未签名。企业应用控制或 SmartScreen 可能阻止运行，应核实来源后按本机管理要求处理。
- 另一台电脑、125% / 150% DPI 与跨屏缩放仍需目标机人工验收。

## 快速使用

- “抽帧”：按张数均匀采样，或按 FPS 抽帧；FPS 留空保留原帧率。尺寸留空保留原尺寸，填写 `256x256` 等比缩放并透明补边。
- “更新预览”：只显示第一帧；修改参数后必须重新更新。
- “透明与边缘”：纯色抠图、背景取色、柔边、去色溢等；这不是 AI 分割。
- “导出与工具”：命名前缀、预览 GIF、描边、图片文件夹画布缩放。
- 批量停止会等待当前文件完成；失败时查看展开的日志。原始素材不覆盖，结果写入独立目录。

## 从源码运行

`src/` 是 2026.9.15 发布包中对应源码，版本依据为 `src/version.json`。从可信的 FFmpeg 发布渠道取得适用 Windows x64 的 `ffmpeg.exe`，放到 `src/`，或使用上述完整发布包内相同文件。然后双击 `src/打开抽帧工具.bat`。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\extract_frames.ps1 -Gui
```

需要生成 EXE 时，开发机安装 PS2EXE 后运行 `tools/build.ps1`；脚本在独立 `dist/` 中构建，不覆盖历史发布。构建前需要 `src/ffmpeg.exe`。公开发布前还需完成 CONTRIBUTING 中的验收，不应仅凭编译成功发布。

## 验证与限制

9 月 15 日历史验收记录：完整 ZIP 解压哈希、EXE 主窗口启动、33 项 GUI 检查、视频 / GIF 各 4 张 PNG、128×128 画布、预览 GIF、停止和失败恢复、174 字符中文空格路径通过。这些是当日开发机记录，本次公开上传未重跑完整 GUI 矩阵。

本次上传会核对原 ZIP 与载荷哈希，不修改程序。已知限制：首帧预览、纯色抠图、设置不跨启动保存、停止在文件边界生效、部分提示优先中文。系统临时目录会保存 `SpineWorkbench_*` 诊断文件。

更新时解压到新目录，保留旧版与素材；回退直接运行保留的旧目录。退出程序后可删除程序目录完成卸载，删除前确认没有将自己的输出保存其中。

## 仓库与授权

本仓库公开可见，但当前未为项目自身代码指定开源许可证。公开可见不等于授予任意再分发或商业使用许可；如需使用授权请通过 Issue 联系维护者。第三方组件遵循各自许可证，见 [第三方说明](THIRD_PARTY_NOTICES.md)。本项目不是 Esoteric Software 的官方产品。
