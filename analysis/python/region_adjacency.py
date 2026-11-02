"""Which regions share a border, from data/processed/regions.geojson (shared boundary vertices).

Output: data/processed/region_adjacency.csv (region_a, region_b, shared_vertices)
"""
import json
import os
from itertools import combinations

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
geo = json.load(open(os.path.join(ROOT, "data", "processed", "regions.geojson"), encoding="utf-8"))

pts = {}
for f in geo["features"]:
    s = set()
    for poly in f["geometry"]["coordinates"]:
        for ring in poly:
            s.update((round(x, 3), round(y, 3)) for x, y in ring)
    pts[f["properties"]["region"]] = s

rows = []
for a, b in combinations(sorted(pts), 2):
    n = len(pts[a] & pts[b])
    if n >= 3:   # a shared border, not a single touching point
        rows.append((a, b, n))

out = os.path.join(ROOT, "data", "processed", "region_adjacency.csv")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("region_a,region_b,shared_vertices\n")
    for r in rows:
        fh.write(f"{r[0]},{r[1]},{r[2]}\n")
for r in rows:
    print(*r, sep="  ")
