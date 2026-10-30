/* ---------------------------------------------------------------------------
 * MODIFIED FILE NOTICE (Apache License 2.0, Section 4(b))
 * Newly added in this distribution; not present in the upstream
 * anthropics/skills web-artifacts-builder. See NOTICE.md for details.
 * ------------------------------------------------------------------------- */
import { useMemo, useState, useEffect, useRef, useCallback } from 'react'
import { PanelLeftClose, PanelLeftOpen } from 'lucide-react'
import { marked } from 'marked'
import hljs from 'highlight.js/lib/core'
import bash from 'highlight.js/lib/languages/bash'
import python from 'highlight.js/lib/languages/python'
import yaml from 'highlight.js/lib/languages/yaml'
import ini from 'highlight.js/lib/languages/ini'
import json from 'highlight.js/lib/languages/json'
import typescript from 'highlight.js/lib/languages/typescript'
import javascript from 'highlight.js/lib/languages/javascript'
import markdown from 'highlight.js/lib/languages/markdown'
import plaintext from 'highlight.js/lib/languages/plaintext'

/* ===========================================================================
 * MarkdownDocument — render a Markdown file as a single-page HTML document.
 *
 * What it adds over a plain Markdown viewer:
 *   - sticky sidebar TOC with scroll-spy
 *   - full-text search across sections
 *   - GitHub-light syntax highlighting (highlight.js, offline)
 *   - per-block copy buttons, language chips
 *   - callouts derived from blockquote lead emoji (⚠️ 🔴 ✅ 👉 📌)
 *
 * Usage: put the Markdown source into src/content.ts as
 *        `export const RAW_MARKDOWN = "..."` and pass it to this component.
 * =========================================================================== */

const LANGS: Record<string, any> = {
  bash, sh: bash, shell: bash, zsh: bash,
  python, py: python,
  yaml, yml: yaml,
  ini, toml: ini,
  json,
  typescript, ts: typescript, tsx: typescript,
  javascript, js: javascript, jsx: javascript,
  markdown, md: markdown,
  text: plaintext, plaintext,
}
for (const [name, lang] of Object.entries(LANGS)) hljs.registerLanguage(name, lang)

marked.setOptions({ gfm: true, breaks: false })

/* UI chrome is localised. `--lang` in md-to-html.sh resolves once and is passed
 * in as `lang`, so the sidebar and buttons match the document instead of always
 * being Chinese. Without `lang` the CJK density of the source decides. */
export type Labels = {
  overview: string
  copy: string
  copied: string
  search: string
  toc: (n: number) => string
  footer: (n: number) => string
  hideNav: string
  showNav: string
}

const LABELS: Record<'zh' | 'en', Labels> = {
  zh: {
    overview: '概览',
    copy: '复制',
    copied: '已复制',
    search: '搜索本文…',
    toc: (n) => `目录 · ${n} 节`,
    footer: (n) => `由 ${n} 个章节渲染 · 源文件逐字保真，未改动`,
    hideNav: '隐藏目录栏',
    showNav: '显示目录栏',
  },
  en: {
    overview: 'Overview',
    copy: 'Copy',
    copied: 'Copied',
    search: 'Search this document…',
    toc: (n) => `Contents · ${n} sections`,
    footer: (n) => `Rendered from ${n} sections · source verbatim, never modified`,
    hideNav: 'Hide contents',
    showNav: 'Show contents',
  },
}

function resolveLabels(source: string, lang?: string): Labels {
  const cjk = source.match(/[\u4e00-\u9fff]/g)?.length ?? 0
  const base = (lang?.trim() || (cjk > 20 ? 'zh' : 'en')).toLowerCase()
  return base.startsWith('zh') ? LABELS.zh : LABELS.en
}

type Section = { id: string; title: string; md: string }

