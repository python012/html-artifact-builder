# Smoke test · every renderer feature

This file exists for one reason: to exercise **every** renderer feature in a
single document, so a change can be re-checked in one pass. It deliberately
contains English prose, a wide table, tagged and untagged fences, `## ` inside a
fence, all five callout kinds, task lists, inline code and an anchor link.

> 📌 This blockquote starts with 📌, so it should render as a grey "note"
> callout rather than a plain quote.

## Quick start

From the skill directory, run this. The output lands next to the source and the
source itself is never modified:

```bash
bash scripts/md-to-html.sh samples/sample-doc-en.md --title "Smoke test · all features"
```

`--title` sets the browser-tab text; `--lang` sets both `<html lang>` and the
language of the UI chrome. Jump to [Callouts](#callouts) to check anchors and
scroll positioning.

## Feature coverage

| # | Feature | Triggered by | Expected | Note |
|---|---|---|---|---|
| 1 | Sidebar TOC | Every `##` heading | Left column lists sections, highlight follows scroll | Count must equal the number of `##` headings |
| 2 | Full-text search | Typing in the header box | Dropdown of matching sections with a snippet, click to jump | Searches sections, not the whole page |
| 3 | Syntax highlighting | Fence tagged `bash` / `ts` / `json` | GitHub-light token colours | Needs highlight.js, not CSS alone |
| 4 | Auto-detection | Fence with no language | Language guessed and coloured | Falls back to `text` |
| 5 | Copy button | Top-right of every block | Label flips to "Copied" for 1.4 s | Copies plain source, not HTML |
| 6 | Callouts | Blockquote starting with an emoji | ⚠️ amber / 🔴 rose / ✅ emerald / 👉 sky / 📌 slate | Anything else stays a normal quote |
| 7 | Headings inside fences | A `## xxx` line in code | Must **not** appear in the TOC | The regression this fixture exists for |
| 8 | Wide tables | Many columns, long cells | Cells wrap, page does not overflow | First column stays on one line |
| 9 | Task lists | `- [ ]` / `- [x]` | Checkbox rendered, bullet removed | Rendered by GFM |
| 10 | Inline code | Backticks | Grey background, monospace | Different from a code block |

## Code blocks: tagged

### Bash

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:?usage: md-to-html.sh <input.md>}"
TITLE="${2:-}"

echo "rendering $INPUT"
grep -c 'importmap' out.html || true
```

### TypeScript

```ts
type Section = { id: string; title: string; md: string }

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fa5]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 60) || 'section'
}

const sections: Section[] = [{ id: slugify('Overview'), title: 'Overview', md: '' }]
console.log(sections.length)
```

### JSON

```json
{
  "name": "html-artifact-builder",
  "selfContained": true,
  "externalRequests": 0,
  "features": ["toc", "search", "highlight", "copy", "callouts"]
}
```

### Python

```python
import json, pathlib

def embed(md_path: str) -> str:
    text = pathlib.Path(md_path).read_text(encoding="utf-8")
    return "export const RAW_MARKDOWN = " + json.dumps(text, ensure_ascii=False)

print(embed("samples/sample-doc-en.md")[:40])
```

## Code blocks: untagged

The fence below has no language on purpose, to exercise highlight.js
auto-detection:

```
interface BuildOptions {
  singleFile: boolean
  inlineAssets: boolean
}

function bundle(opts: BuildOptions): string {
  return opts.singleFile ? 'bundle.html' : 'dist/index.html'
}
```

## A `##` inside a fence must not become a TOC entry

The fence below contains two lines starting with `## `. If they show up in the
sidebar, the fence tracking is broken:

```markdown
# An embedded README template

## Installation
Copy the directory into ~/.agents/skills/ and you are done.

## Usage
bash scripts/md-to-html.sh doc.md
```

That is the end of the fence. Both `##` lines above are code, not sections.

## Callouts

> ⚠️ Warning: the build directory lives in `mktemp -d` and is removed on exit. Set `HAB_KEEP_BUILD=1` to keep it for debugging.

> 🔴 Danger: do not switch the bundler back to Parcel 2.16. It cannot resolve the nested export conditions of `@radix-ui/primitive@1.2.0`, and every shadcn/ui component fails to build.

> ✅ OK: on success `bundle-artifact.sh` prints `✅ Self-contained`, with **zero** external references.

> 👉 Tip: pick `--title` yourself. An H1 usually carries a date and an emoji, which makes a poor browser-tab label.

> 📌 Note: a blockquote without a leading emoji keeps the plain quote styling, like this one.

> This one has no emoji prefix at all and must **not** become a callout.

## Lists, tasks and details

- First level
  - Second level, with inline code `RAW_MARKDOWN`
    - Third level, to check indentation and marker colour
- Another top-level item

- [x] TOC generation
- [x] Search hits
- [ ] To confirm: the UI chrome switches to English
- [ ] To confirm: the copy button label flips back

<details>
<summary>Collapsed block (open it)</summary>

Code works inside too:

```text
plain text block, the language chip should read "text"
```

</details>

---

## Wrapping up

That covers every feature. When re-checking after a change, look at three things:

1. The TOC count equals the number of `##` headings in this file (fences excluded).
2. Every code block has a language chip and a copy button, and its tokens are coloured.
3. The page makes no network requests.
