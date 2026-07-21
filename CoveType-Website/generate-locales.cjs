const fs = require("node:fs");
const path = require("node:path");
const { supportedLanguages, locales, textKeys, localePaths } = require("./site.js");

const root = __dirname;
const baseUrl = "https://covetype.com/";
const templatePath = path.join(root, "index.html");
const template = fs.readFileSync(templatePath, "utf8");
const localeSettings = {
  en: { lang: "en", path: "", ogLocale: "en_US" },
  "zh-Hans": { lang: "zh-Hans", path: "zh-cn/", ogLocale: "zh_CN" },
  "zh-Hant": { lang: "zh-Hant", path: "zh-tw/", ogLocale: "zh_TW" },
  ja: { lang: "ja", path: "ja/", ogLocale: "ja_JP" },
  ko: { lang: "ko", path: "ko/", ogLocale: "ko_KR" },
  fr: { lang: "fr", path: "fr/", ogLocale: "fr_FR" },
  de: { lang: "de", path: "de/", ogLocale: "de_DE" },
  es: { lang: "es", path: "es/", ogLocale: "es_ES" }
};

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function replaceTranslatedText(html, key, value) {
  const escapedKey = escapeRegex(key);
  const pattern = new RegExp(`(<([a-z0-9]+)\\b[^>]*data-i18n="${escapedKey}"[^>]*>)[\\s\\S]*?(</\\2>)`, "gi");
  return html.replace(pattern, `$1${escapeHtml(value)}$3`);
}

function replaceGenerated(html, id, content) {
  const pattern = new RegExp(`(<!-- GENERATED:${id}:START -->)[\\s\\S]*?(<!-- GENERATED:${id}:END -->)`);
  if (!pattern.test(html)) throw new Error(`Missing generated markers for ${id}`);
  return html.replace(pattern, `$1\n${content}\n$2`);
}

function replaceMeta(html, selector, value) {
  const escapedSelector = escapeRegex(selector);
  const pattern = new RegExp(`(<meta\\s+[^>]*(?:name|property)="${escapedSelector}"[^>]*content=")[^"]*("[^>]*>)`, "i");
  if (!pattern.test(html)) throw new Error(`Missing meta ${selector}`);
  return html.replace(pattern, `$1${escapeHtml(value)}$2`);
}

function structuredData(locale, t) {
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": `${baseUrl}#website`,
        url: baseUrl,
        name: "CoveType",
        description: t.seoDescription,
        inLanguage: localeSettings[locale].lang
      },
      {
        "@type": "SoftwareApplication",
        "@id": `${baseUrl}#app`,
        name: "CoveType",
        url: baseUrl,
        downloadUrl: "https://github.com/Marklucif/CoveType/releases/download/v2.1.7-beta.1/CoveType-2.1.7-macOS-AppleSilicon-Installer.zip",
        softwareVersion: "2.1.7",
        operatingSystem: "macOS 15 or later on Apple silicon",
        applicationCategory: "UtilitiesApplication",
        description: t.seoDescription,
        image: `${baseUrl}assets/covetype-icon.png`,
        screenshot: `${baseUrl}assets/status-lamps.png`,
        license: "https://www.gnu.org/licenses/gpl-3.0.html",
        codeRepository: "https://github.com/Marklucif/CoveType",
        featureList: t.features.map(([title]) => title),
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "USD",
          availability: "https://schema.org/InStock"
        }
      }
    ]
  };
}

