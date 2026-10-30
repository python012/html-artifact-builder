# Open issues

Known problems that are recorded but not fixed yet. Each entry is written so it
can be pasted into a GitHub issue verbatim.

---

## 1. `pnpm build` fails: two bundled shadcn/ui components drift from the installed dependency majors

**Status**: open · recorded 2026-10-30 · found while validating a fresh scaffold

**Impact**: on a freshly scaffolded project, `tsc -b` — and therefore
`pnpm build`, plus editor diagnostics — fails. `vite build`, which is what
`init-artifact.sh` and `bundle-artifact.sh` actually run, still succeeds, so
bundling works. Runtime breaks only if the page imports `calendar` or
`resizable`.

**Cause**: `scripts/init-artifact.sh` installs these two packages without a
version bound, so the latest major is pulled in, while the bundled component
sources target the older API:

| Component | Code expects | Installed (2026-10-30) | Error |
|---|---|---|---|
| `src/components/ui/calendar.tsx` | `react-day-picker` v8 (`classNames.table`) | `react-day-picker@10.0.2` | `TS2353: 'table' does not exist in type 'Partial<ClassNames>'` |
| `src/components/ui/resizable.tsx` | `react-resizable-panels` v2 (`PanelGroup`, `PanelResizeHandle`) | `react-resizable-panels@4.15.2` | `TS2339: Property 'PanelGroup' / 'PanelResizeHandle' does not exist` |

`calendar.tsx` targets `react-day-picker` v8; the replacement key in v9+ is
`month_grid`. `resizable.tsx` targets v2; v4 renamed the exports to `Group` /
`Separator`.

**Reproduce**:

```bash
cd /tmp && rm -rf t && mkdir t && cd t
bash <this-skill>/scripts/init-artifact.sh sample
cd sample && pnpm exec tsc -b        # exits non-zero
```

**Workaround**: build with `vite build` (what the scripts do), and avoid
importing `calendar` / `resizable` until this is resolved.

**Options**

1. Pin the two packages in `init-artifact.sh` to `react-day-picker@^8.10.1` and
   `react-resizable-panels@^2.1.7`. Smallest change; but `react-day-picker` v8
   does not list React 19 in its peer range, so pnpm will warn.
2. Update those two component sources to the new APIs (`month_grid`, `Group`,
   `Separator`) and repack `scripts/shadcn-components.tar.gz`. Correct
   long-term fix; effectively the "repackage from `shadcn-ui/ui` with copyright
   headers" item already noted in `NOTICE.md`.
3. Leave as is and document the limitation.

Recommendation: option 2, bundled with a fresh repack of the component tarball.

---

## 2. `<title>`-derived page header shows the raw H1

The sticky header prints the document's first H1 verbatim, which often carries a
date and emoji (`冒烟样本 · 2026-10-30（周五）· 全特性覆盖`). The browser tab gets
the deliberate `--title`, but the on-page header does not.

**Status**: open · cosmetic

**Options**: use `--title` for the header too, or add a `--header` option.
