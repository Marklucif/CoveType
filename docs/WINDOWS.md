# CoveType 的 Windows 使用与安装方案

## 当前可用部分

`scripts/install_windows_backend.ps1` 可以在 Windows 10/11 x64 上安装独立 Python 3.12 环境、PyTorch、官方 `qwen-asr` Transformers 后端与 Qwen3-ASR 0.6B 模型。它不会污染系统 Python。

在 PowerShell 中运行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install_windows_backend.ps1
```

脚本自动检测 NVIDIA GPU：检测到 NVIDIA 时默认安装兼容面较广的 CUDA 12.6 PyTorch；否则安装 CPU 版。也可以明确选择：

```powershell
.\scripts\install_windows_backend.ps1 -Backend Cuda130
.\scripts\install_windows_backend.ps1 -Backend Cuda126
.\scripts\install_windows_backend.ps1 -Backend CPU
```

安装结束会生成目录 `%LOCALAPPDATA%\CoveType\Start Qwen3-ASR Demo.ps1`。运行它可以在浏览器中测试本地麦克风识别。

## 目前不能直接把 macOS 应用复制到 Windows

CoveType 的 macOS 客户端由 AppKit/SwiftUI、AVFoundation、Apple Translation、辅助功能 API 和 MLX 组成，这些框架在 Windows 不存在。Windows 脚本目前交付的是可运行的官方识别后端和测试界面，还不是能向任意程序自动粘贴的 CoveType 原生托盘客户端。

## 完整 Windows 客户端的落地设计

完整移植应保留界面和交互，替换平台层：

| 功能 | macOS 当前实现 | Windows 实现 |
|---|---|---|
| 托盘与聆听浮层 | AppKit / SwiftUI | .NET 8 + WPF 或 WinUI 3 |
| 全局按键 | NSEvent / 辅助功能 | RegisterHotKey + Raw Input / 低级键盘钩子 |
| 录音 | AVFoundation | WASAPI |
| 语音识别 | MLX Qwen3-ASR | 官方 qwen-asr + PyTorch CUDA/CPU |
| 输入当前应用 | CGEvent + 剪贴板 | SendInput + 剪贴板 |
| 翻译 | Apple Translation | 本地翻译模型或可选网络翻译服务 |
| 润色 | MLX Qwen3.5 0.8B | Transformers/ONNX 量化模型 |

Windows 上不能依赖 `Fn`：多数键盘在固件层处理它，系统收不到稳定的独立 Fn 事件。建议默认使用“按住右 Ctrl 说话”，并提供鼠标侧键与用户可配置组合键；免按住模式可用 `Ctrl + Win + Space`。

## 性能建议

- NVIDIA GPU：推荐，0.6B 模型延迟和常驻速度明显更合适。
- 仅 CPU：能安装和运行，但识别延迟会高，不适合作为最终实时体验。
- Intel/AMD GPU：需要单独评估 DirectML、OpenVINO 或 PyTorch XPU 路线，不能假定 CUDA 安装包可用。

下一阶段要交付 Windows 完整成品，需要新增一个 Windows 原生客户端工程，并在真实 Windows 10/11、NVIDIA 与纯 CPU 机器上分别验证键盘钩子、录音设备切换、权限和输入注入。
