#!/bin/sh
# Build an installable .xpi from this directory.
# No signing/web-ext needed: an xpi is just a zip with manifest.json at the root.
# Install via about:addons -> gear -> "Install Add-on From File"
# (requires xpinstall.signatures.required = false, e.g. Developer Edition).
set -eu

cd "$(dirname "$0")"

version=$(grep -o '"version"[^,]*' manifest.json | head -1 | grep -o '[0-9][0-9.]*')
out="local-llm-translator-${version}.xpi"

rm -f "$out"

# List the runtime files explicitly so build artifacts, assets/ (store
# screenshots) and docs stay out of the package.
bsdtar --format zip -cf "$out" \
	manifest.json \
	background.js \
	content.js \
	languages.js \
	options \
	popup \
	translator \
	icons

echo "built: $out"
