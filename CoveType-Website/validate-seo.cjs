const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;
const pages = [
  ["index.html", "https://covetype.com/"],
  ["zh-cn/index.html", "https://covetype.com/zh-cn/"],
  ["zh-tw/index.html", "https://covetype.com/zh-tw/"],
  ["ja/index.html", "https://covetype.com/ja/"],
  ["ko/index.html", "https://covetype.com/ko/"],
  ["fr/index.html", "https://covetype.com/fr/"],
  ["de/index.html", "https://covetype.com/de/"],
  ["es/index.html", "https://covetype.com/es/"]
];

function matches(html, pattern) {
  return [...html.matchAll(pattern)];
}

for (const [relativePath, canonicalUrl] of pages) {
  const html = fs.readFileSync(path.join(root, relativePath), "utf8");
  const titles = matches(html, /<title>([^<]+)<\/title>/g);
  const descriptions = matches(html, /<meta\s+name="description"\s+content="([^"]+)"/gs);
  const canonicals = matches(html, /<link rel="canonical" href="([^"]+)"/g);
  const headings = matches(html, /<h1\b/g);
  const alternates = matches(html, /<link rel="alternate" hreflang="([^"]+)" href="([^"]+)"/g);
  const jsonLdText = html.match(/<script type="application\/ld\+json" id="structured-data">([\s\S]*?)<\/script>/)?.[1];

  if (titles.length !== 1) throw new Error(`${relativePath}: expected one title`);
  if (descriptions.length !== 1) throw new Error(`${relativePath}: expected one meta description`);
  if (canonicals.length !== 1 || canonicals[0][1] !== canonicalUrl) throw new Error(`${relativePath}: canonical mismatch`);
  if (headings.length !== 1) throw new Error(`${relativePath}: expected one H1`);
  if (alternates.length !== 9) throw new Error(`${relativePath}: incomplete hreflang set`);
  if (!jsonLdText) throw new Error(`${relativePath}: missing JSON-LD`);
  if (/meta\s+name="keywords"/i.test(html)) throw new Error(`${relativePath}: obsolete meta keywords found`);
  if (/content="[^"]*noindex/i.test(html)) throw new Error(`${relativePath}: page is not indexable`);

  const titleLength = [...titles[0][1]].length;
  const descriptionLength = [...descriptions[0][1]].length;
  if (titleLength < 20 || titleLength > 65) throw new Error(`${relativePath}: title length ${titleLength}`);
  if (descriptionLength < 60 || descriptionLength > 180) throw new Error(`${relativePath}: description length ${descriptionLength}`);
  JSON.parse(jsonLdText);
}

const english = fs.readFileSync(path.join(root, "index.html"), "utf8").toLowerCase();
for (const phrase of ["ai voice typing", "speech-to-text", "offline", "privacy", "local ai", "open source", "translation"]) {
  if (!english.includes(phrase)) throw new Error(`English search intent missing: ${phrase}`);
}
for (const phrase of ["anonymous daily usage statistics", "enabled by default", "feedback window", "audio, transcripts, and typed text are never included"]) {
  if (!english.includes(phrase)) throw new Error(`English telemetry disclosure missing: ${phrase}`);
}

const simplifiedChinese = fs.readFileSync(path.join(root, "zh-cn/index.html"), "utf8");
for (const phrase of ["语音输入", "语音转文字", "本地", "隐私", "免费开源", "翻译"]) {
  if (!simplifiedChinese.includes(phrase)) throw new Error(`Chinese search intent missing: ${phrase}`);
}
for (const phrase of ["匿名每日使用统计", "默认开启", "使用反馈", "绝不包含录音、转录结果或输入文字"]) {
  if (!simplifiedChinese.includes(phrase)) throw new Error(`Chinese telemetry disclosure missing: ${phrase}`);
}

for (const [relativePath] of pages) {
  const html = fs.readFileSync(path.join(root, relativePath), "utf8");
  if (!html.includes('class="telemetry-disclosure"')) {
    throw new Error(`${relativePath}: telemetry disclosure missing`);
  }
  if (/v2\.1\.[4-7]-beta\.1|CoveType-2\.1\.[4-7]-macOS/.test(html)) {
    throw new Error(`${relativePath}: outdated download link found`);
  }
  if (!html.includes("v2.1.8-beta.1/CoveType-2.1.8-macOS-AppleSilicon-Installer.zip")) {
    throw new Error(`${relativePath}: current download link missing`);
  }
  if (!html.includes("659c719f6b1f5c11b4f2086e0d063e4c860bacb6cf9d7d7da1745506bfd47a3c")) {
    throw new Error(`${relativePath}: current installer checksum missing`);
  }
}

if (!fs.existsSync(path.join(root, "assets/covetype-social-card-seo.png"))) throw new Error("Social image missing");
if (!fs.readFileSync(path.join(root, "robots.txt"), "utf8").includes("sitemap.xml")) throw new Error("robots.txt does not reference sitemap");
if (matches(fs.readFileSync(path.join(root, "sitemap.xml"), "utf8"), /<loc>https:\/\/covetype\.com\//g).length !== pages.length) throw new Error("Sitemap URL count mismatch");

console.log(`SEO validation passed for ${pages.length} localized pages.`);
