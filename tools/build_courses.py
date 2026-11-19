"""コースの元(courses/src/<番号>.txt、亀の命令)から courses/<番号>.json を作り、決まりを守っているかを調べる(仕様書 §9.7)。
道具の中では sin・cos を使ってよい(ゲームの core では使わない)。1 つでも外れたら終了コード 1。

    python tools/build_courses.py           作って調べる
    python tools/build_courses.py --check   調べるだけ(JSON を書かない。CI で使う)

元の書き方(1 行 1 命令。# から後は注記):
    name 入門 / width 200 / S <長さ> / R <半径> <度> / L <半径> <度>
"""

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "courses" / "src"
OUT = ROOT / "courses"
COUNT = 16
POINT_STEP = 8.0  # core/balance.gd と同じ
MIN_RADIUS = 120.0
MIN_WIDTH = 160
MIN_LEN, MAX_LEN = 3000.0, 7000.0
FIRST_STRAIGHT = 600.0


def parse(text: str) -> dict:
    c = {"name": "", "width": 0, "cmds": []}
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        head, *args = line.split()
        if head == "name":
            c["name"] = " ".join(args)
        elif head == "width":
            c["width"] = int(args[0])
        elif head == "S" and len(args) == 1:
            c["cmds"].append(("S", float(args[0]), 0.0))
        elif head in ("R", "L") and len(args) == 2:
            c["cmds"].append((head, float(args[0]), float(args[1])))
        else:
            raise ValueError(f"読めない行: {raw}")
    return c


def pieces(cmds):
    """原点・上向きから命令を進め、区間の列 [(種類, 始点, 向き, 長さ, 半径, 符号)] と終わりの点・向きを返す。"""
    x, y, a = 0.0, 0.0, -math.pi / 2  # 向きの角度(y が下向き。-90 度が画面の上)
    out = []
    for kind, v, deg in cmds:
        if kind == "S":
            out.append(("S", x, y, a, v, 0.0, 0))
            x += math.cos(a) * v
            y += math.sin(a) * v
        else:
            sign = 1 if kind == "R" else -1  # R は時計回り(角度が増える)
            phi = math.radians(deg)
            out.append(("A", x, y, a, v * phi, v, sign))
            cx = x + math.cos(a + sign * math.pi / 2) * v
            cy = y + math.sin(a + sign * math.pi / 2) * v
            a2 = a + sign * phi
            x = cx + math.cos(a2 - sign * math.pi / 2) * v
            y = cy + math.sin(a2 - sign * math.pi / 2) * v
            a = a2
    return out, x, y, a


def point_at(p, s):
    kind, x, y, a, _length, r, sign = p
    if kind == "S":
        return x + math.cos(a) * s, y + math.sin(a) * s
    cx = x + math.cos(a + sign * math.pi / 2) * r
    cy = y + math.sin(a + sign * math.pi / 2) * r
    a2 = a + sign * s / r
    return cx + math.cos(a2 - sign * math.pi / 2) * r, cy + math.sin(a2 - sign * math.pi / 2) * r


def sample(ps):
    """1 周を等しい間隔(長さ ÷ round(長さ ÷ 8)、ほぼ 8 px)の点にする。最後の点の次は始めの点に戻る。"""
    total = sum(p[4] for p in ps)
    n = round(total / POINT_STEP)
    pts = []
    k, base = 0, 0.0
    for i in range(n):
        s = total * i / n
        while k < len(ps) - 1 and s >= base + ps[k][4]:
            base += ps[k][4]
            k += 1
        pts.append(point_at(ps[k], s - base))
    return pts, total