const slug = (s: string) =>
  s.toLowerCase().replace(/[^\w\u4e00-\u9fa5]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'section'

/**
 * Split on H2 headings, but ignore "## " inside fenced code blocks — a README
 * template embedded in a code fence otherwise becomes phantom TOC entries.
 */
export function splitSections(md: string, overviewLabel = '概览'): Section[] {
  const out: Section[] = []
  let title = overviewLabel
  let buf: string[] = []
  let inFence = false
  const flush = () => {
    if (buf.join('\n').trim()) out.push({ id: slug(title), title, md: buf.join('\n') })
  }
  for (const line of md.split('\n')) {
    if (/^\s*```/.test(line)) inFence = !inFence
    const h2 = !inFence && /^##\s+(.*)$/.exec(line)
    if (h2) {
      flush()
      title = h2[1].trim()
      buf = []
    } else if (!(out.length === 0 && buf.length === 0 && /^#\s/.test(line))) {
      buf.push(line)
    }
  }
  flush()
  const seen = new Map<string, number>()
  return out.map((s) => {
    const n = seen.get(s.id) ?? 0
    seen.set(s.id, n + 1)
    return n === 0 ? s : { ...s, id: `${s.id}-${n}` }
  })
}

function calloutKind(text: string): string {
  const t = text.trimStart()
  if (/^⚠️/.test(t)) return 'warn'
  if (/^🔴/.test(t)) return 'danger'
  if (/^✅/.test(t)) return 'ok'
  if (/^👉/.test(t)) return 'tip'
  if (/^📌|^⏸/.test(t)) return 'note'
  return ''
}

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

let codeSeq = 0

/** Post-process marked's HTML: callouts, highlighted copyable code blocks. */
export function transformHtml(html: string, labels: Labels = LABELS.zh): string {
  html = html.replace(/<blockquote>([\s\S]*?)<\/blockquote>/g, (m, inner: string) => {
    const kind = calloutKind(inner.replace(/<[^>]+>/g, ''))
    return kind ? `<blockquote class="callout callout-${kind}">${inner}</blockquote>` : m
  })

  html = html.replace(
    /<pre><code(?: class="language-([\w-]+)")?>([\s\S]*?)<\/code><\/pre>/g,
    (_m, lang: string | undefined, codeHtml: string) => {
      const raw = codeHtml
        .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&')
      // Untagged fences are common (output snippets). Auto-detect so they get
      // colour too, rather than rendering as flat text.
      let label = (lang || '').toLowerCase()
      let inner = esc(raw)
      if (label && hljs.getLanguage(label)) {
        try {
          inner = hljs.highlight(raw, { language: label, ignoreIllegals: true }).value
        } catch { /* escaped text is a fine fallback */ }
      } else if (!label) {
        try {
          const auto = hljs.highlightAuto(raw, Object.keys(LANGS))
          inner = auto.value
          label = auto.language || 'text'
        } catch {
          label = 'text'
        }
      }
      if (!label) label = 'text'
      const id = `code-${++codeSeq}`
      return (
        `<div class="codeblock">` +
        `<div class="codeblock-bar">` +
        `<span class="codeblock-lang">${esc(label)}</span>` +
        `<button class="codeblock-copy" data-copy="${id}" type="button">${esc(labels.copy)}</button>` +
        `</div>` +
        `<pre><code id="${id}" class="hljs language-${esc(label)}">${inner}</code></pre>` +
        `</div>`
      )
    },
  )
  return html
}

export default function MarkdownDocument({ source, lang }: { source: string; lang?: string }) {
  const labels = useMemo(() => resolveLabels(source, lang), [source, lang])
  const sections = useMemo(() => splitSections(source, labels.overview), [source, labels])
  const [activeId, setActiveId] = useState(sections[0]?.id ?? '')
  const [query, setQuery] = useState('')
  // The document title in the header doubles as the sidebar toggle, so narrow
  // screens and narrow reading tasks both get a way to reclaim the width.
  const [navOpen, setNavOpen] = useState(true)
  const bodyRef = useRef<HTMLDivElement>(null)

  const rendered = useMemo(() => {
    codeSeq = 0
    return sections.map((s) => ({ ...s, html: transformHtml(marked.parse(s.md) as string, labels) }))
  }, [sections, labels])

  useEffect(() => {
    const els = sections.map((s) => document.getElementById(s.id)).filter(Boolean) as HTMLElement[]
    const obs = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0]
        if (visible) setActiveId(visible.target.id)
      },
      { rootMargin: '-72px 0px -70% 0px', threshold: 0 },
    )
    els.forEach((el) => obs.observe(el))
    return () => obs.disconnect()
  }, [sections])

  // Copy reads textContent, so highlighted <span>s copy as plain source text.
  useEffect(() => {
    const root = bodyRef.current
    if (!root) return
    const onClick = (e: MouseEvent) => {
      const btn = (e.target as HTMLElement).closest('[data-copy]') as HTMLElement | null
      if (!btn) return
      const code = document.getElementById(btn.dataset.copy ?? '')
      if (!code) return
      navigator.clipboard?.writeText(code.textContent ?? '')
      btn.textContent = labels.copied
      setTimeout(() => { btn.textContent = labels.copy }, 1400)
    }
    root.addEventListener('click', onClick)
    return () => root.removeEventListener('click', onClick)
  }, [labels])

  const scrollTo = useCallback((id: string) => {
    const el = document.getElementById(id)
    if (el) window.scrollTo({ top: el.offsetTop - 64, behavior: 'smooth' })
  }, [])

  const matches = useMemo(() => {
    if (!query.trim()) return []
    const q = query.toLowerCase()
    return sections
      .map((s) => {
        const plain = s.md.replace(/[`*>#|-]/g, ' ')
        const i = plain.toLowerCase().indexOf(q)
        if (i < 0) return null
        return { id: s.id, title: s.title, snippet: plain.slice(Math.max(0, i - 40), i + 80).trim() }
      })
      .filter(Boolean) as { id: string; title: string; snippet: string }[]
  }, [query, sections])

  const firstLine = source.split('\n').find((l) => l.startsWith('# '))?.replace(/^#\s*/, '') ?? 'Document'

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="sticky top-0 z-30 border-b border-border/70 bg-background/85 backdrop-blur">
        <div className="mx-auto flex max-w-[1500px] items-center gap-4 px-5 py-3">
          <button
            type="button"
            onClick={() => setNavOpen((v) => !v)}
            aria-controls="doc-toc"
            aria-expanded={navOpen}
            title={navOpen ? labels.hideNav : labels.showNav}
            className="flex min-w-0 items-center gap-2 rounded px-1 py-0.5 text-left font-semibold tracking-tight hover:bg-accent/60 focus:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            {navOpen
              ? <PanelLeftClose className="h-4 w-4 shrink-0 text-muted-foreground" />
              : <PanelLeftOpen className="h-4 w-4 shrink-0 text-muted-foreground" />}
            <span className="truncate">{firstLine}</span>
          </button>
          <div className="relative ml-auto w-full max-w-xs">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={labels.search}
              className="w-full rounded-md border border-border bg-card px-3 py-1.5 text-sm outline-none focus:ring-2 focus:ring-ring"
            />
            {matches.length > 0 && (
              <div className="absolute mt-1 max-h-80 w-full overflow-auto rounded-md border border-border bg-popover p-1 shadow-xl">
                {matches.slice(0, 12).map((m) => (
                  <button
                    key={m.id}
                    onClick={() => { scrollTo(m.id); setQuery('') }}
                    className="block w-full rounded px-2 py-1.5 text-left text-sm hover:bg-accent hover:text-accent-foreground"
                  >
                    <div className="font-medium">{m.title}</div>
                    <div className="truncate text-xs text-muted-foreground">{m.snippet}</div>
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </header>

      <div className="mx-auto flex max-w-[1500px] gap-8 px-5 py-6">
        {navOpen && (
          <nav
            id="doc-toc"
            aria-label={labels.toc(sections.length)}
            className="sticky top-[68px] hidden h-[calc(100vh-92px)] w-60 shrink-0 overflow-auto pr-2 lg:block"
          >
            <div className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              {labels.toc(sections.length)}
            </div>
            <ul className="space-y-0.5 border-l border-border">
              {sections.map((s) => (
                <li key={s.id}>
                  <button
                    onClick={() => scrollTo(s.id)}
                    className={
                      'block w-full border-l-2 py-1 pl-3 pr-2 text-left text-[13px] leading-snug transition-colors ' +
                      (activeId === s.id
                        ? 'border-primary bg-accent/60 font-medium text-accent-foreground'
                        : 'border-transparent text-muted-foreground hover:border-border hover:text-foreground')
                    }
                  >
                    {s.title}
                  </button>
                </li>
              ))}
            </ul>
          </nav>
        )}

        <main ref={bodyRef} className="min-w-0 flex-1 pb-24">
          <article className="doc">
            {rendered.map((s) => (
              <section key={s.id} id={s.id} className="scroll-mt-20">
                <h2 className="mt-8 mb-3 border-b border-border pb-2 text-xl font-semibold tracking-tight">
                  {s.title}
                </h2>
                <div dangerouslySetInnerHTML={{ __html: s.html }} />
              </section>
            ))}
            <p className="pt-6 text-xs text-muted-foreground">
              {labels.footer(sections.length)}
            </p>
          </article>
        </main>
      </div>
    </div>
  )
}
