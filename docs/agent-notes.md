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

### Glossary whole-segment matching (post-merge, v1.6.1)

- Added `getGlossaryExactIndex()` in `background.js`: when a segment's trimmed text exactly equals a glossary source, the glossary target is applied directly and the model is skipped. Fixes short context-free labels being mistranslated (e.g. heading "About" → "について").
- Runs before the cache lookup, so a user mapping beats stale cached LLM output; exact hits are not written to the cache.
- Empty glossary target still means "keep as-is". Index is invalidated together with the automaton (`invalidateGlossary` / `loadGlossary`).
- Added `examples/ui-labels-ja.tsv` (common English nav/UI labels → Japanese) and a README "Glossary" section.
- Validated in Node with stubbed `chrome.storage` + `fetch`: `About` (x2) resolved to `概要` without reaching the model, other text went through the normal batch path.

### Removed "Delete all except current model" (post-merge, v1.6.1)

- Dropped the per-model cache deletion carried over from the fork: `cacheDeleteModel` in `cache.js`, the `CLEAR_OTHER_MODELS_CACHE` message, and the Options button/handler.
- Rationale: its purpose was freeing disk space in the persistent cache; the user's browser blocks IndexedDB (memory-only cache), and the 100k-entry LRU cap handles size anyway. Removing it also shrinks the diff against upstream.
- `cacheDeleteKeys` stays — selection repair (`CLEAR_TRANSLATION_CACHE_ENTRIES`) depends on it. Upstream's "Clear cache" button is untouched.

### Fix: XPI was missing cache.js (v1.6.1)

- "Failed to save glossary" after installing the 1.6.0 XPI was NOT a glossary bug: `mkxpi.sh` has an explicit file list that predates upstream's `cache.js`, so the packaged extension had no cache module. `SAVE_GLOSSARY` hit a ReferenceError on `cacheClear`.
- Same missing file also caused the bogus "doesn't support keeping the cache across sessions" warning (`cachePersistentAvailable` undefined → treated as unsupported) and the stuck "0 entries" count. A browser that blocks IndexedDB shows the same warning legitimately — check the background console to tell them apart.
- Fixed by adding `cache.js` to `mkxpi.sh` and guarding the two glossary handlers with `typeof cacheClear === 'function'` (same style as the onStartup guard). Rebuilt `local-llm-translator-1.6.1.xpi` and verified `cache.js` is inside.
- When adding a new runtime file, remember BOTH lists: `manifest.json` background scripts and `mkxpi.sh`.
- The earlier `local-llm-translator-1.6.0.xpi` is broken (no cache.js) — don't install it.

### Glossary load feedback (v1.6.1)

- Status line now shows count + file name + load time ("✅ 16 terms loaded from ui-labels-ja.tsv (…)"), highlighted via `.glossary-status-loaded`.
- Added a collapsible "Show loaded terms" preview under the status: first `GLOSSARY_PREVIEW_MAX` (200) rows as `source → target`, `(kept as-is)` for empty targets, "… and N more" for the rest. Rows are built with `textContent` (TSV content never hits innerHTML).
- `SAVE_GLOSSARY` now stores `{ name, loadedAt }` under storage.local `glossaryMeta`; `GET_GLOSSARY_INFO` returns count/name/loadedAt/preview; `CLEAR_GLOSSARY` removes both keys.
- Repurposed the orphaned `.cache-stat*` CSS (left from the removed per-model stats UI) into `.glossary-*` styles.

### Upstream PR #15: content-script bugfixes (2026-07-02)

- Opened https://github.com/Eldoprano/offline-browser-translate/pull/15 — first probe PR to see how the maintainer receives contributions.
- Branch `fix/skip-tags-and-decimal-split` (pushed to our GitHub fork), cut from `upstream/main`, two commits extracted from fork history: SKIP_TAGS ancestor check (e6ef018) and decimal sentence splitting (45381b8), `content.js` changes only.
- Evidence in the PR: upstream's regex silently DROPS text around decimals (`String.match` fragments don't cover the input), verified by extracting `splitIntoSentences` from both versions and diffing outputs.
- Remaining PR queue if #15 lands well: glossary (open an issue first), cancel-on-navigation, selection repair. Keep Ruby tooling / BUGS.md / agent-notes fork-only.
- Result: merged upstream as-is via merge commit be61e98 (2026-07-03 confirmed). Maintainer is receptive; skipped the "issue first" step for the glossary and went straight to a PR.

### Upstream PR: glossary (2026-07-03)

- Branch `feat/glossary` off `upstream/main` (2fffa0c), worktree-built, hand-ported (fork's background.js has extra features, so no cherry-pick):
  - `options/options.{js,html,css}`: fork diff vs upstream was glossary-only → applied wholesale via `git diff upstream/main -- <files> | git apply`.
  - `background.js`: glossary section (constants/loader/automaton/exact index) after `getSettings()`, prompt injection in `requestBatch`, whole-segment bypass before the cache lookup (`unresolvedGroups`), 3 message handlers after `CACHE_BACKEND`. No `promptSigFor`/cancel/selection-repair bits — those stay fork-only.
  - `README.md`: feature bullet + Glossary section only (no mkxpi/benchmark/selection-repair text).
  - `examples/ui-labels-ja.tsv`: sample dictionary, header comments rewritten in English for upstream.
- Verified with `scratchpad/test-glossary.js` (stubbed chrome + Ollama fetch, drives the real onMessage handler): 14/14 PASS — save/info/clear, whole-segment bypass, keep-as-is, prompt hints, and cache-on behavior (exact hits not written to cache; `CACHE_COUNT` = model results only).
- Reminder for fork: upstream cache messages are `CLEAR_CACHE`/`CACHE_COUNT`/`CACHE_BACKEND` — same names used by our merged tree.

## Handoff

- Cache is now **off by default** (upstream policy). Enable it in Options → Translation Cache; selection repair works with or without it.
- Old fork cache data under storage.local `translationCache` is orphaned (never read); harmless, cleared on uninstall.
- Selection repair cache keys include `promptSigFor` output — if key derivation in `translate()` changes, change the `CLEAR_TRANSLATION_CACHE_ENTRIES` handler the same way (both call the shared helper).
- `background.js` briefly contained a literal NUL again during the merge; keep the `\u0000` escape in source (see upstream 5b5f1d5 and the fork's `.gitattributes`).
- Validation run: `node --check` on all six JS files, duplicate-id scan on both HTML files, and a Node smoke test of `cacheDeleteKeys` / `cacheDeleteModel` (memory layer).
- Not yet done: real-browser test (load the extension, translate a page, try Retranslate/Discard Selection and "Delete all except current model"), XPI rebuild, push/PR decision.
