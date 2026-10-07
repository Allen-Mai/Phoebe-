#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
日记统计脚本 —— 连续记录天数 + 字数热力图

用法：
    python 统计.py                  # 自动定位同级的 graph 目录
    python 统计.py --graph "D:\\path\\to\\graph"
    python 统计.py --days 180       # 只看最近 180 天

特点：
    * 只用 Python 标准库，不需要 pip install 任何东西
    * 只读，不修改你的日记文件
    * 输出：备份/统计报告.html（热力图 + 汇总），并在终端打印摘要
"""

import argparse
import datetime as dt
import html
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# 字数统计口径
# ---------------------------------------------------------------------------

# Logseq / Markdown 的"噪音"，不计入字数
_PROPERTY_RE = re.compile(r"^\s*[A-Za-z][A-Za-z0-9_-]*::.*$")          # type:: 项目
_BLOCK_MARKER_RE = re.compile(r"^\s*[-*+]\s*")                            # 列表符号
_QUERY_RE = re.compile(r"\{\{[^}]*\}\}", re.S)                            # {{query ...}}
_BEGIN_END_RE = re.compile(r"^\s*#\+(BEGIN|END)_\w+.*$", re.M)            # #+BEGIN_QUOTE
_MD_LINK_RE = re.compile(r"!?\[[^\]]*\]\([^)]*\)")                        # [文字](链接)
_URL_RE = re.compile(r"https?://\S+")
_TASK_RE = re.compile(r"^\s*(TODO|DOING|DONE|NOW|later)\s+", re.I)
_INLINE_CODE_RE = re.compile(r"`[^`]*`")
_HEADING_RE = re.compile(r"^\s*#{1,6}\s*")
_EMPHASIS_RE = re.compile(r"[*_~]{1,3}")
_BRACKET_RE = re.compile(r"[\[\]{}]")
_SCHEDULED_RE = re.compile(r"(SCHEDULED|DEADLINE|CLOSED):\s*<[^>]*>")


def count_visible_chars(text: str) -> int:
    """把一段 Logseq/Markdown 文本换算成"有效字数"（不含空白与语法符号）。"""
    text = _QUERY_RE.sub("", text)
    text = _BEGIN_END_RE.sub("", text)
    text = _SCHEDULED_RE.sub("", text)

    kept_lines = []
    in_code_block = False
    for line in text.splitlines():
        if line.strip().startswith("```"):
            in_code_block = not in_code_block
            continue
        if in_code_block:
            continue
        if _PROPERTY_RE.match(line):
            continue
        line = _BLOCK_MARKER_RE.sub("", line)
        line = _TASK_RE.sub("", line)
        line = _HEADING_RE.sub("", line)
        line = _MD_LINK_RE.sub("", line)
        line = _URL_RE.sub("", line)
        line = _INLINE_CODE_RE.sub("", line)
        kept_lines.append(line)

    text = "\n".join(kept_lines)
    text = _EMPHASIS_RE.sub("", text)
    text = _BRACKET_RE.sub("", text)
    return sum(1 for ch in text if not ch.isspace())


# ---------------------------------------------------------------------------
# 读取日记
# ---------------------------------------------------------------------------

JOURNAL_NAME_RE = re.compile(r"^(\d{4})[_-](\d{2})[_-](\d{2})$")


def load_journals(graph: Path):
    """返回 {date: 字数}，只统计 journals/ 目录下一级目录里的日记文件。"""
    journals_dir = graph / "journals"
    if not journals_dir.is_dir():
        return {}, journals_dir

    result = {}
    for path in sorted(journals_dir.rglob("*.md")):
        stem = path.stem
        m = JOURNAL_NAME_RE.match(stem)
        if not m:
            continue  # 非标准命名的文件（用户自己放的）跳过
        try:
            day = dt.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            continue
        try:
            raw = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        result[day] = result.get(day, 0) + count_visible_chars(raw)
    return result, journals_dir


def compute_streaks(days):
    """返回 (当前连续天数, 最长连续天数)。"""
    if not days:
        return 0, 0
    ordered = sorted(days)

    longest = 1
    run = 1
    for prev, cur in zip(ordered, ordered[1:]):
        if (cur - prev).days == 1:
            run += 1
            longest = max(longest, run)
        else:
            run = 1

    today = dt.date.today()
    anchor = today if today in days else today - dt.timedelta(days=1)
    current = 0
    cursor = anchor
    while cursor in days:
        current += 1
        cursor -= dt.timedelta(days=1)
    return current, longest


# ---------------------------------------------------------------------------
# 生成 HTML 报告
# ---------------------------------------------------------------------------

LEVELS = [(0, 0), (1, 150), (151, 400), (401, 800), (801, 10 ** 9)]
LEVEL_NAMES = ["未记录", "1–150 字", "151–400 字", "401–800 字", "800 字以上"]
LEVEL_COLORS = ["#ebedf0", "#c6e48b", "#7bc96f", "#239a3b", "#196127"]


def level_of(chars: int) -> int:
    if chars <= 0:
        return 0
    for idx, (lo, hi) in enumerate(LEVELS[1:], start=1):
        if lo <= chars <= hi:
            return idx
    return 4


def build_heatmap_html(days: dict, stats: dict, weeks: int = 53) -> str:
    today = dt.date.today()
    # GitHub 风格热力图：每列 = 一周，第 1 行 = 周日，第 7 行 = 周六。
    # 因此最后一列必须是「本周的周六」，这样行与星期才能对齐。
    days_since_sunday = (today.weekday() + 1) % 7
    end = today + dt.timedelta(days=6 - days_since_sunday)   # 本周周六
    start = end - dt.timedelta(days=weeks * 7 - 1)           # 恰好落在周日

    cells = []
    cursor = start
    while cursor <= end:
        if cursor > today:
            cells.append('<div class="cell empty"></div>')
        else:
            chars = days.get(cursor, 0)
            lv = level_of(chars)
            tip = f"{cursor.isoformat()}　{chars} 字"
            cells.append(
                f'<div class="cell lv{lv}" title="{html.escape(tip)}" '
                f'aria-label="{html.escape(tip)}"></div>'
            )
        cursor += dt.timedelta(days=1)

    legend = "".join(
        f'<div class="cell lv{i}" title="{html.escape(LEVEL_NAMES[i])}"></div>'
        for i in range(5)
    )
    legend_labels = "".join(
        f"<span class='lg'>{html.escape(LEVEL_NAMES[i])}</span>" for i in (0, 4)
    )

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>日记统计报告</title>
<style>
  :root {{ color-scheme: light; }}
  body {{ font-family: -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
         margin: 0; padding: 32px; background: #f6f8fa; color: #24292f; }}
  h1 {{ font-size: 22px; margin: 0 0 4px; }}
  .sub {{ color: #57606a; font-size: 13px; margin-bottom: 24px; }}
  .cards {{ display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 28px; }}
  .card {{ background: #fff; border: 1px solid #d0d7de; border-radius: 8px;
           padding: 14px 18px; min-width: 132px; }}
  .card .k {{ font-size: 12px; color: #57606a; }}
  .card .v {{ font-size: 24px; font-weight: 600; margin-top: 4px; }}
  .panel {{ background: #fff; border: 1px solid #d0d7de; border-radius: 8px;
            padding: 18px; overflow-x: auto; }}
  .panel h2 {{ font-size: 15px; margin: 0 0 14px; }}
  .grid {{ display: grid; grid-template-rows: repeat(7, 12px); grid-auto-flow: column;
           grid-auto-columns: 12px; gap: 3px; }}
  .cell {{ width: 12px; height: 12px; border-radius: 2px; background: #ebedf0; }}
  .cell.empty {{ background: transparent; }}
  .lv0 {{ background: {LEVEL_COLORS[0]}; }}
  .lv1 {{ background: {LEVEL_COLORS[1]}; }}
  .lv2 {{ background: {LEVEL_COLORS[2]}; }}
  .lv3 {{ background: {LEVEL_COLORS[3]}; }}
  .lv4 {{ background: {LEVEL_COLORS[4]}; }}
  .legend {{ display: flex; align-items: center; gap: 6px; margin-top: 14px;
             font-size: 12px; color: #57606a; }}
  .lg {{ margin: 0 4px; }}
  .missing {{ font-size: 13px; color: #57606a; line-height: 1.9; }}
  .missing code {{ background: #eff1f3; padding: 1px 5px; border-radius: 4px; }}
</style>
</head>
<body>
  <h1>日记统计报告</h1>
  <div class="sub">生成时间：{dt.datetime.now():%Y-%m-%d %H:%M}　·　数据来源：journals/ 目录</div>
  <div class="cards">
    <div class="card"><div class="k">当前连续记录</div><div class="v">{stats['current_streak']} 天</div></div>
    <div class="card"><div class="k">最长连续记录</div><div class="v">{stats['longest_streak']} 天</div></div>
    <div class="card"><div class="k">累计记录天数</div><div class="v">{stats['total_days']} 天</div></div>
    <div class="card"><div class="k">累计字数</div><div class="v">{stats['total_chars']:,}</div></div>
    <div class="card"><div class="k">有记录日均字数</div><div class="v">{stats['avg_chars']:,}</div></div>
    <div class="card"><div class="k">本月字数</div><div class="v">{stats['month_chars']:,}</div></div>
  </div>
  <div class="panel">
    <h2>字数热力图（最近 {weeks} 周）</h2>
    <div class="grid">
{''.join(cells)}
    </div>
    <div class="legend">少 {legend} 多 {legend_labels}</div>
  </div>
  <div class="panel" style="margin-top:20px">
    <h2>最近 30 天里没写日记的日子（{len(stats['missing'])} 天）</h2>
    <div class="missing">{stats['missing_html']}</div>
  </div>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def default_graph_dir() -> Path:
    here = Path(__file__).resolve().parent
    for cand in (here.parent / "graph", here / "graph", here.parent):
        if (cand / "journals").is_dir():
            return cand
    return here.parent / "graph"


def main() -> int:
    parser = argparse.ArgumentParser(description="日记统计：连续天数 + 字数热力图")
    parser.add_argument("--graph", default=None, help="Logseq 图库目录（默认自动定位）")
    parser.add_argument("--weeks", type=int, default=53, help="热力图显示多少周，默认 53")
    parser.add_argument("--days", type=int, default=None,
                        help="只统计最近 N 天（汇总数字与热力图都受影响）")
    parser.add_argument("--out", default=None, help="HTML 输出路径")
    args = parser.parse_args()

    graph = Path(args.graph).resolve() if args.graph else default_graph_dir()
    if not (graph / "journals").is_dir():
        print(f"[错误] 在 {graph} 下找不到 journals/ 目录。", file=sys.stderr)
        print("       请用 --graph 指定 Logseq 图库目录。", file=sys.stderr)
        return 1

    days, journals_dir = load_journals(graph)
    all_days = days
    if args.days:
        cutoff = dt.date.today() - dt.timedelta(days=args.days)
        days = {d: c for d, c in days.items() if d >= cutoff}

    if not days:
        print(f"[提示] {journals_dir} 里还没有符合命名规范的日记文件。")
        print("       Logseq 的日记文件名格式应为 2026_10_07.md")
        return 0

    current_streak, longest_streak = compute_streaks(days)
    total_days = len(days)
    total_chars = sum(days.values())
    written = [c for c in days.values() if c > 0]
    avg_chars = round(total_chars / len(written)) if written else 0

    today = dt.date.today()
    month_chars = sum(c for d, c in days.items()
                      if d.year == today.year and d.month == today.month)

    # 「漏写日」始终基于完整数据判断，不受 --days 影响
    missing = [today - dt.timedelta(days=i) for i in range(30)
               if (today - dt.timedelta(days=i)) not in all_days]
    missing_html = "　".join(f"<code>{d.isoformat()}</code>" for d in missing) or "最近 30 天全勤，厉害。"

    stats = {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "total_days": total_days,
        "total_chars": total_chars,
        "avg_chars": avg_chars,
        "month_chars": month_chars,
        "missing": missing,
        "missing_html": missing_html,
    }

    out_path = Path(args.out).resolve() if args.out else graph.parent / "报告" / "统计报告.html"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(build_heatmap_html(days, stats, weeks=args.weeks), encoding="utf-8")

    print("=" * 46)
    print("  日记统计")
    print("=" * 46)
    print(f"  当前连续记录 : {current_streak} 天")
    print(f"  最长连续记录 : {longest_streak} 天")
    print(f"  累计记录天数 : {total_days} 天")
    print(f"  累计字数     : {total_chars:,}")
    print(f"  有记录日均   : {avg_chars:,} 字")
    print(f"  本月字数     : {month_chars:,}")
    print("-" * 46)
    print(f"  报告已生成   : {out_path}")
    print("=" * 46)
    return 0


if __name__ == "__main__":
    sys.exit(main())
