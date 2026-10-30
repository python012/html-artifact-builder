#!/usr/bin/env bash
# [LOCAL ADDITION 2026-10-30] Render a Markdown file as a single self-contained
# HTML document, using the MarkdownDocument component shipped with this skill.
#
# Why a script: doing this by hand means (a) hand-copying the source into a TS
# module, which risks silent content loss, and (b) rebuilding the TOC / search /
# highlighting scaffolding every time. This wires it up in one command.
#
# Usage:
#   bash scripts/md-to-html.sh <input.md> [options]
#
# Options:
#   --title <text>     Browser tab title. Markdown has no <title>, so this is the
#                      one piece of metadata the model should choose deliberately.
#                      Prefer a short, human-readable name over the raw first line.
#                      Falls back to the H1 of the document, then the filename.
#   --lang <code>      <html lang>, and the language of the UI chrome (TOC label,
#                      search placeholder, copy button). Auto-detects zh-CN vs en
#                      from CJK character density when omitted.
#   --project <name>   Scaffold directory name (cosmetic; never used as title).
#
# Notes:
#  - The source .md is only ever READ. It is never modified.
#  - The document is embedded verbatim as a JSON string, so escaping is exact.

set -e

INPUT=""
TITLE=""
LANG_CODE=""
PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title)   TITLE="$2"; shift 2 ;;
    --lang)    LANG_CODE="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    -h|--help)
      sed -n '10,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "❌ Unknown option: $1"; exit 1 ;;
    *)  if [ -z "$INPUT" ]; then INPUT="$1"; else echo "❌ Unexpected argument: $1"; exit 1; fi; shift ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "❌ Usage: md-to-html.sh <input.md> [--title <text>] [--lang <code>]"
  exit 1
fi
if [ ! -f "$INPUT" ]; then
  echo "❌ Error: input file not found: $INPUT"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SKILL_DIR/templates/markdown-doc"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Error: template missing at $TEMPLATE_DIR"
  exit 1
fi

# [LOCAL ADDITION 2026-10-30] Resolve a Python 3 interpreter portably.
# `python3` cannot be assumed: python.org's Windows installer only provides
# `python.exe` and `py.exe`, and the Microsoft Store App Execution Alias creates
# a `python3.exe` stub that "exists" but exits non-zero. So probe each candidate
# by actually running it, and reject anything that is not Python 3.
PYTHON=""
for candidate in python3 python py; do
  if command -v "$candidate" > /dev/null 2>&1 &&
     "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' > /dev/null 2>&1; then
    PYTHON="$candidate"
    break
  fi
done
if [ -z "$PYTHON" ]; then
  echo "❌ Error: no working Python 3 interpreter found (tried: python3, python, py)"
  exit 1
fi

INPUT_ABS="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
BASE="$(basename "$INPUT" .md)"
OUT_HTML="$(dirname "$INPUT_ABS")/$BASE.html"

