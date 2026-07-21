# CoveType privacy and anonymous usage statistics

CoveType performs microphone capture, Qwen3-ASR transcription, Qwen3.5 polishing, and transcript insertion on the Mac. Audio, transcripts, typed text, clipboard contents, application names, names, email addresses, and precise location are not included in anonymous usage statistics.

Anonymous usage statistics are enabled by default and can be disabled at any time in **CoveType → Send Feedback… → Send anonymous daily usage statistics**. Disabling the setting stops future telemetry attempts.

At most once every 24 hours, CoveType sends one readable JSON request over HTTPS to `https://telemetry.covetype.com/v1/heartbeat` containing:

- a randomly generated installation UUID;
- CoveType version;
- macOS major/minor version;
- processor architecture (`arm64` or `x86_64`).

Cloudflare derives a two-letter country code from the network request. CoveType does not write the raw IP address to its database. The Worker converts the random installation UUID to a server-secret HMAC before storage, so the raw UUID is not stored. Daily activity records are deleted after 90 days and installations inactive for 365 days are deleted. Aggregate statistics report active device counts, countries, versions, macOS versions, and architectures; they do not expose installation identifiers.

The complete macOS client and telemetry Worker source are included in this repository for inspection.

## 中文说明

CoveType 的麦克风采集、Qwen3-ASR 转录、Qwen3.5 润色和文字输入都在 Mac 本地完成。匿名统计不包含录音、转录结果、输入文字、剪贴板内容、应用名称、姓名、邮箱或精确位置。

匿名使用统计默认开启，可随时在 **CoveType → 使用反馈… → 发送匿名每日使用统计** 中关闭；关闭后不再进行后续统计请求。

CoveType 每 24 小时最多通过 HTTPS 向 `https://telemetry.covetype.com/v1/heartbeat` 发送一次可读 JSON，其中只有：随机生成的安装 UUID、CoveType 版本、macOS 主/次版本和处理器架构。Cloudflare 根据网络请求判断两位国家代码；CoveType 不把原始 IP 写入数据库。服务端会先用密钥 HMAC 转换随机安装 UUID，再保存转换结果，不保存原始 UUID。

每日活跃记录保留 90 天；连续 365 天未活跃的安装记录会自动删除。后台只输出活跃设备数量、国家、版本、macOS 和芯片架构汇总，不公开安装编号。客户端与统计服务源码都在本仓库中，可直接检查。
