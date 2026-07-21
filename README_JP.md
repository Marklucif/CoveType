# CoveType

[English](README.md) | [简体中文](README_CN.md)

[製品サイト](https://covetype.com/) · [ダウンロード](https://github.com/Marklucif/CoveType/releases/tag/v2.1.7-beta.1) · [フィードバック](https://github.com/Marklucif/CoveType/issues/new) · [プライバシー](docs/PRIVACY.md) · [上流プロジェクト](https://github.com/marswaveai/TypeNo)

**CoveType** は、プライバシーを重視した macOS 向けローカル AI 音声入力ツールです。ショートカットを押して話し、離すと Qwen3-ASR が Mac 上で文字起こしします。必要に応じて Qwen3.5 によるローカル整文、または Apple のオンデバイス翻訳を使用できます。

![CoveType — Private AI voice typing for Mac](assets/covetype-github-hero.png)

## 主な機能

- Qwen3-ASR 0.6B 8-bit によるローカル音声認識と30言語の自動検出
- Qwen3.5 0.8B 4-bit によるローカル文章整形
- Apple Translation によるオンデバイス即時翻訳
- 任意の物理キーまたはキー組み合わせと長押し時間の設定
- メニューバーの呼吸ランプ、マイク選択、ログイン時の自動起動
- アカウント不要。通常の認識と整文にクラウド AI API を使用しない設計
- 匿名利用統計は既定で有効で、「フィードバック…」画面から無効化可能。24時間に最大1回、ランダムなインストール ID、アプリ/macOS版、CPU構成だけを HTTPS 送信し、生の IP、音声、文字起こし、入力文字は保存しません
- クライアント内のフィードバック画面から CoveType 自身の GitHub Issue を作成

## 動作条件

- Apple シリコン（M1 以降）
- macOS 15 以降
- 8 GB RAM で動作、16 GB 推奨
- 5 GB 以上の空き容量
- 初回インストール時のインターネット接続

`dist/CoveType-2.1.7-macOS-AppleSilicon-Installer.zip` を展開し、`Install CoveType.command` を開いてください。インストーラは独立した Python/MLX 環境、モデル、ログイン項目、初期設定を構成します。マイクとアクセシビリティの許可は、macOS のシステム設定でユーザー本人が承認する必要があります。

## ライセンス

[marswaveai/TypeNo](https://github.com/marswaveai/TypeNo) を基にした派生プロジェクトで、GNU GPLv3 で公開します。モデルと依存パッケージにはそれぞれのライセンスが適用されます。
