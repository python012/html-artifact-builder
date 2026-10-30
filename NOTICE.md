# NOTICE

This distribution is based on work by Anthropic, PBC.

## Upstream

- **Project**: `web-artifacts-builder`, part of [`anthropics/skills`](https://github.com/anthropics/skills)
- **License**: Apache License 2.0 (see `LICENSE.txt`)
- **Copyright**: Copyright 2026 Anthropic, PBC.

## What was changed (Apache License 2.0, Section 4(b))

This is a **modified** version. Files that differ from upstream carry a
`MODIFIED FILE NOTICE` comment at the top, or a `[LOCAL ...]` marker in scripts.
Summary of changes:

| File | Change |
|---|---|
| `scripts/init-artifact.sh` | **Rewritten.** Scaffolding now uses Vite instead of the upstream Parcel + html-inline flow. Template demo images are deleted rather than left in `src/assets`. |
| `scripts/bundle-artifact.sh` | **Rewritten.** Uses `vite-plugin-singlefile` and verifies self-containment (exits non-zero on root-relative refs or import-maps). |
| `scripts/md-to-html.sh` | **New.** Renders a Markdown file as a single self-contained HTML document. |
| `templates/markdown-doc/*` | **New.** Markdown renderer component plus document and code themes. |
| `SKILL.md` | Rewritten to match the above; upstream description replaced. |
| `README.md` | **New.** User-facing documentation, including the non-affiliation statement. |
| `README.zh-CN.md` | **New.** Chinese translation of `README.md`. |
| `NOTICE.md` | **New.** This file. |
| `licenses/shadcn-ui-MIT.txt` | **New.** MIT text for the bundled shadcn/ui components. |
| `samples/sample-doc.md`, `samples/sample-doc-en.md` | **New.** Regression fixtures covering every renderer feature, in Chinese and English, plus their rendered single-file output (`samples/*.html`). |
| `ISSUES.md` | **New.** Known-issue tracker for this distribution. |
| `.gitignore` | **New.** Ignores build output, generated bundles and maintainer notes. |

### Why Parcel was replaced

Upstream bundles with Parcel. Parcel 2.16 cannot resolve the nested
`development` / `production` export conditions used by
`@radix-ui/primitive@1.2.0`, so every shadcn/ui component failed at build time:

```
@parcel/resolver-default: Cannot load file './is-development'
from module '@radix-ui/primitive'
```

This was verified as unfixable via `targets` configuration, version pinning, and
`pnpm.overrides`. The switch to Vite resolves it and additionally produces a
genuinely single-file output.

## Third-party components

`scripts/shadcn-components.tar.gz` contains shadcn/ui component source.

- **Project**: [`shadcn-ui/ui`](https://github.com/shadcn-ui/ui)
- **License**: MIT — full text in `licenses/shadcn-ui-MIT.txt`
- **Copyright**: Copyright (c) 2023 shadcn

The upstream tarball ships these files without per-file copyright headers. The
MIT license text is therefore included separately in `licenses/` to satisfy the
MIT condition that the copyright and permission notice accompany copies.

## Trademarks

The Apache License 2.0 does not grant permission to use the trade names or
trademarks of the Licensor (Section 6). This project is **not** an official
Anthropic release and is not endorsed by Anthropic. The upstream project is
referenced only to describe origin, as permitted.
