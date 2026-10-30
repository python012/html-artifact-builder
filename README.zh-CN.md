# html-artifact-builder

> [English](README.md) · **简体中文**

一个 **agent skill**（遵循 [Agent Skills 规范](https://agentskills.io/specification)）：
生成轻量、更有表现力的单个自包含 HTML 文件 —— 双击就能打开，不用起服务器，
也不从网上拉任何东西。

两条路径：

| 路径 | 命令 | 你会得到 |
|---|---|---|
| **用 React 写页面**（主要用法） | 先 `scripts/init-artifact.sh`，再 `scripts/bundle-artifact.sh` | 单个 HTML，43 个 shadcn/ui 组件，React + Tailwind 的表达力都在手上 |
| **从已有文档起步** | `scripts/md-to-html.sh doc.md` | 单个 HTML：侧边目录、搜索、语法高亮代码 |

> 本项目是 Anthropic [`web-artifacts-builder`](https://github.com/anthropics/skills)
> 的修改衍生版，以 Apache 2.0 发布。具体改了什么见 [NOTICE.md](NOTICE.md)。

**先看效果：** [samples/sample-doc.html](samples/sample-doc.html) —— 渲染器自己的冒烟样本，
已经渲染成单个 HTML 文件。

---

## 为什么需要它

一个 HTML 文件，是把成果递给别人最直接的方式：不用部署、链接不会失效，也不用问「你能打开附件吗」。
卡住人的往往不是想法，而是搭环境 —— 一个 React 工程、一套组件库、一个能把资源全部内联的打包器。
这个 skill 就是把这段准备工作省掉：43 个 shadcn/ui 组件、Tailwind，以及一条命令产出单个自包含文件的构建。

有时候内容已经写成 Markdown，而你不想再手工设计一个页面。`md-to-html.sh` 给它同样的待遇 ——
还是一个 `.html`，但比原始 Markdown 好用得多：

- **侧边目录**，随滚动高亮当前章节 —— 点击页头标题可收起／展开目录栏
- **全文搜索**，跳到命中的章节并显示片段
- **语法高亮**，GitHub 浅色主题（highlight.js 离线内置）
- **代码块**带语言标签和一键复制按钮
- **告警卡片**，由引用块首字符的 emoji 推出：⚠️ 警告、🔴 危险、✅ 正常、👉 提示、📌 备注
- 围栏代码里的 `## ` 会被忽略，所以文档里嵌的 README 模板不会污染目录

Markdown 这条链路是**逐字保真**的：`.md` 以 JSON 字符串原样嵌入，运行时解析。源文件永远不会被修改，
也不存在「手工转录」这一步（内容被悄悄丢掉，通常就发生在转录环节）。

## 环境要求

| 要求 | 说明 |
|---|---|
| **Node.js 18+** | 初始化脚本会检查版本 |
| **pnpm** | 缺失时由脚本全局安装 |
| **网络** | 首次运行要装约 40 个 npm 包 |
| **python3** | 用来安全地嵌入内容、改写 `<title>` |

没有零依赖模式。如果你需要零依赖，不要用这个 skill，直接手写一个静态 HTML 文件。

## 安装

Skill 是从文件系统里发现的。把这个目录拷到以下任一位置：

| 工具 | 位置 |
|---|---|
| **DSH** | `~/.dsh/skills/` 或 `~/.agents/skills/` |
| **OpenCode** | `~/.config/opencode/skills/`、`~/.claude/skills/` 或 `~/.agents/skills/` |
| **Claude Code** | `~/.claude/skills/` |
| **GitHub Copilot** | 仓库内的 `.github/skills/` |

`~/.agents/skills/` 能同时被 DSH、OpenCode 和 Claude 兼容的 agent 识别，所以共享安装时它最省事：

```bash
git clone https://github.com/<you>/html-artifact-builder.git \
  ~/.agents/skills/html-artifact-builder
```

注意：目录名必须和 `SKILL.md` 里的 `name:` 字段一致。

## 用法

### React → 单个 HTML

```bash
bash scripts/init-artifact.sh my-artifact     # 脚手架
cd my-artifact
# 编辑 src/App.tsx，从 '@/components/ui/*' 引入组件
bash ../scripts/bundle-artifact.sh            # 产出 bundle.html
```

打包脚本会跑一次自包含自检，成功时打印：

```
✅ Self-contained: no root-relative refs, no import-maps.
```

失败时它会列出泄漏的引用并以**非零退出码**结束。请把这种情况当成 bug 而不是「警告」——
通常是某个资源用了绝对路径引用，而不是内联。

### Markdown → 单个 HTML

```bash
bash scripts/md-to-html.sh samples/sample-doc.md --title "冒烟样本 · 全特性"
```

输出写在源文件旁边（`sample-doc.html`），源文件不会被修改。仓库里已带上渲染结果：
[samples/sample-doc.html](samples/sample-doc.html)。

**标题要自己挑。** Markdown 没有标题元数据，而 `<title>` 就是浏览器标签页上显示的文字。
请用一个简短、人能读的名字，而不是原始的 H1 —— H1 通常太长，还常带日期和 emoji：

| 别用（原始 H1） | 建议（`--title`） |
|---|---|
| `冒烟样本 · 全特性覆盖` | `冒烟样本 · 全特性` |
| `发布说明 · 打包器从 Parcel 换成 Vite 的经过` | `发布说明 · Parcel 换 Vite` |

不传 `--title` 时，回退顺序是：首个 H1 → 文件名。`<html lang>` 可以显式指定，也按中文字符
密度自动判定 `zh-CN` / `en`；同一个值还会决定界面文案（侧栏标题、搜索占位、复制按钮）的语言。

## 保持自包含

唯一需要记住的规则：**永远不要用绝对路径引用文件。**

| 应该这样做 | 不要这样做 |
|---|---|
| 内联 SVG，或用 `lucide-react` 图标 | 从 `src/assets` 引入 `.png` / `.svg` |
| CSS 渐变、边框、形状 | 引用 `/images/foo.png` |
| 系统字体栈 | 用 `<link>` 加载 Google Fonts |
| 把数据写成内联 TS 对象 | `fetch()` 本地 JSON 文件 |

## 设计建议

避开一眼就像机器生成的东西：全部居中、紫色渐变、统一的圆角、默认字体 Inter。
更可取的是有意图的配色和真实的信息密度，并让颜色承载语义（绿色 = 通过，琥珀 = 未达标）。

## 许可

- 本项目：**Apache License 2.0** —— 见 [LICENSE.txt](LICENSE.txt)
- 上游 `anthropics/skills`：Apache License 2.0，Copyright 2026 Anthropic, PBC.
- 内置的 shadcn/ui 组件：**MIT**，Copyright (c) 2023 shadcn —— 见
  [licenses/shadcn-ui-MIT.txt](licenses/shadcn-ui-MIT.txt)
- 修改内容记录在 [NOTICE.md](NOTICE.md)，这是 Apache 2.0 第 4(b) 条的要求。

依 Apache 2.0 第 6 条，本项目不获得任何商标权利。本项目与 Anthropic 无隶属关系，也未获其背书。
