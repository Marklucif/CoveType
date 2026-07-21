# CoveType 更新通道

CoveType 已经彻底停止查询 `marswaveai/TypeNo` 的原版 GitHub Releases，避免原版应用覆盖本地 Qwen3-ASR、Qwen3.5、即时翻译、自定义快捷键和呼吸灯等功能。

应用只读取 `Info.plist` 中的以下字段：

- `CoveTypeUpdateChannelIdentifier`：当前为 `covetype-local-ai-stable`。
- `CoveTypeUpdateManifestURL`：`https://marklucif.github.io/CoveType/update.json`。

更新清单使用以下 JSON 格式：

```json
{
  "channel": "covetype-local-ai-stable",
  "bundle_identifier": "ai.covetype.app",
  "version": "2.1.4",
  "release_page_url": "https://github.com/Marklucif/CoveType/releases/tag/v2.1.4-beta.1"
}
```

只有通道标识、Bundle ID 与应用完全一致，版本号高于本机版本，且发布页面使用 HTTPS 时，CoveType 才会提示新版本。应用只打开我们的发布页面，不会静默下载安装未知程序；正式安装仍由签名安装包完成，并原位更新以尽量保留 macOS 隐私权限。

CoveType 使用完全独立的 Bundle ID `ai.covetype.app`，不复用上游应用的运行身份、权限记录或偏好设置域。
