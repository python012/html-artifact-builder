---
name: html-artifact-builder
description: Build a single self-contained HTML file with modern frontend tech (React + TypeScript + Vite + Tailwind CSS + shadcn/ui). Use when a deliverable needs far more expressive power than Markdown - interactive tabs, accordions, charts, rich layout, state management. Output is ONE .html file with everything inlined and no external references.
license: Complete terms in LICENSE.txt
---

# HTML Artifacts Builder

Build a **single, self-contained HTML file** that far outclasses Markdown in
expressiveness. No server, no sharing required — just open the file.

> **Local variant (2026-10-30).** This copy diverges from the upstream
> Anthropic skill on purpose:
> - Bundling uses **Vite + vite-plugin-singlefile** instead of Parcel.
>   Parcel 2.16 cannot resolve `@radix-ui/primitive@1.2.0`'s nested
>   `development`/`production` export conditions, which broke every shadcn/ui
>   component (`Cannot load file './is-development'`). Verified unfixable via
>   `targets`, version pinning, and pnpm overrides.
> - Template demo images are **deleted**, not just hidden. Upstream left
>   `hero.png` / `react.svg` / `vite.svg` in `src/assets`, which turned into
>   `/assets/*.png` refs in the output and broke self-containment.
> - `bundle-artifact.sh` **verifies** self-containment and fails loudly.
> - Added `scripts/md-to-html.sh` + `templates/markdown-doc/` for rendering an
>   existing Markdown file as a browsing-friendly single-page HTML document,
>   with light GitHub-style syntax highlighting (highlight.js, offline).

## Stack

React 18 + TypeScript + Vite + Tailwind CSS 3.4.1 + shadcn/ui (43 components) + lucide-react

## Platform

The scripts are **bash**. Run them with `bash scripts/<name>.sh …` — never
paste them into PowerShell or `cmd`, where `bash` may not resolve.

| Host | How to run |
|---|---|
| macOS / Linux | Native shell |
| Windows | **Git for Windows → Git Bash**, or WSL. Not PowerShell, not `cmd` |
| Python | Resolved automatically: `python3` → `python` → `py` (Python 3 only) |

Never hardcode `python3` in a new script: on Windows a python.org install only
provides `python.exe` / `py.exe`, and the Microsoft Store alias leaves a
`python3.exe` stub that exists but fails. Probe with
`"$cmd" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)'`.


## Quick Start — the main path (React)

Compose the page in React, then bundle it to one file. Use the Markdown renderer
further down only when the content already exists as a `.md`.

### Step 1 — Initialize

```bash
bash scripts/init-artifact.sh <project-name>
cd <project-name>
```

Creates a configured project with:
- React + TypeScript via Vite, `@/` path aliases wired for both Vite and `tsc`
- Tailwind 3.4.1 with the full shadcn/ui CSS-variable theme (light + dark)
- 43 shadcn/ui components in `src/components/ui/`, all Radix deps installed
- `vite-plugin-singlefile` configured, `assetsInlineLimit` raised so assets inline
- A smoke build, so you know the scaffold works before writing any code

### Step 2 — Build

Edit `src/App.tsx`. Import components:

```tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Button } from '@/components/ui/button'
import { Copy, Check } from 'lucide-react'
```

Optional live preview while developing:

```bash
pnpm dev
```

### Step 3 — Bundle to one file

```bash
bash scripts/bundle-artifact.sh
```

Produces `bundle.html` — one file, everything inlined. The script then runs a
self-containment check and reports:

```
✅ Self-contained: no root-relative refs, no import-maps.
```

If it prints ⚠️ instead, something leaked out as an external reference; fix it
before shipping the file.

### Step 4 — Open it

```bash
open bundle.html        # macOS
start bundle.html       # Windows (cmd / PowerShell)
xdg-open bundle.html    # Linux
```

No artifact renderer is needed — it is a plain file you can double-click.

## Rendering an existing Markdown file

When the content already exists as Markdown and you would rather not design a
page by hand, use the bundled renderer instead of building one in React:

```bash
bash scripts/md-to-html.sh path/to/doc.md [--title "Tab title"] [--lang zh-CN]
```

The document title in the page header is also a button: clicking it hides or
shows the left-hand contents sidebar, for when the text needs the full width.

### Set the browser-tab title deliberately

Markdown has **no title metadata** — the H1 is a document heading, not a tab
label. The scaffold directory name is a throwaway build detail and reads badly
in a browser tab (this skill previously shipped `<title>testdoc</title>` and
`<title>v1</title>`). So:

**Choose `--title` yourself.** Read the document, then write a short,
human-readable name — ideally "topic · specific focus" rather than the raw H1,
which is usually too long for a tab and carries dates/emoji.

