# Agent Notes

## Work Plan

- Fix sentence splitting around decimal numbers such as `SAML 2.0`.
- Bump the extension version to `1.5.9`.
- Rebuild the local unsigned XPI package.
- Add a way to repair rare bad translations for selected page text.
- Allow selected translations to be retranslated without reusing stale cache entries.
- Allow selected translations to be discarded, restoring original text and removing matching cached history.
- Add a reproducible local benchmark for translation throughput.
- Document the repair workflow and local benchmark reference values in README.

## Work Record

- Replaced sentence splitting with a small scanner that preserves decimal numbers.
- Confirmed the Keycloak `SAML 2.0 Identity Providers` sample now splits into complete sentences.
- Updated `manifest.json` to version `1.5.9`.
- Added popup actions for `Retranslate Selection` and `Discard Selection`.
- Added content-script handlers for selected segment retranslation and selected segment reset.
- Added background cache deletion for specific model/source/target/text entries.
- Added `scripts/benchmark.rb` for fixed-input Ollama/LM Studio benchmark output.
- Measured local Ollama reference values for `translategemma:4b` and `translategemma:12b`.
- Updated README with selection repair usage, benchmarking method, and local reference results.

## Handoff

- Reload the extension after installing `local-llm-translator-1.5.9.xpi`.
- If a bad translation was cached before this fix, clear the relevant translation cache before retesting.
- Selection repair operates on internal sentence/text-node segments, not arbitrary character ranges.
- `Retranslate Selection` clears matching cache entries before sending text to the provider.
- `Discard Selection` does not require a running provider, but still needs the content script to be available on the active tab.
- Benchmark results measure provider/API translation throughput only; full-page speed also depends on DOM size, cache hit rate, and parallel request settings.
- Validation run: `node --check background.js`, `node --check content.js`, `node --check popup/popup.js`, `ruby -c scripts/benchmark.rb`, and `git diff --check`.