function renderLocale(locale) {
  const settings = localeSettings[locale];
  const t = locales[locale];
  let html = template;

  html = html.replace(/<html\b[^>]*>/, `<html lang="${settings.lang}" data-locale="${locale}" data-root="${settings.path ? ".." : "."}">`);
  html = html.replace(/<title>[\s\S]*?<\/title>/, `<title>${escapeHtml(t.seoTitle)}</title>`);
  html = replaceMeta(html, "description", t.seoDescription);
  html = replaceMeta(html, "og:title", t.seoTitle);
  html = replaceMeta(html, "og:description", t.seoDescription);
  html = replaceMeta(html, "og:url", `${baseUrl}${settings.path}`);
  html = replaceMeta(html, "og:locale", settings.ogLocale);
  html = replaceMeta(html, "og:image:alt", t.seoTitle);
  html = replaceMeta(html, "twitter:title", t.seoTitle);
  html = replaceMeta(html, "twitter:description", t.seoDescription);
  html = replaceMeta(html, "twitter:image:alt", t.seoTitle);
  html = html.replace(/<link rel="canonical" href="[^"]*" \/>/, `<link rel="canonical" href="${baseUrl}${settings.path}" />`);

  for (const key of textKeys) {
    if (typeof t[key] === "string") html = replaceTranslatedText(html, key, t[key]);
  }

  const pairCards = (pairs, cardClass = "") => pairs.map(([title, text], index) =>
    `          <article${cardClass ? ` class="${cardClass}"` : ""}><span>${String(index + 1).padStart(2, "0")}</span><h3>${escapeHtml(title)}</h3><p>${escapeHtml(text)}</p></article>`
  ).join("\n");
  html = replaceGenerated(html, "painGrid", pairCards(t.painPoints));
  html = replaceGenerated(html, "featureGrid", pairCards(t.features, "card"));
  html = replaceGenerated(html, "comparisonRows", t.comparisons.map(([name, local, cloud]) =>
    `                <tr><th>${escapeHtml(name)}</th><td>${escapeHtml(local)}</td><td>${escapeHtml(cloud)}</td></tr>`
  ).join("\n"));
  html = replaceGenerated(html, "privacyList", t.privacy.map(([title, text]) =>
    `            <div><b>${escapeHtml(title)}</b><p>${escapeHtml(text)}</p></div>`
  ).join("\n"));
  html = replaceGenerated(html, "localFlow", t.localFlow.map(([title, text], index) =>
    `            <li><span>${index + 1}</span><b>${escapeHtml(title)}</b><small>${escapeHtml(text)}</small></li>`
  ).join("\n"));
  html = replaceGenerated(html, "proofGrid", t.proofs.map(([title, text]) =>
    `          <article><h3>${escapeHtml(title)}</h3><p>${escapeHtml(text)}</p></article>`
  ).join("\n"));
  html = replaceGenerated(html, "installSteps", t.installSteps.map(([title, text], index) =>
    `              <li><span>${index + 1}</span><div><b>${escapeHtml(title)}</b><p>${escapeHtml(text)}</p></div></li>`
  ).join("\n"));
  html = replaceGenerated(html, "faqList", t.faqs.map(([title, text]) =>
    `          <details><summary>${escapeHtml(title)}</summary><p>${escapeHtml(text)}</p></details>`
  ).join("\n"));

  let displayNames;
  try { displayNames = new Intl.DisplayNames([settings.lang], { type: "language" }); } catch (_) { displayNames = null; }
  html = replaceGenerated(html, "languageGrid", supportedLanguages.map(([code, fallback]) =>
    `<span>${escapeHtml(displayNames?.of(code) || fallback)}</span>`
  ).join(""));

  const jsonLd = JSON.stringify(structuredData(locale, t), null, 2)
    .split("\n").map((line) => `      ${line}`).join("\n");
  html = html.replace(/(<script type="application\/ld\+json" id="structured-data">)[\s\S]*?(<\/script>)/, `$1\n${jsonLd}\n    $2`);

  if (settings.path) {
    html = html
      .replaceAll('href="assets/', 'href="../assets/')
      .replaceAll('src="assets/', 'src="../assets/')
      .replace('href="styles.css"', 'href="../styles.css"')
      .replace('src="site.js"', 'src="../site.js"');
  }

  const outputDirectory = settings.path ? path.join(root, settings.path) : root;
  fs.mkdirSync(outputDirectory, { recursive: true });
  fs.writeFileSync(path.join(outputDirectory, "index.html"), html);
}

for (const locale of Object.keys(localeSettings)) {
  if (localePaths[locale] !== localeSettings[locale].path) throw new Error(`Locale path mismatch for ${locale}`);
  renderLocale(locale);
}

console.log(`Generated ${Object.keys(localeSettings).length} localized pages.`);
