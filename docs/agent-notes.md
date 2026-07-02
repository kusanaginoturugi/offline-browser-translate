# Agent Notes

## Work Plan

- Merge upstream (Eldoprano/offline-browser-translate) `main` into the fork.
- Adopt upstream's IndexedDB translation cache (`cache.js`, three-mode `cacheMode`) and remove the fork's storage.local cache.
- Keep fork-only features working on top of it: glossary, selection repair, per-model cache deletion, benchmark.

## Work Record

- Merged `upstream/main` (69176649, v1.6.0) on branch `merge-upstream`; merge base was df65723.
- Resolved conflicts in `README.md`, `manifest.json`, `background.js`, `options/options.js`, `popup/popup.css`, `popup/popup.js`.
- Removed the fork's translation cache (Map + storage.local in `background.js`) in favor of upstream's `cache.js` (memory + IndexedDB, `cacheMode`: off/session/persistent).
- Ported fork cache features onto `cache.js`:
  - `cacheDeleteModel(model, keep)` — per-model deletion, used by `CLEAR_OTHER_MODELS_CACHE` ("Delete all except current model" in Options).
  - `cacheDeleteKeys(keys)` — exact-entry deletion, used by `CLEAR_TRANSLATION_CACHE_ENTRIES` (selection repair/discard).
- Extracted `promptSigFor(settings, modelId)` in `background.js` so `translate()` and the entry-deletion handler build identical cache keys (keys include the prompt-shape hash).
- Dropped fork-only settings/UI: `useTranslationCache` checkbox, per-model cache stats list (`refreshCacheStats`), `CLEAR_TRANSLATION_CACHE` / `GET_CACHE_STATS` / `CLEAR_MODEL_CACHE` messages.
- Glossary save/clear now invalidates via upstream's `cacheClear()`.
- `popup.js`: fork's `runSelectionCommand` now reads the model from upstream's `modelPicker.getValue()` (old `elements.modelSelect` is gone from the popup).
- Version is upstream's `1.6.0`.

## Handoff

- Cache is now **off by default** (upstream policy). Enable it in Options → Translation Cache; selection repair works with or without it.
- Old fork cache data under storage.local `translationCache` is orphaned (never read); harmless, cleared on uninstall.
- Selection repair cache keys include `promptSigFor` output — if key derivation in `translate()` changes, change the `CLEAR_TRANSLATION_CACHE_ENTRIES` handler the same way (both call the shared helper).
- `background.js` briefly contained a literal NUL again during the merge; keep the `\u0000` escape in source (see upstream 5b5f1d5 and the fork's `.gitattributes`).
- Validation run: `node --check` on all six JS files, duplicate-id scan on both HTML files, and a Node smoke test of `cacheDeleteKeys` / `cacheDeleteModel` (memory layer).
- Not yet done: real-browser test (load the extension, translate a page, try Retranslate/Discard Selection and "Delete all except current model"), XPI rebuild, push/PR decision.
