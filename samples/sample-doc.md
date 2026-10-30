# 冒烟样本 · 2026-10-30（周五）· 全特性覆盖

这份文档的唯一用途是**一次性覆盖** `md-to-html.sh` 的全部渲染特性，方便改动后快速回归。
它故意包含：中文正文、宽表格、带/不带语言标记的围栏代码、围栏内的 `## `、五种告警卡片、
任务列表、行内代码与锚点链接。

> 📌 这一段以 📌 开头，应该渲染成灰色「备注」卡片，而不是普通引用。

## 快速开始

在技能目录下执行下面一行，输出会落在源文件旁边，**源文件本身不会被修改**：

```bash
bash scripts/md-to-html.sh samples/sample-doc.md --title "冒烟样本 · 全特性"
```

参数说明：`--title` 决定浏览器标签页文字，`--lang` 同时决定 `<html lang>` 与界面文案语言。
跳转到 [告警卡片](#告警卡片) 可以验证锚点与滚动定位。

## 特性覆盖表

| # | 特性 | 触发方式 | 预期表现 | 备注 |
|---|---|---|---|---|
| 1 | 侧边目录 | 每个 `##` 标题 | 左栏生成条目，滚动时高亮跟随 | 目录数量应等于 `##` 数量 |
| 2 | 全文搜索 | 顶部输入框输入关键词 | 下拉显示章节名 + 片段，点击跳转 | 只搜章节，不做全文高亮 |
| 3 | 语法高亮 | 围栏标注 `bash` / `ts` / `json` | GitHub 浅色 token 配色 | 依赖 highlight.js，不是纯 CSS |
| 4 | 自动探测 | 围栏不标语言 | 自动判定语言并上色 | 失败时退化为 `text` |
| 5 | 复制按钮 | 每个代码块右上角 | 点击后变成「已复制」，1.4 秒后复原 | 复制的是纯文本源码 |
| 6 | 告警卡片 | 引用块首字符是 emoji | ⚠️ 琥珀 / 🔴 玫瑰 / ✅ 翠绿 / 👉 天蓝 / 📌 灰 | 首字符不在表内则保持普通引用 |
| 7 | 围栏内标题 | 代码里出现 `## xxx` | **不得**出现在目录中 | 关键回归点 |
| 8 | 宽表格 | 列多、单元格长文本 | 自动换行，不撑破页面 | 第一列不换行 |
| 9 | 任务列表 | `- [ ]` / `- [x]` | 显示复选框并去掉项目符号 | 由 GFM 渲染 |
| 10 | 行内代码 | 反引号包裹 | 浅灰底、等宽字体 | 与代码块样式不同 |

## 代码块：带语言标记

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

const sections: Section[] = [{ id: slugify('概览'), title: '概览', md: '' }]
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

print(embed("samples/sample-doc.md")[:40])
```

## 代码块：不带语言标记

下面这个围栏故意不写语言，用来验证 highlight.js 的自动探测路径：

```
interface BuildOptions {
  singleFile: boolean
  inlineAssets: boolean
}

function bundle(opts: BuildOptions): string {
  return opts.singleFile ? 'bundle.html' : 'dist/index.html'
}
```

## 代码块：围栏里的 ## 不应进入目录

下面围栏里有两行以 `## ` 开头。如果目录里出现「假章节」，说明 fence 状态跟踪坏了：

```markdown
# 一个被嵌入的 README 模板

## 安装
把目录拷到 ~/.agents/skills/ 下即可。

## 用法
bash scripts/md-to-html.sh doc.md
```

围栏结束。上面那两行 `##` 都只是代码，不是章节。

## 告警卡片

> ⚠️ 警告：构建目录默认在 `mktemp -d` 里，脚本退出即删除。设 `HAB_KEEP_BUILD=1` 才会保留。

> 🔴 危险：不要把打包器改回 Parcel 2.16。它无法解析 `@radix-ui/primitive@1.2.0` 的嵌套导出条件，每个 shadcn 组件都会构建失败。

> ✅ 正常：`bundle-artifact.sh` 的自检通过时会打印 `✅ Self-contained`，并且**零**外部引用。

> 👉 提示：`--title` 要自己挑一个短名字。H1 通常带日期和 emoji，做标签页标题太长。

> 📌 备注：没有首字符 emoji 的引用块会保持普通引用样式，比如这一段。

> 这一条没有任何 emoji 前缀，应当**不**被识别成告警卡片。

## 列表、任务与细节

- 一级项目
  - 二级项目，带行内代码 `RAW_MARKDOWN`
    - 三级项目，验证缩进与标记颜色
- 另一条一级项目

- [x] 目录生成正常
- [x] 搜索命中正常
- [ ] 待确认：`--lang en` 时界面文案是否为英文
- [ ] 待确认：复制按钮点击后的状态文案

<details>
<summary>折叠区块（点开看结构）</summary>

折叠内容里也可以放代码：

```text
plain text block, language chip should read "text"
```

</details>

---

## 结尾

到这里所有特性都过了一遍。回归时重点看三件事：

1. 目录条目数 = 本文件的 `##` 数量（围栏内的不算）。
2. 每个代码块都有语言标签和复制按钮，且 token 有颜色。
3. 页面不发起任何网络请求。
