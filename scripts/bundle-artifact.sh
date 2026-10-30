#!/bin/bash
set -e

# [LOCAL REWRITE 2026-10-30] Vite + vite-plugin-singlefile edition.
# Replaces the Parcel + html-inline flow. Output is ONE .html file with no
# external references. A post-build check fails loudly if anything leaks out,
# so "self-contained" is verified rather than assumed.

echo "📦 Bundling to a single self-contained HTML file..."

if [ ! -f "package.json" ]; then
  echo "❌ Error: No package.json found. Run this script from your project root."
  exit 1
fi
if [ ! -f "index.html" ]; then
  echo "❌ Error: No index.html found in project root."
  exit 1
fi
if ! grep -q "vite-plugin-singlefile" package.json 2>/dev/null; then
  echo "❌ Error: vite-plugin-singlefile is missing."
  echo "   This project was scaffolded by the upstream Parcel-based script."
  echo "   Re-run init-artifact.sh to get the Vite-based scaffold."
  exit 1
fi

echo "🧹 Cleaning previous build..."
rm -rf dist bundle.html

echo "🔨 Building with Vite..."
pnpm exec vite build 2>&1 | tail -12

SRC=$(ls -1 dist/*.html 2>/dev/null | head -1)
if [ -z "$SRC" ]; then
  echo "❌ Error: build produced no HTML in dist/"
  exit 1
fi
cp "$SRC" bundle.html

FILE_SIZE=$(du -h bundle.html | cut -f1)

# ---------------------------------------------------------------------------
# Self-containment check. Only real markup attributes count; string fragments
# inside minified JS look like attributes to grep but are not network requests.
# ---------------------------------------------------------------------------
echo "🔍 Verifying self-containment..."
LEAKS=$(grep -oE '(src|href)="/[^"/][^"]*"' bundle.html | sort -u | head -10 || true)
IMPORTMAPS=$(grep -c 'type=importmap' bundle.html || true)
LEFTOVER=$(ls dist | grep -vE '\.html$' | head -10 || true)

STATUS=0
if [ -n "$LEAKS" ]; then
  echo "⚠️  Found root-relative references (would 404 when the file is moved):"
  echo "$LEAKS"
  STATUS=1
fi
if [ "$IMPORTMAPS" -gt 0 ]; then
  echo "⚠️  Found $IMPORTMAPS import-map(s); some assets may still be external."
  STATUS=1
fi
if [ -n "$LEFTOVER" ]; then
  echo "ℹ️  Extra files in dist/ (already inlined, safe to ignore):"
  echo "$LEFTOVER"
fi

if [ "$STATUS" -eq 0 ]; then
  echo "✅ Self-contained: no root-relative refs, no import-maps."
else
  echo "❌ Bundle written but NOT fully self-contained (see above)."
  echo "   Treat this as a failure, not a warning: the file will break when moved."
  exit 1
fi

echo ""
echo "✅ Bundle complete!"
echo "📄 Output: bundle.html ($FILE_SIZE)"
echo "📂 Open it directly: open bundle.html"