def overlaps(pts, width, step):
    """道が重なっていないか(壁と壁の間が 40 px 以上あるか)。輪の上で幅 + 40 より離れた 2 点が、互いに一番近くなる所
    (両方から見て距離が極小)で幅 + 40 未満なら外れ。外れた点の対を返す。
    仕様書の「番号の差が 幅 ÷ 8 + 5 以上の点どうしの距離が 幅 + 40 以上」をそのまま当てると、弦は弧より短いので
    どの円弧でも外れる(入門コースも)。同じ考え「別の所の道が近くに来ない」をこの形で調べる。"""
    n = len(pts)
    lim = width + 40.0
    lim2 = lim * lim
    cell = {}
    for i, (x, y) in enumerate(pts):
        cell.setdefault((int(x // lim), int(y // lim)), []).append(i)

    def d2(i, j):
        i, j = i % n, j % n
        return (pts[i][0] - pts[j][0]) ** 2 + (pts[i][1] - pts[j][1]) ** 2

    bad = []
    for i, (x, y) in enumerate(pts):
        cx, cy = int(x // lim), int(y // lim)
        for gx in (cx - 1, cx, cx + 1):
            for gy in (cy - 1, cy, cy + 1):
                for j in cell.get((gx, gy), []):
                    gap = min(abs(i - j), n - abs(i - j)) * step
                    d = d2(i, j)
                    if gap > lim and d < lim2 and d <= min(d2(i, j - 1), d2(i, j + 1), d2(i - 1, j), d2(i + 1, j)):
                        bad.append((i, j, math.sqrt(d)))
    return bad


def check(c) -> tuple[list[str], dict]:
    errs = []
    ps, ex, ey, ea = pieces(c["cmds"])
    if math.hypot(ex, ey) >= 1.0:
        errs.append(f"閉じていない: 終わりの点が始めから {math.hypot(ex, ey):.3f} px")
    turn = math.degrees(ea + math.pi / 2)
    off = (turn + 180.0) % 360.0 - 180.0
    if abs(off) >= 0.5:
        errs.append(f"終わりの向きが {off:.3f} 度ずれている")
    for kind, v, _deg in c["cmds"]:
        if kind in ("R", "L") and v < MIN_RADIUS:
            errs.append(f"半径 {v} が {MIN_RADIUS} 未満")
        if kind in ("R", "L") and v < (c["width"] + 40) / 2:
            errs.append(f"半径 {v} では内側の壁が重なる((幅 + 40) ÷ 2 = {(c['width'] + 40) / 2} 未満)")
    if c["width"] < MIN_WIDTH:
        errs.append(f"幅 {c['width']} が {MIN_WIDTH} 未満")
    if not c["cmds"] or c["cmds"][0][0] != "S" or c["cmds"][0][1] < FIRST_STRAIGHT:
        errs.append(f"最初の命令が {FIRST_STRAIGHT} px 以上の直進でない")
    pts, total = sample(ps)
    if not MIN_LEN <= total <= MAX_LEN:
        errs.append(f"1 周の長さ {total:.0f} が {MIN_LEN:.0f}〜{MAX_LEN:.0f} の外")
    bad = overlaps(pts, c["width"], total / len(pts))
    if bad:
        i, j, d = min(bad, key=lambda b: b[2])
        errs.append(f"道が重なる: 点 {i} と {j} が {d:.1f} px(幅 + 40 = {c['width'] + 40})")
    return errs, {"name": c["name"], "width": c["width"], "points": [[round(x, 2), round(y, 2)] for x, y in pts], "length": round(total)}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    only_check = "--check" in sys.argv
    failed = 0
    for k in range(COUNT):
        path = SRC / f"{k}.txt"
        if not path.exists():
            print(f"NG  {k}: {path.name} が無い")
            failed += 1
            continue
        errs, data = check(parse(path.read_text(encoding="utf-8")))
        if errs:
            failed += 1
            print(f"NG  {k} {data['name']}: " + " / ".join(errs))
            continue
        print(f"OK  {k} {data['name']}: 長さ {data['length']} px、点 {len(data['points'])}、幅 {data['width']}")
        if not only_check:
            (OUT / f"{k}.json").write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    print(f"{COUNT} 本中 {COUNT - failed} 本が通った")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
