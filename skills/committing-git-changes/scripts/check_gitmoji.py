#!/usr/bin/env python3
# コミットメッセージの中見出し（### ）の先頭の絵文字が、gitmoji の公式一覧にあるかを確かめる。
# 使い方: python3 check_gitmoji.py < メッセージのファイル
#
# 終了コード: 0 = すべて一覧にある / 1 = 一覧にない絵文字がある / 2 = 一覧を取れなかった
# 一覧は ~/.cache/gitmoji.json に1日置いて使い回す。

import json
import sys
import time
import urllib.request
from pathlib import Path

URL = "https://gitmoji.dev/api/gitmojis"
CACHE = Path.home() / ".cache" / "gitmoji.json"
CACHE_SECONDS = 24 * 60 * 60


def normalize(emoji):
    # ⚡️ と ⚡ のように、異体字セレクタの有無だけが違うものを同じに扱う
    return emoji.replace("\ufe0f", "")


def load_gitmojis():
    if CACHE.exists() and time.time() - CACHE.stat().st_mtime < CACHE_SECONDS:
        return json.loads(CACHE.read_text())
    # 既定の User-Agent は 403 で弾かれる
    req = urllib.request.Request(URL, headers={"User-Agent": "check-gitmoji"})
    with urllib.request.urlopen(req, timeout=10) as res:
        data = json.load(res)["gitmojis"]
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(data, ensure_ascii=False))
    return data


def main():
    try:
        gitmojis = load_gitmojis()
    except Exception as e:
        print(f"gitmoji の一覧を取れませんでした: {e}", file=sys.stderr)
        return 2

    known = {normalize(g["emoji"]): g["description"] for g in gitmojis}
    unknown = []
    for line in sys.stdin.read().splitlines():
        if not line.startswith("### "):
            continue
        emoji = line[4:].split(" ", 1)[0]
        if normalize(emoji) not in known:
            unknown.append(line)

    for line in unknown:
        print(f"一覧にない絵文字: {line}")
    return 1 if unknown else 0


if __name__ == "__main__":
    sys.exit(main())
