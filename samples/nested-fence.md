# 嵌套 fence 回归样本

本文件**故意**写错，用来验证 `md-to-html.sh` 的 fence 预检（`scripts/check-md-fences.py`）。

按 CommonMark，闭合 fence 不能带 info string，所以内层的 ` ```bash ` 关不掉外层的
` ```markdown `；真正生效的闭合是内层代码块结尾那行裸 ` ``` `。从那一行开始，后面的
内容都会被当成正文渲染 —— `## Roadmap` 会变成真的 `<h2>`。

正确写法是把外层改成 4 个反引号：` ````markdown ` … ` ```` `，内部的 3 反引号就只是内容。

```markdown
# ai-evals

## Why this exists

```bash
git clone foo
```

## Roadmap

- link
```
