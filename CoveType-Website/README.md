# CoveType static website

This folder is a dependency-free static download and documentation website.

- `index.html` — semantic page content with English as the no-JavaScript default
- `styles.css` — responsive styling
- `site.js` — website language selector and the exact 30-language ASR list
- `assets/` — local product artwork
- `downloads/` — the downloadable macOS installer

Preview locally:

```sh
python3 -m http.server 4173 --directory CoveType-Website
```

Then open `http://localhost:4173`.

The production site is deployed by GitHub Actions to `https://marklucif.github.io/CoveType/`. Installer links point to the matching GitHub prerelease asset; installer archives are intentionally excluded from the source repository.

The social sharing card was generated with the built-in image generation tool from this prompt: a minimal CoveType card with a dark green-black background, a mint/cyan/violet aurora orb, and the exact text “CoveType” / “Your voice stays on your Mac.”
