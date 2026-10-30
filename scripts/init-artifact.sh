#!/bin/bash
set -e

# [LOCAL REWRITE 2026-10-30] Vite + vite-plugin-singlefile edition.
# Replaces the upstream Parcel-based flow. Why:
#  - Parcel 2.16 cannot resolve @radix-ui/primitive@1.2.0's nested
#    "development"/"production" export conditions, so every shadcn/ui component
#    failed with: Cannot load file './is-development' from module
#    '@radix-ui/primitive'. Verified unfixable via targets / version pinning /
#    pnpm overrides.
#  - Vite + vite-plugin-singlefile emits ONE self-contained .html with no
#    /assets/ references and no import-map, which is the whole point here.
#  - Goal: minimal images, fully self-contained, single HTML file.

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
echo "🔍 Detected Node.js version: $NODE_VERSION"
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "❌ Error: Node.js 18 or higher is required"
  exit 1
fi

if [ -z "$1" ]; then
  echo "❌ Usage: init-artifact.sh <project-name>"
  exit 1
fi
PROJECT_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS_TARBALL="$SCRIPT_DIR/shadcn-components.tar.gz"
if [ ! -f "$COMPONENTS_TARBALL" ]; then
  echo "❌ Error: shadcn-components.tar.gz not found next to this script"
  exit 1
fi

if ! command -v pnpm &> /dev/null; then
  echo "📦 pnpm not found. Installing pnpm..."
  npm install -g pnpm
fi

echo "🚀 Creating React + TS + Vite project: $PROJECT_NAME"
pnpm create vite "$PROJECT_NAME" --template react-ts
cd "$PROJECT_NAME"

# ---------------------------------------------------------------------------
# Strip the demo template down to a blank slate.
# [LOCAL REWRITE] Upstream only deleted one <link> tag, leaving hero.png,
# react.svg and vite.svg in src/assets -- those are exactly what made the
# bundle non-self-contained (they became /assets/*.png refs in the output).
# Minimal images is a hard requirement, so all template art goes away.
# ---------------------------------------------------------------------------
echo "🧹 Removing template demo assets..."
rm -rf src/assets src/App.css public
rm -f src/App.tsx
cat > src/App.tsx << 'EOF'
// [LOCAL REWRITE] Blank canvas. Import shadcn/ui components from '@/components/ui/*'.
// Keep images to a minimum so the bundle stays a single self-contained file.
// Theme tokens only: the scaffold is light by default, so a hardcoded
// bg-slate-950 would fight the page (and white-on-white is easy to hit).
export default function App() {
  return (
    <main className="min-h-screen bg-background p-8 text-foreground">
      <h1 className="text-3xl font-semibold tracking-tight">Ready</h1>
      <p className="mt-2 text-muted-foreground">Edit src/App.tsx, then run bundle-artifact.sh</p>
    </main>
  )
}
EOF

# index.html: drop the favicon link entirely (no external file to resolve).
# The <title> here is only a placeholder: the project name is a throwaway build
# detail and reads badly in a browser tab. md-to-html.sh rewrites <title> from
# the document's own H1 (or an explicit --title). When scaffolding by hand, set
# <title> deliberately before shipping.
cat > index.html << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$PROJECT_NAME</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# main.tsx: App.css is gone, so rewrite without that import.
cat > src/main.tsx << 'EOF'
import React from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App'

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

echo "📦 Installing base dependencies..."
pnpm install

echo "📦 Installing Tailwind + shadcn/ui dependencies..."
pnpm install -D tailwindcss@3.4.1 postcss autoprefixer @types/node tailwindcss-animate
pnpm install class-variance-authority clsx tailwind-merge lucide-react next-themes

# Bundling: Vite singlefile replaces Parcel + html-inline entirely.
pnpm install -D vite-plugin-singlefile

echo "⚙️  Creating Tailwind and PostCSS configuration..."
cat > postcss.config.js << 'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# shadcn/ui CSS variables (hsl triplets) + Tailwind layers.
cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --popover: 222.2 84% 4.9%;
    --popover-foreground: 210 40% 98%;
    --primary: 210 40% 98%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 212.7 26.8% 83.9%;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
EOF

cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: { "2xl": "1400px" },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
EOF

echo "🔧 Setting up path aliases (@/ -> src/) ..."
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { viteSingleFile } from 'vite-plugin-singlefile'
import { fileURLToPath } from 'node:url'

