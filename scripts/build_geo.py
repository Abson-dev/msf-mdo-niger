"""Convert the region shapefile (WGS84) to GeoJSON for the app's maps, without GDAL.

Output: data/processed/regions.geojson (one feature per region, property "region" = ADM1_FR)
"""
import json
import os
import struct
from mdo_common import SHP, canon_region, out_path

BASE = os.path.join(SHP, "NER_admbnda_adm1_IGNN_20230720")


def read_dbf(path):
    with open(path, "rb") as f:
        b = f.read()
    n, hlen, rlen = struct.unpack("<IHH", b[4:12])
    fields, p = [], 32
    while b[p] != 0x0D:
        fields.append((b[p:p + 11].split(b"\0")[0].decode(), b[p + 16]))
        p += 32
    recs = []
    for i in range(n):
        r = b[hlen + i * rlen + 1: hlen + (i + 1) * rlen]
        rec, o = {}, 0
        for name, ln in fields:
            rec[name] = r[o:o + ln].decode("utf-8").strip()
            o += ln
        recs.append(rec)
    return recs


def signed_area(ring):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(ring, ring[1:])) / 2


def read_polygons(path):
    """Polygon shapes (type 5) as lists of rings; shapefile outer rings are clockwise, holes counter-clockwise."""
    with open(path, "rb") as f:
        b = f.read()
    p, shapes = 100, []
    while p < len(b):
        clen = struct.unpack(">i", b[p + 4:p + 8])[0] * 2
        c = b[p + 8:p + 8 + clen]
        assert struct.unpack("<i", c[:4])[0] == 5, "expected polygons"
        nparts, npts = struct.unpack("<ii", c[36:44])
        parts = list(struct.unpack(f"<{nparts}i", c[44:44 + 4 * nparts])) + [npts]
        pts = struct.unpack(f"<{2 * npts}d", c[44 + 4 * nparts:44 + 4 * nparts + 16 * npts])
        shapes.append([[[round(pts[2 * k], 4), round(pts[2 * k + 1], 4)] for k in range(a, z)]
                       for a, z in zip(parts[:-1], parts[1:])])
        p += 8 + clen
    return shapes


def to_geometry(rings):
    # group holes under the outer ring before them. Rings keep the shapefile's winding (outer clockwise):
    # plotly draws with d3-geo, which reads counter-clockwise outer rings as "the whole globe minus this shape"
    polys = []
    for ring in rings:
        if signed_area(ring) < 0:
            polys.append([ring])
        else:
            polys[-1].append(ring)
    return {"type": "MultiPolygon", "coordinates": polys}


def main():
    attrs = read_dbf(BASE + ".dbf")
    feats = []
    for a, rings in zip(attrs, read_polygons(BASE + ".shp")):
        region = canon_region(a["ADM1_FR"])
        assert region, a["ADM1_FR"]
        feats.append({"type": "Feature", "properties": {"region": region, "pcode": a["ADM1_PCODE"]},
                      "geometry": to_geometry(rings)})
    with open(out_path("regions.geojson"), "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": feats}, f, ensure_ascii=False, separators=(",", ":"))
    print("regions:", [ft["properties"]["region"] for ft in feats])


if __name__ == "__main__":
    main()
