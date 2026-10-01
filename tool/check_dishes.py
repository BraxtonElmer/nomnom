"""Cross-checks the dish tables against USDA prepared and restaurant foods.

For each dish, finds USDA entries whose name shares the dish's key words and
prints both energy values, flagging differences over 30%. USDA has no entry
for many regional dishes, and word overlap gives false matches ("hot dog" vs
pickle relish), so every flag needs a human read. Last review: 2026-10-01,
20 flags, 5 real corrections, the rest false matches.
Usage: python tool/check_dishes.py
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "data")
STOP = {"with", "and", "of", "the", "a", "plain", "home", "style", "veg", "fresh", "pizza"}


def words(s):
    return {w.rstrip("s") for w in re.findall(r"[a-z]+", s.lower()) if w not in STOP and len(w) > 2}


usda = json.load(open(os.path.join(ROOT, "usda.json"), encoding="utf-8"))
prepared = [r for r in usda if not re.search(r"\braw\b|dry|powder|frozen, unprepared|uncooked", r[1].lower())]

flagged = 0
for name in sorted(os.listdir(os.path.join(ROOT, "dishes"))):
    for d in json.load(open(os.path.join(ROOT, "dishes", name), encoding="utf-8")):
        key = words(d[1])
        if not key:
            continue
        hits = [r for r in prepared if key <= words(r[1])]
        hits.sort(key=lambda r: len(r[1]))
        if not hits:
            continue
        ref = hits[0]
        diff = (d[3] - ref[2]) / ref[2] if ref[2] else 0
        mark = "  <-- check" if abs(diff) > 0.30 else ""
        if mark:
            flagged += 1
        print(f"{d[0]:28} {d[3]:5.0f} vs {ref[2]:5.0f} ({diff:+.0%})  {ref[1][:70]}{mark}")
print(f"\n{flagged} dishes differ from their closest USDA match by more than 30%")
