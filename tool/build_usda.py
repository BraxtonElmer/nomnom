"""Builds assets/data/usda.json from the USDA FoodData Central SR Legacy CSVs.

Download: https://fdc.nal.usda.gov/download-datasets (SR Legacy, CSV)
Usage:    python tool/build_usda.py path/to/FoodData_Central_sr_legacy_food_csv_2018-04

Output rows: [id, description, kcal, protein, carbs, fat, fiber, [[portion, grams], ...]]
All nutrient values are per 100 g. SR Legacy is public domain.
"""

import csv
import json
import os
import sys

NUTRIENTS = {"1008": 0, "1003": 1, "1005": 2, "1004": 3, "1079": 4}
SKIP_CATEGORIES = {"3", "24", "26", "27"}  # baby foods, regional native, branded, QC
MAX_PORTIONS = 6


def read(folder, name):
    with open(os.path.join(folder, name), encoding="utf-8") as f:
        yield from csv.DictReader(f)


def main(folder):
    foods = {}
    for row in read(folder, "food.csv"):
        if row["food_category_id"] in SKIP_CATEGORIES:
            continue
        foods[row["fdc_id"]] = {"d": row["description"], "n": [None] * 5, "p": []}

    for row in read(folder, "food_nutrient.csv"):
        food = foods.get(row["fdc_id"])
        idx = NUTRIENTS.get(row["nutrient_id"])
        if food is not None and idx is not None and row["amount"]:
            food["n"][idx] = round(float(row["amount"]), 1)

    units = {r["id"]: r["name"] for r in read(folder, "measure_unit.csv")}
    for row in read(folder, "food_portion.csv"):
        food = foods.get(row["fdc_id"])
        if food is None or len(food["p"]) >= MAX_PORTIONS:
            continue
        unit = units.get(row["measure_unit_id"], "")
        unit = "" if unit == "undetermined" else unit
        label = " ".join(
            s for s in [row["amount"].removesuffix(".0"), unit, row["modifier"]] if s
        ).strip()
        grams = float(row["gram_weight"] or 0)
        if label and grams > 0:
            food["p"].append([label, round(grams, 1)])

    rows = []
    for fdc_id, f in foods.items():
        kcal, protein, carbs, fat, fiber = f["n"]
        if kcal is None:
            continue
        rows.append([int(fdc_id), f["d"], kcal, protein or 0, carbs or 0, fat or 0, fiber or 0, f["p"]])
    rows.sort(key=lambda r: r[1])

    out = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "usda.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(rows)} foods -> {os.path.normpath(out)} ({os.path.getsize(out) // 1024} KB)")


if __name__ == "__main__":
    main(sys.argv[1])