# Build in a throwaway temp dir, NOT in the caller's cwd and NOT inside the
# skill directory. Scaffolding in place would litter wherever the user happened
# to be (e.g. inside ~/.agents/skills/), leaving pnpm build artifacts behind.
# Set HAB_KEEP_BUILD=1 to preserve it for debugging.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/html-artifact-build.XXXXXX")"
cleanup() {
  if [ "${HAB_KEEP_BUILD:-0}" = "1" ]; then
    echo "ℹ️  Build dir kept: $WORK_DIR"
  else
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

PROJECT="${PROJECT:-$BASE}"

echo "📄 Input  : $INPUT_ABS"

# 1. Scaffold with the normal init flow (inside the temp workspace).
cd "$WORK_DIR"
bash "$SCRIPT_DIR/init-artifact.sh" "$PROJECT" > /dev/null
cd "$WORK_DIR/$PROJECT"

# 2. Extra deps for rendering + highlighting (hljs core + only the languages used).
pnpm add marked highlight.js > /dev/null
pnpm add -D @types/node > /dev/null

# 3. Copy the document component and theme.
mkdir -p src/components
cp "$TEMPLATE_DIR/MarkdownDocument.tsx" src/components/MarkdownDocument.tsx
cat "$TEMPLATE_DIR/doc-typo.css" "$TEMPLATE_DIR/code-theme.css" >> src/index.css

# 4. Embed the Markdown verbatim, and resolve <title>/<html lang> from content.
#    When --title is omitted we fall back to the document's H1 — never the
#    scaffold directory name, which is a throwaway build detail.
TITLE_OUT=$("$PYTHON" - "$INPUT_ABS" "$TITLE" "$LANG_CODE" <<'PY'
import json, re, sys, pathlib

src = pathlib.Path(sys.argv[1])
title_arg = sys.argv[2].strip()
lang_arg = sys.argv[3].strip()

text = src.read_text(encoding='utf-8')

# First ATX H1 outside a fenced code block.
h1 = None
in_fence = False
for line in text.split('\n'):
    if re.match(r'^\s*```', line):
        in_fence = not in_fence
        continue
    if not in_fence:
        m = re.match(r'^#\s+(.*)$', line)
        if m:
            h1 = m.group(1).strip()
            break

title = title_arg or h1 or src.stem

# Strip light Markdown emphasis so the tab title stays clean.
title = re.sub(r'[*_`]', '', title).strip()

if lang_arg:
    lang = lang_arg
else:
    cjk = len(re.findall(r'[\u4e00-\u9fff]', text))
    lang = 'zh-CN' if cjk > 20 else 'en'

# Rewrite the head. Operate on the <html ...> start tag only: splitting the
# whole document on ">" would land on "<!doctype html>" and mis-detect whether
# lang is already present, which previously emitted a duplicate lang attribute.
html = pathlib.Path('index.html').read_text(encoding='utf-8')

# The resolved lang drives BOTH <html lang> and the component's UI chrome
# (TOC label, search placeholder, copy button), so an English document does not
# get a Chinese sidebar.
pathlib.Path('src/content.ts').write_text(
    f"// Generated verbatim from {src.name} (read-only source, never modified).\n"
    "export const RAW_MARKDOWN = " + json.dumps(text, ensure_ascii=False) + "\n"
    "export const DOC_LANG = " + json.dumps(lang) + "\n",
    encoding='utf-8')

safe_title = title.replace('&', '&amp;').replace('<', '&lt;')
if re.search(r'<title>.*?</title>', html, flags=re.S):
    html = re.sub(r'<title>.*?</title>', '<title>' + safe_title + '</title>', html, count=1, flags=re.S)
else:
    html = html.replace('</head>', '  <title>' + safe_title + '</title>\n  </head>', 1)

m = re.search(r'<html\b[^>]*>', html)
if m:
    tag = m.group(0)
    if re.search(r'\blang="[^"]*"', tag):
        new_tag = re.sub(r'\blang="[^"]*"', f'lang="{lang}"', tag, count=1)
    else:
        new_tag = tag.replace('<html', f'<html lang="{lang}"', 1)
    html = html[:m.start()] + new_tag + html[m.end():]
else:
    html = html.replace('<!doctype html>', f'<!doctype html>\n<html lang="{lang}">', 1)

pathlib.Path('index.html').write_text(html, encoding='utf-8')

print(f"{title}\t{lang}")
PY
)
TITLE_RESOLVED="${TITLE_OUT%%$'\t'*}"
LANG_RESOLVED="${TITLE_OUT##*$'\t'}"
echo "🏷  Title  : $TITLE_RESOLVED"
echo "🌐 Lang   : $LANG_RESOLVED"

# 5. Point App.tsx at the component, passing the resolved lang so the UI chrome
#    (TOC label, search placeholder, copy button) matches the document.
cat > src/App.tsx <<'EOF'
import MarkdownDocument from '@/components/MarkdownDocument'
import { RAW_MARKDOWN, DOC_LANG } from './content'

export default function App() {
  return <MarkdownDocument source={RAW_MARKDOWN} lang={DOC_LANG} />
}
EOF

# 6. Build the single file and copy it next to the source.
#    No dark-mode rewrite is needed: init-artifact.sh emits a <html> tag with no
#    class="dark", which is what the GitHub-light code palette expects.
pnpm install > /dev/null
pnpm exec vite build > /dev/null
cp dist/index.html "$OUT_HTML"

SIZE=$(du -h "$OUT_HTML" | cut -f1)
BUNDLED_TITLE=$(grep -o '<title>[^<]*</title>' "$OUT_HTML" | head -1)
echo ""
echo "✅ Rendered: $OUT_HTML ($SIZE)"
echo "   $BUNDLED_TITLE"
echo "   Source untouched: $INPUT_ABS"
