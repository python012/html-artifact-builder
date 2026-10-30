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

---

## 3. Windows: a non-ASCII or spaced source filename becomes the scaffold directory name

**Status**: open · recorded 2026-10-30 · not reproducible here (no Windows host); reasoned from the code path

**Impact**: on `md-to-html.sh`, the rendered `.html` may be produced correctly or
the build may fail at the `pnpm create vite` step, depending on the console
codepage. The failure mode is confusing: either a Chinese-garbled directory name,
or `create-vite` rejecting an invalid npm package name.

**Cause**: `PROJECT="${PROJECT:-$BASE}"` reuses the Markdown basename as the
Vite project directory inside the temp workspace. Two things follow:

1. On Windows the argv of a native `.exe` (`pnpm`, `node`) is converted from
   UTF-8 by msys, but the console codepage (typically GBK / 936) is what the
   native side decodes with, so CJK path components can be mangled.
2. `create-vite` validates the directory name as an npm package name
   (`^[a-z0-9-~][a-z0-9-._~]*$`); CJK and spaces are invalid, which can send it
   into an interactive prompt — fatal for a non-interactive agent run.

macOS is unaffected in practice (UTF-8 everywhere), which is why the fixtures
with names like `day-2-今日行动清单-2026-10-22.md` work.

**Workaround**: pass an explicit ASCII name:

```bash
bash scripts/md-to-html.sh "今日行动清单.md" --project doc-build --title "今日行动"
```

`--project` only names the throwaway scaffold directory, never the `<title>`.

**Options**

1. Sanitise internally: slugify `PROJECT` to ASCII (`sed`/`tr` to `[a-z0-9-]`,
   fall back to `doc`), and never expose the raw filename to `create-vite`.
   Fixes it for every host, no user action.
2. Document `--project` in both READMEs and rely on the caller.
3. Both: sanitise as a safety net, and document the flag.

Recommendation: option 3. Option 1 alone removes the need to know about the flag.

---

## 4. Windows: long-path limit on the temp build directory

**Status**: open · recorded 2026-10-30 · not reproducible here; structural risk

**Impact**: `md-to-html.sh` scaffolds and builds inside
`mktemp -d "${TMPDIR:-/tmp}/html-artifact-build.XXXXXX"`. On Windows the temp
root is already deep (`C:\Users\<name>\AppData\Local\Temp`), and a Vite + React +
Radix `node_modules` tree adds a long nesting on top. The classic 260-character
`MAX_PATH` ceiling is reachable, at which point `pnpm install` or `vite build`
fails with `ENAMETOOLONG` / `EPERM` rather than anything self-explanatory.

**Workaround**: point the build at a short root before running —

```bash
TMPDIR=/c/t bash scripts/md-to-html.sh doc.md    # Git Bash
```

or enable Windows long paths (`LongPathsEnabled`) / `git config --system
core.longpaths true`. Neither is obvious to a user hitting the error.

**Options**

1. Use a short deterministic root instead of `TMPDIR` when it looks long
   (e.g. `${TMPDIR:-/tmp}` truncated, or a fixed `C:\hab-build` on Windows).
2. Detect the failure and re-print an actionable hint.
3. Document the `TMPDIR` override.

Recommendation: option 2 (cheap, keeps cwd clean and stays out of the user's
filesystem choices), plus option 3.

---

## 5. Windows: `npm install -g pnpm` does not refresh PATH for the running shell

**Status**: open · recorded 2026-10-30 · reasoned, not reproduced

**Impact**: `init-artifact.sh` installs pnpm on demand and then immediately runs
`pnpm create vite`. If the global npm bin directory was not already on `PATH` in
the current shell (common on Windows when Node was installed for the current
user only), the just-installed `pnpm` is not found and the script dies at the
next command with `pnpm: command not found`.

**Workaround**: install pnpm in a separate shell first
(`npm install -g pnpm`), then run the script.

**Options**

1. Re-check `command -v pnpm` after installing and, if still missing, stop with
   an explicit "open a new shell and re-run" message instead of a bare
   not-found error.
2. Call pnpm through `npx --yes pnpm` for the remainder of the script.
3. Use `corepack enable` (ships with Node) instead of a global npm install.

Recommendation: option 1 — it turns a confusing failure into an instruction, and
does not change how pnpm is invoked.
