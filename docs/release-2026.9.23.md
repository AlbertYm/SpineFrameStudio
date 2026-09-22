# Spine Frame Studio 2026.9.23

## 修复

- 修复 GUI 读取 `status.json` 与后台替换文件冲突时，任务因“正由另一进程使用”而失败。
- 修复 `Clipping end` 指回自身的模板无法自动确定目标 Slot；现在优先选择已有 Region/Mesh 的非 Clipping Slot。
- 修复模板 `images` 路径为空时未复制模板同目录图片的问题。

## Spine 模板验证

使用真实 `EmojiPumpkinKing_01.spine` 验证：自动选择 `frame_0001`，保留 `zhezhao, frame_0001` Slot 顺序、Clipping、已有 `Idle` 动画和 30 张模板图片，并加入新序列动画。

## 公开包依赖

GitHub Release 附件不包含 FFmpeg。请把可信的 Windows x64 `ffmpeg.exe` 放进程序目录，或加入系统 PATH。创建 `.spine` 工程还需要安装并激活 Spine 4.1.24。

## 已知边界

用户实际更多复杂 Mask/Deform 工程、另一台 Windows 电脑、125% / 150% DPI 和跨屏缩放仍待人工验收。EXE 未签名。
