# Spine Frame Studio

Windows 本地视频 / GIF 抽帧素材工作台，当前源码版本 **2026.9.22**。支持按张数或 FPS 抽帧、纯色背景抠图、透明 PNG、画布缩放、Spine 前缀命名、预览 GIF、描边，以及从新工程或带 Clipping/Mask 的模板生成 Spine 序列帧动画。

## 下载与启动

1. 当前公开便携包仍是 [2026.9.15 发布页](https://github.com/AlbertYm/SpineFrameStudio/releases/tag/v2026.9.15) 的 `SpineFrameStudio_2026.9.15.zip`。2026.9.22 已同步源码，但因第三方依赖材料尚未闭合，没有发布新的公开二进制附件。
2. 完整解压到可写文件夹，不要在 ZIP 内直接运行。
3. 双击发布包中的 EXE。全部同目录文件必须保留；不能只复制 EXE。
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
- “Spine 动画”：创建简单序列帧工程，或选择 `.spine` / Skeleton JSON 模板并保留骨骼、Slot、Skin、Clipping/Mask、Draw Order、Constraint 与已有动画；Mask 目标 Slot 可填写，也可从第一个 Clipping 范围自动识别。
- 批量停止会等待当前文件完成；失败时查看展开的日志。原始素材不覆盖，结果写入独立目录。

## 从源码运行

`src/` 是当前 2026.9.22 源码，版本依据为 `src/version.json`。从可信的 FFmpeg 发布渠道取得适用 Windows x64 的 `ffmpeg.exe`，放到 `src/`。然后双击 `src/打开抽帧工具.bat`。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\extract_frames.ps1 -Gui
```

需要生成 EXE 时，在 Windows PowerShell 5.1 中运行 `tools/build.ps1`；使用归档的 PS2EXE 1.0.18 源码，在独立 `dist/` 中构建，不覆盖历史发布。构建前需要 `src/ffmpeg.exe`。普通构建仅供本地验证；公开发布须运行 `tools/build.ps1 -ForPublicRelease`，当前依赖材料未完整，因此会拒绝公开打包。详见 [许可与来源档案](compliance/README.md)。

## 验证与限制

2026.9.22 开发机验收：普通抽帧回归 32 项通过；干净中文空格目录中的真实 EXE 完成 10 项 Spine GUI 检查。4 张 128×128 PNG 成功写入含 Clipping 的模板工程，往返后保留 `mask_slot, content_slot, mask_end` 顺序、Clipping 类型、4 个顶点、结束 Slot 和既有动画，并新增 4 个 attachment。用户实际复杂 Mask 工程、另一台电脑及 125% / 150% DPI 仍待人工验收。

已知限制：首帧预览、纯色抠图、设置不跨启动保存、停止在文件边界生效、部分提示优先中文。系统临时目录会保存 `SpineWorkbench_*` 诊断文件。创建 `.spine` 需要目标电脑安装并激活 Spine 4.1.24；模板克隆以 Spine JSON 能表达的运行时结构为准，不保证编辑器视图状态等专属元数据。

更新时解压到新目录，保留旧版与素材；回退直接运行保留的旧目录。退出程序后可删除程序目录完成卸载，删除前确认没有将自己的输出保存其中。

## 仓库与授权

项目自身源码与文档采用 [MIT License](LICENSE)，允许使用、修改、商用和再分发，须保留版权与许可证，无担保。第三方组件、第三方许可原文和归档源码不由 MIT 重新授权，见 [第三方说明](THIRD_PARTY_NOTICES.md)。本项目不是 Esoteric Software 的官方产品。

**历史便携包的 FFmpeg 完整对应源码尚未补齐，PS2EXE 上游许可表述也存在差异。** 本仓库已归档核实材料并阻止未来未经检查的公开打包，但不能将旧二进制包称为已完成许可整改。详见 [材料清单与缺项](compliance/README.md)。