| Document | Avoid (raw H1) | Prefer (`--title`) |
|---|---|---|
| `samples/sample-doc.md` | `冒烟样本 · 全特性覆盖` | `冒烟样本 · 全特性` |
| Release notes | `Release notes · bundler moved from Parcel to Vite, and what broke` | `Release notes · Parcel to Vite` |

Resolution order when `--title` is omitted: **first H1 → filename stem**.
`--lang` follows the same idea: pass it explicitly, or it auto-detects `zh-CN`
vs `en` from CJK character density. It drives **both** `<html lang>` and the UI
chrome (TOC label, search placeholder, copy button), so an English document does
not get a Chinese sidebar.

Ready-made regression fixtures live in `samples/`: `sample-doc.md` (Chinese)
and `sample-doc-en.md` (English), each with its rendered `.html` next to it. They
cover wide tables, tagged and untagged fences, `## ` inside a fence, all five
callout kinds, task lists and inline code. Render it and eyeball the result after any
change to the renderer:

```bash
bash scripts/md-to-html.sh samples/sample-doc.md --title "冒烟样本 · 全特性"
```

It writes `doc.html` next to the source and **never modifies the source**. You get:
- sticky sidebar TOC with scroll-spy, full-text search
- **light GitHub-style code blocks** with real syntax highlighting
  (highlight.js, registered per-language and bundled — no CDN)
- language chips + one-click copy on every code block
- callouts inferred from blockquote lead emoji (⚠️ warn / 🔴 danger / ✅ ok / 👉 tip / 📌 note)
- `## `-inside-fenced-code is ignored, so embedded README templates don't
  become phantom TOC entries — **provided the fences are written correctly**.
  CommonMark closes a fence at the first *bare* fence of the same character and
  at least the same length, so a ` ``` ` nested inside a ` ``` ` block closes
  the outer block early: the rest of the document renders as body text, and any
  `## ` left behind becomes a real heading. Write the outer block in **four**
  backticks (` ````markdown ` … ` ```` `) and keep the inner block at three.

### Fence preflight

That early-close shape renders correctly per CommonMark — GitHub (cmark-gfm) and
`marked` agree — so it is not a renderer bug and nothing in the pipeline used to
flag it. `scripts/check-md-fences.py` runs **before any install**, reports the
opening line, the nested line and the line that actually closes the block, and
lets the render continue:

```
⚠️  Fence  : doc.md 第 11 行 ```markdown 内有嵌套 fence（第 16 行 ```bash）
       →   实际闭合于第 18 行，其后的内容会被当成正文渲染
       →   修法：外层改用 4 个反引号（````markdown … ````），或把内部 fence 缩进 4 空格
ℹ️  渲染继续；加 --strict-fences 可让此情况直接失败
```

`--strict-fences` turns the warning into a non-zero exit — and because the
preflight sits before `pnpm`, a broken document fails in about 0.1 s instead of
after a two-minute install.

Implementation lives in `templates/markdown-doc/`:
`MarkdownDocument.tsx` (component), `doc-typo.css` (document typography),
`code-theme.css` (GitHub Light token palette).

**Code colouring is opt-in by design.** A plain shadcn `Card` full of `<pre>`
renders code on a dark background with no token colours. If you build a page by
hand and want the GitHub look, `@import`/append `code-theme.css` and run each
block through `highlight.js` — adding the CSS alone gives you an unstyled block,
because highlight.js is what emits the `<span class="hljs-*">` tokens.

## Keeping the bundle self-contained

The single biggest cause of breakage is **referencing a file by absolute path**.
Rules that actually matter:

| Do | Don't |
|---|---|
| Inline SVG (paste the markup or use `lucide-react` icons) | Import `.png` / `.jpg` / `.svg` from `src/assets` |
| Use CSS gradients, borders, and shapes for decoration | Reference `/images/foo.png` |
| Use system fonts or web-safe font stacks | Load Google Fonts via `<link>` |
| Keep data as inline TS objects | `fetch()` a local JSON file |

`lucide-react` icons compile into inline SVG, so they add zero external requests.
The scaffolded `<html>` carries **no** `class="dark"`: the light theme is the
default, which is what the Markdown renderer's GitHub-light code palette assumes.
Use theme tokens (`bg-background`, `text-foreground`, `text-muted-foreground`)
instead of hardcoded colours — `text-slate-100` on a light `bg-card` produces
invisible white-on-white text, and `bg-slate-950` fights the light document page.

## Design Guidelines

Avoid what reads as "AI slop": excessive centered layouts, purple gradients,
uniform rounded corners, and the Inter font. Prefer a deliberate palette, real
information density, and semantic use of color (e.g. green for pass, amber for
below target).

## Reference

- shadcn/ui components: https://ui.shadcn.com/docs/components
- Tailwind CSS: https://tailwindcss.com/docs
