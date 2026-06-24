# Agent Notes

## Work Plan

- Add a way to repair rare bad translations for selected page text.
- Allow selected translations to be retranslated without reusing stale cache entries.
- Allow selected translations to be discarded, restoring original text and removing matching cached history.
- Add a reproducible local benchmark for translation throughput.
- Document the repair workflow and local benchmark reference values in README.

## Work Record

- Added popup actions for `Retranslate Selection` and `Discard Selection`.
- Added content-script handlers for selected segment retranslation and selected segment reset.
- Added background cache deletion for specific model/source/target/text entries.
- Added `scripts/benchmark.rb` for fixed-input Ollama/LM Studio benchmark output.
- Measured local Ollama reference values for `translategemma:4b` and `translategemma:12b`.
- Updated README with selection repair usage, benchmarking method, and local reference results.

## Handoff

- Selection repair operates on internal sentence/text-node segments, not arbitrary character ranges.
- `Retranslate Selection` clears matching cache entries before sending text to the provider.
- `Discard Selection` does not require a running provider, but still needs the content script to be available on the active tab.
- Benchmark results measure provider/API translation throughput only; full-page speed also depends on DOM size, cache hit rate, and parallel request settings.
- Validation run: `node --check background.js`, `node --check content.js`, `node --check popup/popup.js`, `ruby -c scripts/benchmark.rb`, and `git diff --check`.
