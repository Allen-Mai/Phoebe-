#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
日记备份脚本 —— 把整个 Logseq 图库打包成带时间戳的 zip

用法：
    python 备份.py                     # 备份到 图库上级/备份/
    python 备份.py --keep 20           # 只保留最近 20 个备份
    python 备份.py --out "E:\\我的备份"

特点：
    * 只用 Python 标准库
    * 默认排除 .git、logseq/bak、logseq/.recycle、报告、备份等无用内容
    * 自动清理旧备份，避免无限增长
"""

import argparse
import datetime as dt
import os
import sys
import zipfile
from pathlib import Path

EXCLUDE_DIRS = {".git", "bak", ".recycle", "version-files", "报告", "备份", "__pycache__"}
EXCLUDE_FILES = {"Thumbs.db", "Desktop.ini", ".DS_Store"}


def default_graph_dir() -> Path:
    here = Path(__file__).resolve().parent
    for cand in (here.parent / "graph", here / "graph", here.parent):
        if (cand / "journals").is_dir():
            return cand
    return here.parent / "graph"


def should_skip(path: Path, base: Path) -> bool:
    """只按相对 base 的路径片段判断排除，避免图库本身所在的绝对路径里
    含有 '备份'、'报告' 等同名目录时把整个图库都跳过。"""
    try:
        rel_parts = path.relative_to(base).parts
    except ValueError:
        rel_parts = path.parts
    if any(part in EXCLUDE_DIRS for part in rel_parts):
        return True
    if path.name in EXCLUDE_FILES:
        return True
    if path.suffix in {".tmp", ".swp"}:
        return True
    return False


def make_backup(graph: Path, out_dir: Path, compress_level: int = 6):
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_path = out_dir / f"日记本备份_{stamp}.zip"

    file_count = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED,
                         compresslevel=compress_level) as zf:
        for root, dirs, files in os.walk(graph):
            root_path = Path(root)
            dirs[:] = [d for d in dirs if not should_skip(root_path / d, graph)]
            for name in files:
                src = root_path / name
                if should_skip(src, graph):
                    continue
                try:
                    zf.write(src, src.relative_to(graph.parent))
                    file_count += 1
                except OSError as exc:
                    print(f"[跳过] {src}（{exc}）", file=sys.stderr)
    return zip_path, file_count


def prune(out_dir: Path, keep: int) -> list:
    if keep <= 0:
        return []
    backups = sorted(out_dir.glob("日记本备份_*.zip"),
                     key=lambda p: p.stat().st_mtime, reverse=True)
    removed = []
    for old in backups[keep:]:
        try:
            old.unlink()
            removed.append(old)
        except OSError as exc:
            print(f"[无法删除] {old}（{exc}）", file=sys.stderr)
    return removed


def human_size(num: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if num < 1024 or unit == "GB":
            return f"{num:.1f} {unit}" if unit != "B" else f"{num} {unit}"
        num /= 1024.0
    return f"{num:.1f} GB"


def main() -> int:
    parser = argparse.ArgumentParser(description="把 Logseq 图库打包备份")
    parser.add_argument("--graph", default=None, help="Logseq 图库目录（默认自动定位）")
    parser.add_argument("--out", default=None, help="备份输出目录")
    parser.add_argument("--keep", type=int, default=10, help="保留最近几个备份，默认 10；0 表示不清理")
    args = parser.parse_args()

    graph = Path(args.graph).resolve() if args.graph else default_graph_dir()
    if not (graph / "journals").is_dir():
        print(f"[错误] 在 {graph} 下找不到 journals/ 目录。", file=sys.stderr)
        print("       请用 --graph 指定 Logseq 图库目录。", file=sys.stderr)
        return 1

    out_dir = Path(args.out).resolve() if args.out else graph.parent / "备份"

    zip_path, file_count = make_backup(graph, out_dir)
    size = zip_path.stat().st_size

    print("=" * 52)
    print("  日记备份完成")
    print("=" * 52)
    print(f"  来源图库 : {graph}")
    print(f"  备份文件 : {zip_path}")
    print(f"  文件数量 : {file_count} 个")
    print(f"  压缩后   : {human_size(size)}")

    removed = prune(out_dir, args.keep)
    if args.keep > 0:
        print(f"  保留策略 : 最近 {args.keep} 个，已清理 {len(removed)} 个旧备份")
    print("=" * 52)

    if file_count == 0:
        print("[警告] 没有打包到任何文件，请检查图库路径是否正确。", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
