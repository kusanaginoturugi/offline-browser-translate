# 既知の不具合

GitHub Issues が無効なため、ここに記録する。

## [修正済み] SKIP_TAGS が直近の親要素にしか効かず、`<pre><code>` 内が翻訳される

`shouldSkipElement()` の祖先ループ内で `SKIP_TAGS` を判定するよう修正済み。

### 概要

`content.js` の `shouldSkipElement()` は `SKIP_TAGS`（`SCRIPT`/`STYLE`/`CODE`/`PRE` など）の判定を **テキストノードの直近の親要素にしか適用していない**。間に `span`/`div` などが挟まると貫通し、`<pre><code>` 内のコードまで翻訳されてしまう。

### 再現

Astro Starlight / Expressive Code 系のシンタックスハイライト構造で発生:

```html
<pre data-language="txt"><code>
  <div class="ec-line"><div class="code">
    <span style="--0:#eeffff;--1:#62676a">wrangler containers build [パス] [オプション]</span>
  </div></div>
</code></pre>
```

テキストノードの直接の親は `<span>` で `SKIP_TAGS.has('SPAN')` は false。`<code>`/`<pre>` は祖先にしか存在しないが、現状の祖先ループは `translate="no"` と自前 ID しか見ておらず `SKIP_TAGS` を再チェックしていないため除外されない。

- `<pre><code>foo</code></pre>` のように直接の親が `code`/`pre` なら正しく除外される
- 間にラッパー要素が入ると貫通する

### 原因箇所

`content.js` `shouldSkipElement()`:

```js
function shouldSkipElement(element) {
    if (SKIP_TAGS.has(element.tagName)) return true;   // 直近の親だけ
    ...
    while (curr) {
        if (curr.getAttribute('translate') === 'no') return true; // SKIP_TAGS を見ていない
        if (curr.id === '...') return true;
        curr = curr.parentElement;
    }
}
```

### 修正案

祖先ループ内でも `SKIP_TAGS` を判定する:

```js
while (curr) {
    if (curr.tagName && SKIP_TAGS.has(curr.tagName)) return true;
    if (curr.getAttribute && curr.getAttribute('translate') === 'no') return true;
    if (curr.id === 'llm-translator-status' || curr.id === 'llm-translator-float-btn') return true;
    curr = curr.parentElement;
}
```

冒頭の `if (SKIP_TAGS.has(element.tagName))` はループが兼ねるので削除可（早期 return として残してもよい）。

### 備考

別マシンで修正済みだがこのリポジトリへコミットし忘れている可能性あり。コミットを取り込むか、上記で再修正する。
