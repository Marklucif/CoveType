# CoveType SEO notes

## Search intent targeted

Primary English phrases used naturally in visible content:

- private AI voice typing for Mac
- local speech to text Mac
- offline dictation Mac
- Mac voice typing app
- open source dictation Mac
- AI dictation app for Mac

Supporting intent:

- local AI text polishing
- voice to text translation
- multilingual voice typing
- Qwen speech to text
- voice typing without an account
- system-wide hold-to-talk shortcut

Simplified Chinese intent:

- Mac 语音输入
- Mac 语音转文字
- 本地语音转文字
- 离线语音输入
- AI 语音输入
- 开源语音输入

## User problems addressed

- Concern that sensitive audio or AI-cleaned text is sent to cloud services.
- Network latency and loss of functionality while offline.
- Raw transcripts that require punctuation and sentence cleanup.
- Global shortcuts that collide with normal development shortcuts.
- Voice typing that works only in a single editor instead of across Mac apps.
- Unclear subscription, account, or transcript-sync requirements.
- Translation features that silently use remote APIs.
- Privacy claims that cannot be inspected in closed-source software.

## Technical implementation

- One descriptive title, meta description, canonical URL, and H1 per locale.
- Static locale URLs with reciprocal `hreflang` links and `x-default`.
- Crawlable visible content without requiring JavaScript rendering.
- `WebSite` and accurate `SoftwareApplication` JSON-LD without fabricated ratings.
- XML sitemap and permissive robots file at the site root.
- Absolute Open Graph and X image URLs with a dedicated 1200×630 social image.
- Natural search language in headings and body copy; no `meta keywords` tag or keyword stuffing.

The first-party product claims stay deliberately precise: daily transcription and optional AI polishing run locally, while initial model installation, Apple translation pack downloads, update checks, GitHub feedback, and source/release links can use the network.