export default defineConfig({
  plugins: [react(), viteSingleFile()],
  resolve: {
    // fileURLToPath(new URL(...)) instead of __dirname: the latter is
    // unsupported by Vite's native config loader and warns on every build.
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  build: {
    // Inline every asset as base64 so the output is ONE file.
    assetsInlineLimit: 100000000,
    cssCodeSplit: false,
  },
})
EOF

echo "📦 Extracting shadcn/ui components..."
mkdir -p src/components src/hooks src/lib
tar -xzf "$COMPONENTS_TARBALL" -C src
echo "📝 Creating components.json config..."
cat > components.json << 'EOF'
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "src/index.css",
    "baseColor": "slate",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
EOF

# Enforce "@/" aliases in TS so editors and tsc agree with Vite.
# Vite emits tsconfig*.json as JSONC (comments), so strip them before parsing.
#
# [LOCAL ADDITION 2026-10-30] `python3` cannot be assumed — see md-to-html.sh.
# python.org's Windows installer only ships `python.exe` / `py.exe`, and the
# Microsoft Store alias leaves a `python3.exe` stub that exits non-zero.
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

"$PYTHON" - << 'PY'
import json, os, re

def strip_jsonc(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'(^|[^:"\'])//[^\n]*', r'\1', text)
    return text

for name in ("tsconfig.json", "tsconfig.app.json"):
    if not os.path.exists(name):
        continue
    with open(name) as f:
        raw = f.read()
    try:
        cfg = json.loads(strip_jsonc(raw))
    except json.JSONDecodeError as exc:
        print(f"  (skipped {name}: cannot parse as JSONC: {exc})")
        continue
    co = cfg.setdefault("compilerOptions", {})
    # No "baseUrl": TypeScript 7 removed it (TS5102) and `paths` has been
    # resolvable relative to the tsconfig since TS 4.1, so this works on both.
    co.pop("baseUrl", None)
    co.setdefault("paths", {})["@/*"] = ["./src/*"]
    with open(name, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
PY

echo "📦 Installing Radix + remaining shadcn/ui runtime deps..."
pnpm install @radix-ui/react-accordion @radix-ui/react-aspect-ratio \
  @radix-ui/react-avatar @radix-ui/react-checkbox @radix-ui/react-collapsible \
  @radix-ui/react-context-menu @radix-ui/react-dialog @radix-ui/react-dropdown-menu \
  @radix-ui/react-hover-card @radix-ui/react-label @radix-ui/react-menubar \
  @radix-ui/react-navigation-menu @radix-ui/react-popover @radix-ui/react-progress \
  @radix-ui/react-radio-group @radix-ui/react-scroll-area @radix-ui/react-select \
  @radix-ui/react-separator @radix-ui/react-slider @radix-ui/react-slot \
  @radix-ui/react-switch @radix-ui/react-tabs @radix-ui/react-toast \
  @radix-ui/react-toggle @radix-ui/react-toggle-group @radix-ui/react-tooltip
pnpm install cmdk embla-carousel-react react-day-picker react-hook-form \
  react-resizable-panels sonner vaul zod date-fns @hookform/resolvers

echo "🔨 Verifying the scaffold builds..."
pnpm exec vite build > /dev/null
BUILT=$(ls -1 dist/*.html 2>/dev/null | head -1)
if [ -z "$BUILT" ]; then
  echo "❌ Build produced no HTML in dist/"
  exit 1
fi
SIZE=$(du -h "$BUILT" | cut -f1)
echo "✅ Setup complete! Smoke build produced a single file: $BUILT ($SIZE)"

echo ""
echo "📦 Included components (43 total):"
echo "  - accordion, alert, alert-dialog, aspect-ratio, avatar, badge,"
echo "    breadcrumb, button, calendar, card, carousel, checkbox, collapsible,"
echo "    command, context-menu, dialog, drawer, dropdown-menu, form,"
echo "    hover-card, input, label, menubar, navigation-menu, popover,"
echo "    progress, radio-group, resizable, scroll-area, select, separator,"
echo "    sheet, skeleton, slider, sonner, switch, table, tabs, textarea,"
echo "    toast, toaster, toggle, toggle-group, tooltip"
echo ""
echo "To start developing:"
echo "  cd $PROJECT_NAME && pnpm dev"
echo ""
echo "Then bundle to ONE self-contained HTML:"
echo "  bash $SCRIPT_DIR/bundle-artifact.sh"
