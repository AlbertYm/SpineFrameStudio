# 第三方组件

便携版使用 FFmpeg；它是独立外部进程，不是本项目源码。2026.9.15 历史包版本为 `N-102062-g63b2b0f47d-ffmpeg-windows-build-helpers`，构建包含 `--enable-gpl --enable-version3` 和第三方库。FFmpeg 相关许可说明见 https://ffmpeg.org/legal.html ，源码见 https://git.ffmpeg.org/ffmpeg.git ，对应 FFmpeg commit 为 `63b2b0f47d`。构建工具项目为 https://github.com/rdp/ffmpeg-windows-build-helpers 。上述信息不是全部第三方库对应源码已经归档的证明。

历史二进制的完整构建依赖源码和分发许可材料尚未在本仓库归档。使用者和再分发者应核对实际二进制的 `ffmpeg -version`、`ffmpeg -L` 与对应源码要求；未来发布应补齐可重现构建来源与所有适用许可材料。

EXE 启动器通过 PS2EXE 构建，项目及许可：https://github.com/MScholtes/PS2EXE 。运行依赖 Windows PowerShell / .NET Framework，受 Microsoft 各自许可约束。Spine 名称用于说明素材用途，本工具不包含 Spine 编辑器或 Spine Runtime。
