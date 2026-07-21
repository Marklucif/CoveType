# CoveType 2.1.4 自动安装说明

这份安装包会自动安装 CoveType，以及它使用的本地 AI 环境：

- Qwen3-ASR 0.6B 8-bit：离线语音识别与语种自动检测。
- Qwen3.5 0.8B 4-bit：关闭翻译时的本地文字润色。
- Apple Translation：开启即时翻译时使用系统设备端语言模型。
- 独立 CPython 3.12、MLX 运行环境及固定版本依赖，不污染系统 Python。

## 支持范围

- Apple 芯片 Mac（M1 或更新）。
- macOS 15 或更新。
- 首次安装至少保留 5 GB 可用空间。
- 安装模型与运行环境时需要联网；安装完成后的识别、润色和已下载语言包的翻译均可离线运行。

Intel Mac 与 macOS 14 或更早版本无法运行这套完整配置。原因是语音模型使用 Apple MLX，而即时翻译使用 macOS 15 的 Translation framework。

## 安装

双击 `Install CoveType.command`。脚本会自动完成环境、模型、应用、登录时自启动、默认配置及端到端自检。重复执行是安全的：已经完整下载的模型不会重复下载，旧应用会保存在：

`~/Library/Application Support/CoveType/backups`

旧应用会压缩为 ZIP，更新时保留原来的 `.app` 外层目录并原位替换内容，以免 macOS 把辅助功能授权跟随旧应用移动到备份位置。

如果系统阻止打开脚本，请按住 Control 点击脚本，选择“打开”。

脚本可选参数：

```zsh
./Install\ CoveType.command --skip-launch
./Install\ CoveType.command --skip-model-test
./Install\ CoveType.command --permissions-only
./Install\ CoveType.command --install-dir "$HOME/Applications"
```

## 自动权限向导

安装程序会读取 macOS 的系统区域设置，自动选择简体中文、繁体中文、英语、日语、韩语、法语、德语或西班牙语；其他语言回退到英语。随后它会启动 CoveType、显示逐步说明、打开对应的系统设置并检测授权结果。

macOS 不允许安装程序静默授予隐私权限，因此仍需要本人点击允许或打开开关：

1. 麦克风权限。
2. 辅助功能权限，用于全局快捷键和把结果粘贴到当前应用。
3. 首次使用某个翻译目标语言时，确认下载 Apple 设备端语言包。

脚本只有检测到麦克风和辅助功能都已开启后，才会显示权限检查通过。也可以选择“稍后处理”，以后使用 `--permissions-only` 只运行权限向导和检测，不必重新安装模型。

安装器会在当前用户的 `~/Library/LaunchAgents` 中写入 CoveType 登录启动项，并通过 macOS `launchd` 加载和验证。CoveType 会在用户登录桌面后自动启动；它不会在尚未登录时运行，也不会安装系统级守护进程。

## 快捷键

- 菜单栏 CoveType →“快捷键设置…”：直接录制一个实体单键或组合键。
- “触发前按住时长”：可在 0.10–1.50 秒之间调整，默认 0.32 秒；达到时长后开始录音，松开停止并转录。
- “恢复自动兼容模式”：恢复 `Fn`、任一 `Option/Alt`、任一 `Control` 按住说话。
- `Fn + Space`：免按住模式，按一次开始，再按一次停止。
- `Esc`：取消录音或处理。

在设定时长结束前，修饰键如果继续与其他按键组成正常快捷键，CoveType 会取消本次录音触发。例如按住时长为 0.32 秒时，快速按 `Control + C` 仍然只会复制。

## 存储位置

- 新安装：优先安装到 `/Applications/CoveType.app`；无写入权限时自动安装到 `~/Applications/CoveType.app`。
- 更新 CoveType 时会原位替换应用内容，并在更新前生成可恢复备份。
- 模型与运行环境使用 CoveType 自己的目录：`~/Library/Application Support/CoveType`。
