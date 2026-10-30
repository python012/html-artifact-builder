#!/usr/bin/env python3
# [LOCAL ADDITION 2026-10-30] Fence preflight for md-to-html.sh.
#
# Why this exists: the renderer (marked 18) follows CommonMark/GFM, and GitHub
# renders the same input identically. So when a document nests a code fence
# inside another fence of the SAME marker and length (``` inside ```), the
# output is not a renderer bug -- the outer block really does close early, the
# rest of the document really is body text, and a "## Heading" inside the
# leftover block really becomes an <h2>. Correct per spec, useless to the
# author. This script is the missing diagnostic: it reports where the mark was
# almost certainly intended to close instead.
#
# Scope / deliberate limits (do not extend without checking CommonMark):
#   - Only top-level fenced blocks. Fences inside blockquotes or list items are
#     not special-cased; they are scanned as ordinary lines.
#   - A line indented 4+ columns is NOT a fence (it is literal/indented code),
#     so it neither opens nor closes anything. Tabs advance to the next
#     4-column stop when measuring the indent.
#   - ` and ~ fences are independent namespaces: a ``` line can never affect a
#     ~~~ block, which is why mixing markers is a valid workaround.
#   - Symmetric nesting (open 4, nest 3) is LEGAL and must stay silent: a fence
#     shorter than the opener can never close it. This is the main false-positive
#     trap -- "closing fences may not carry an info string" is not enough on its
#     own, the length test is what keeps that case quiet.
#
# Exit codes: 0 = clean or warning-only (default), 1 = warning with --strict,
#             2 = usage / IO error.
import sys

# Windows consoles can still be on a legacy codepage, where printing the emoji
# below raises UnicodeEncodeError. Downgrading to '?' beats crashing the build.
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, 'reconfigure'):
        stream.reconfigure(errors='replace')

USAGE = "usage: check-md-fences.py [--strict] <file.md>"


def indent_columns(prefix):
    col = 0
    for ch in prefix:
        col += 4 - (col % 4) if ch == '\t' else 1
    return col


def parse_fence(line):
    """Return (char, count, info) if the line is shaped like a fence, else None.

    "Shaped like" = indent <= 3 columns, then a run of >= 3 ` or ~, then an
    info string. Whether that line opens or closes is decided by the caller.
    """
    i = 0
    while i < len(line) and line[i] in ' \t':
        i += 1
    if indent_columns(line[:i]) > 3:
        return None
    rest = line[i:]
    if not rest or rest[0] not in '`~':
        return None
    char = rest[0]
    count = 0
    while count < len(rest) and rest[count] == char:
        count += 1
    if count < 3:
        return None
    return char, count, rest[count:].strip()


def main(argv):
    strict = False
    path = None
    for arg in argv[1:]:
        if arg == '--strict':
            strict = True
        elif arg in ('-h', '--help'):
            print(USAGE, file=sys.stderr)
            return 0
        elif arg.startswith('-'):
            print(f"check-md-fences.py: unknown option {arg}\n{USAGE}", file=sys.stderr)
            return 2
        elif path is None:
            path = arg
        else:
            print(f"check-md-fences.py: unexpected argument {arg}\n{USAGE}", file=sys.stderr)
            return 2

    if path is None:
        print(f"check-md-fences.py: missing input file\n{USAGE}", file=sys.stderr)
        return 2

    try:
        with open(path, 'r', encoding='utf-8-sig', errors='replace') as fh:
            lines = fh.read().split('\n')
    except OSError as exc:
        print(f"check-md-fences.py: cannot read {path}: {exc}", file=sys.stderr)
        return 2

    def close_line(start, char, count):
        """First line at/after `start` (0-based) that really closes the block."""
        for idx in range(start, len(lines)):
            parsed = parse_fence(lines[idx])
            if parsed is None:
                continue
            c, n, info = parsed
            if c == char and n >= count and info == '':
                return idx + 1
        return None

    warnings = []       # one dict per nested-fence hit
    open_block = None   # (char, count, lineno, info, line_index)
    for idx, line in enumerate(lines):
        parsed = parse_fence(line)
        if parsed is None:
            continue
        char, count, info = parsed

        if open_block is None:
            # A backtick fence whose info string contains a backtick is not a
            # fence at all in CommonMark; leaving it out avoids inventing blocks.
            if char == '`' and '`' in info:
                continue
            open_block = (char, count, idx + 1, info, idx)
            continue

        o_char, o_count, o_line, o_info, o_index = open_block
        if char != o_char:
            continue                      # other marker: plain literal content

        if count >= o_count and info == '':
            open_block = None             # normal close
            continue

        if count >= o_count and info != '':
            if char == '`' and '`' in info:
                continue                  # not a fence line in CommonMark
            warnings.append({
                'open_line': o_line, 'open_char': o_char, 'open_count': o_count,
                'open_info': o_info, 'start': o_index,
                'hit_line': idx + 1, 'hit_char': char, 'hit_count': count,
                'hit_info': info,
            })

    if not warnings:
        return 0

    per_block = {}
    for hit in warnings:
        per_block.setdefault(hit['open_line'], []).append(hit)

    for hit in warnings:
        block = per_block[hit['open_line']]
        needed = max(h['hit_count'] for h in block) + 1
        needed = max(needed, hit['open_count'] + 1)
        marker = '反引号' if hit['open_char'] == '`' else '波浪号'
        run = hit['open_char'] * needed
        example = run + hit['open_info'] + ' … ' + run

        print(
            f"⚠️  Fence  : {path} 第 {hit['open_line']} 行 "
            f"{hit['open_char'] * hit['open_count']}{hit['open_info']} "
            f"内有嵌套 fence（第 {hit['hit_line']} 行 "
            f"{hit['hit_char'] * hit['hit_count']}{hit['hit_info']}）",
            file=sys.stderr,
        )
        closed = close_line(hit['start'] + 1, hit['open_char'], hit['open_count'])
        if closed is None:
            print("       →   直到文档结尾都没有闭合行，其后的内容都会被当成代码",
                  file=sys.stderr)
        else:
            print(f"       →   实际闭合于第 {closed} 行，其后的内容会被当成正文渲染",
                  file=sys.stderr)
        print(f"       →   修法：外层改用 {needed} 个{marker}（{example}），"
              "或把内部 fence 缩进 4 空格", file=sys.stderr)

    if strict:
        print("❌ Fence  : --strict-fences 已启用，构建中止", file=sys.stderr)
        return 1
    print("ℹ️  渲染继续；加 --strict-fences 可让此情况直接失败", file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
