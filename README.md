<h1 align="center">
  <img src="assets/logo.png" width="48" valign="middle"> Local LLM Translator
</h1>

A privacy-focused browser extension that translates web pages using local LLMs (Ollama or LMStudio). **Your data never leaves your machine.**

[![Get the Add-on](https://extensionworkshop.com/assets/img/documentation/publish/get-the-addon-178x60px.dad84b42.png)](https://addons.mozilla.org/en-GB/firefox/addon/local-llm-translator/)

## Features

- 🔒 **100% Private** - All translations happen on your local machine via Ollama or LMStudio
- 🎯 **Smart Prioritization** - Visible content and headings are translated first
- 🌍 **Many Languages** - Supports many many languages :3
- ⚡ **Translation Cache** - Optional: translate identical text once and reuse it (great for forums). Off by default; stored locally with a session-only or persistent mode
- 🛠️ **Selection Repair** - Retranslate a bad selected segment or discard its cached translation and restore the original text
- 📖 **Glossary** - Force consistent translations for proper nouns and UI labels via a user-supplied TSV dictionary

## Requirements

You need one of these running locally:

- **[Ollama](https://ollama.ai/)** (default: `http://localhost:11434`)
- **[LMStudio](https://lmstudio.ai/)** (default: `http://localhost:1234`)

With a translation-capable model loaded (e.g. `TranslateGemma`, `tencent.hunyuan-mt`, `qwen3`, etc.)

## Installation

### Firefox / Mullvad Browser
1. Go to `about:debugging#/runtime/this-firefox`
2. Click **Load Temporary Add-on**
3. Select the `manifest.json` file

This is temporary and is removed on restart. For a persistent install, package it
as an `.xpi` and load it in a browser that allows unsigned add-ons (Firefox
Developer Edition / Nightly / ESR with `xpinstall.signatures.required = false`):

1. Run `./mkxpi.sh` to produce `local-llm-translator-<version>.xpi`
2. Go to `about:addons` → gear icon → **Install Add-on From File**
3. Select the generated `.xpi`

An xpi is just a zip with `manifest.json` at the root, so no signing or `web-ext`
is needed. Bump `version` in `manifest.json` and re-run `./mkxpi.sh` to update.

### Chrome / Chromium
1. Go to `chrome://extensions`
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select the extension folder

**Coming Soon:** Extension in Chrome Web Store

## Preview

<p align="center">
  <img src="assets/translating.png" width="600" alt="Extension Screenshot">
</p>

## Usage

1. Click the extension icon
2. Select a model from the dropdown
3. Choose your target language
4. Click **Translate Page**

The extension will:
- Extract all visible text from the page
- Prioritize headings and visible content
- Translate in batches with progress percentage
- Auto-translate new content (infinite scroll)

### Fixing a Bad Translation

If a small part of the page is translated badly:

1. Select the bad translated text on the page
2. Open the extension popup
3. Click **Retranslate Selection** to force a fresh translation
4. Click **Discard Selection** to restore the original text and forget that cached translation

Selection actions work on the extension's internal sentence/text segments. Long text is usually handled sentence by sentence; short UI text may be restored or retranslated as one text-node segment.

## Benchmarking

Use `scripts/benchmark.rb` to measure local LLM translation speed with a fixed
8-segment input set. This measures provider/API translation throughput, not
browser DOM replacement time.

```sh
PROVIDER=ollama MODEL=translategemma:4b TARGET_LANGUAGE=Japanese ./scripts/benchmark.rb
```

Recommended reporting:

- Use one warmup run and at least three measured runs (the script default)
- Record the model, provider, target language, wall time, source characters/sec,
  and output tokens/sec
- Keep the benchmark input unchanged when comparing models or machines

### Local Reference

Measured on 2026-06-24 with Ollama, English -> Japanese, 8 segments / 584 source
characters. These are reference numbers for this machine, not a guarantee for
other pages; real page translation also depends on DOM size, cache hits, and
parallel request settings.

Machine:

- OS: `Linux 7.0.12-zen1-1.1-zen x86_64 GNU/Linux`
- CPU: AMD Ryzen 7 3700X 8-Core Processor / 16 threads
- RAM: 31.3 GiB
- GPU: NVIDIA GeForce RTX 3060, 12 GiB VRAM, driver 610.43.02

| Model | Avg wall time | Source chars/s | Avg output tokens/s |
|-------|---------------|----------------|---------------------|
| `translategemma:4b` | 4.12 s | 145.1 | 75.4 |
| `translategemma:12b` | 7.29 s | 80.1 | 34.3 |

## Privacy

This extension is designed to be privacy-focused:

- ✅ Only connects to `localhost` - no external network requests
- ✅ No analytics or tracking
- ✅ No data collection
- ✅ Minimal permissions (only `localhost` host permissions)
- ✅ The translation cache is **off by default**. When enabled it is stored **locally** (in memory, or IndexedDB for the persistent mode) and never leaves your machine; it can be set to clear on browser close, turned off, or cleared at any time

## Settings

Click **Advanced Settings** to configure:

| Setting | Description |
|---------|-------------|
| Provider | Auto-detect, Ollama only, or LMStudio only |
| URLs | Custom endpoints for Ollama/LMStudio |
| Max tokens/items per batch | Control batch sizes |
| Temperature | Model creativity (lower = more consistent) |
| Request Format (*work in progress*) | Default JSON, Hunyuan-MT, Simple, or Custom |
| Show Glow | Toggle visual indicator on translated text |
| Cache translations | Reuse stored translations for identical text — *off* (default), *until browser close*, or *across sessions*; includes a "Clear cache" button |
| Retranslate/Discard Selection | Repair selected bad translations from the popup. Retranslate clears the matching cache entry first; discard restores original text and removes the cached result |

## Translation Cache

To avoid re-translating the same text over and over (forum boilerplate, menus, usernames, repeated phrases), translations can be cached locally and reused — both later on the same page and across other pages. It is **off by default**; enable it in Options or the popup's Advanced Settings.

- **Modes (Options → Translation Cache):**
  - **Don't cache** (default) — every segment is translated fresh.
  - **Until I close the browser** — cache speeds things up while you browse, then is wiped on the next browser start. Kept in memory, so nothing translation-related lingers on disk between sessions. Works in every browser.
  - **Keep across sessions** — cache persists on disk (IndexedDB) until you clear it. Best for repeatedly visiting the same sites. Hardened browsers that block IndexedDB (e.g. Mullvad/Tor-based Firefox) disable this option automatically and fall back to the in-memory session cache.
- **What's cached:** the translated output for each source text segment, stored locally (in memory, or IndexedDB for the persistent mode) — nothing is uploaded.
- **How it's keyed:** by the source text plus everything that determines the model's output — model, source & target language, request format, prompt template, structured-output mode, and temperature. Changing any of these yields fresh translations instead of stale cached ones, so the cache never serves output that wouldn't match your current settings.
- **De-duplication:** within a single page, identical strings are translated only once and the result is reused for every occurrence (this happens regardless of cache mode).
- **Clearing:** use **Clear cache** to wipe it at any time (the button shows the current entry count). The cache is capped (oldest entries are evicted first).

## Glossary

Load a TSV dictionary (Options → Glossary) to pin translations for specific terms. Each line is `source<TAB>translation`; leave the second column empty to keep the term untranslated. Matching is case-sensitive.

It works at two levels:

- **Inside sentences** — glossary terms found in the text being translated are injected into the prompt as hard hints, so the model keeps proper nouns consistent (e.g. *The Companions* → *同胞団* everywhere). Only matching terms are sent, so a large dictionary is fine.
- **Whole segments** — when a segment consists *entirely* of a glossary term, the mapping is applied directly and the model is skipped. This is the reliable way to fix short context-free labels that small models mangle — e.g. add `About<TAB>概要` and the nav heading "About" always becomes "概要" instead of the broken "について".

Whole-segment matches take priority over the translation cache, and loading or clearing a glossary wipes the cache (the same source text now translates differently). See `examples/` for sample dictionaries.

## File Structure

```
├── manifest.json      # Extension manifest (MV3)
├── background.js      # Background script (LLM API, settings)
├── content.js         # Content script (DOM manipulation)
├── scripts/
│   └── benchmark.rb   # Local provider translation benchmark
├── popup/
│   ├── popup.html     # Popup UI
│   ├── popup.css      # Styles (Everforest Dark theme)
│   └── popup.js       # Popup logic
├── icons/             # Extension icons
└── mkxpi.sh           # Build an installable .xpi (no signing needed)
```

## Development

The codebase is intentionally simple with no build step or dependencies:

- Pure vanilla JavaScript
- No external libraries
- No bundler required
- Works directly in the browser

### Debug Logging

Enable **"Enable debug logging"** in Options → Output Settings, then Save.

To view logs, go to `about:debugging#/runtime/this-firefox`, find **Local LLM Translator**, and click **Inspect** — messages with `[Background]` prefix appear in the Console tab.

## License

MIT
