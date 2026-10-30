"""How close is a last-gen game's stock output, read as PQ, to the engine's own HDR light?

A game tone-maps scene light x (relative, 0.18 = mid grey) to T(x) in [0, 1], gamma-encodes it and sends
code value V. When the signal is flagged as HDR10, the TV reads V as PQ: L = PQ_EOTF(V) nits.

The reference is the engine's own light at HDR reference exposure: 18% grey at 26 nits (ITU-R BT.2408),
so ref(x) = 26 * x / 0.18. For each stop the script prints the PQ read, its offset from the reference in
stops, the local log slope (1.0 means it tracks the engine's light exactly) and the luminance step one
8-bit code makes under PQ, then where the highlights clip (code 255).

The generic curves are stand-ins (Hable filmic, Reinhard, the Narkowicz ACES fit), not measurements of
any particular game. A measured curve comes in with --curve: a CSV of `scene_x,code_v` rows (code_v 0..1, the value
the game sends; '#' lines are comments), interpolated in log x.

--edge measures texture contrast on one patch of a frame: mean |gradient of log2 luminance| (stops per
pixel) of the PQ read against the pre-tone-map frame (scene light in the same x units). A ratio of 1.0
means edges and texture keep the engine's contrast.

Usage:
    python tools/pq_read_closeness.py [--gamma 2.2] [--curve re6.csv [--curve bo2.csv]] [--only-measured]
    python tools/pq_read_closeness.py --edge pre_x.npy out.png x0,y0,x1,y1
"""
import argparse
import bisect
import csv
import math
import os

M1, M2 = 2610 / 16384, 2523 / 4096 * 128
C1, C2, C3 = 3424 / 4096, 2413 / 4096 * 32, 2392 / 4096 * 32
REF_GREY_NITS = 26.0  # ITU-R BT.2408, 18% grey


def pq_eotf(v):
    p = v ** (1 / M2)
    return 10000 * (max(p - C1, 0) / (C2 - C3 * p)) ** (1 / M1)


def _hable(x):
    a, b, c, d, e, f = 0.15, 0.50, 0.10, 0.20, 0.02, 0.30
    return ((x * (a * x + c * b) + d * e) / (x * (a * x + b) + d * f)) - e / f


def hable(x, bias=2.0, white=11.2):
    return min(_hable(x * bias) / _hable(white), 1.0)


def reinhard(x):
    return x / (1 + x)


def aces_fit(x):
    x *= 0.6
    return min(max((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0), 1.0)


CURVES = {"Hable filmic": hable, "Reinhard": reinhard, "ACES fit (Narkowicz)": aces_fit}


def gamma_code(tone_map, gamma):
    """A generic curve as code value: T(x) gamma-encoded."""
    return lambda x: tone_map(x) ** (1 / gamma)


def load_curve(path):
    """Measured curve: code_v(x) from a `scene_x,code_v` CSV, linear in log2 x, held flat past the ends."""
    rows = []
    with open(path, newline="") as f:
        for r in csv.reader(line for line in f if line.strip() and not line.startswith("#")):
            try:
                x, v = float(r[0]), float(r[1])
            except ValueError:
                continue  # header
            if x > 0:
                rows.append((math.log2(x), v))
    rows.sort()
    lx = [r[0] for r in rows]
    vs = [r[1] for r in rows]

    def code(x):
        t = math.log2(max(x, 1e-12))
        i = bisect.bisect_left(lx, t)
        if i <= 0:
            return vs[0]
        if i >= len(lx):
            return vs[-1]
        a = (t - lx[i - 1]) / (lx[i] - lx[i - 1])
        return vs[i - 1] + a * (vs[i] - vs[i - 1])

    return code


def clip_point(code):
    """Smallest scene x whose code reaches 255, searched over -8..+12 stops, or None."""
    for i in range(0, 2001):
        x = 0.18 * 2 ** (-8 + i * 0.01)
        if code(x) >= 254.5 / 255:
            return x
    return None


def table(name, code):
    print(f"\n{name}, read as PQ (reference: 18% grey = {REF_GREY_NITS:g} nits)")
    print(" stop  scene_x  code_V  PQ_nits  ref_nits  vs_ref_stops  log_slope  8bit_step")
    for stop in range(-5, 7):
        x = 0.18 * 2 ** stop
        v = code(x)
        nits = pq_eotf(v)
        ref = REF_GREY_NITS * x / 0.18
        nits2 = pq_eotf(code(x * 1.05))
        slope = (math.log(nits2) - math.log(nits)) / math.log(1.05) if nits > 0 and nits2 > 0 else float("nan")
        vs_ref = math.log2(nits / ref) if nits > 0 else float("nan")
        step = (pq_eotf(min(v + 1 / 255, 1.0)) / nits - 1) * 100 if nits > 0 else float("nan")
        print(f" {stop:+3d}  {x:7.4f}  {v:6.3f}  {nits:7.1f}  {ref:8.1f}  {vs_ref:+12.2f}  {slope:9.2f}  {step:8.1f}%")
    cx = clip_point(code)
    if cx:
        print(f" highlights clip at code 255 (10000 nits as PQ; the panel tone-maps it) from scene x {cx:.2f}, "
              f"{math.log2(cx / 0.18):+.2f} stops over mid grey")
    else:
        print(" highlights don't reach code 255 within +12 stops")


def edge(pre_path, out_path, rect):
    """Texture contrast of one patch: PQ read of the final frame vs the pre-tone-map light."""
    import numpy as np
    from PIL import Image

    x0, y0, x1, y1 = rect
    pre = np.load(pre_path).astype(np.float64)
    if pre.ndim == 3:
        pre = pre[..., :3] @ [0.2126, 0.7152, 0.0722]
    out = np.asarray(Image.open(out_path).convert("RGB"), np.float64) / 255
    if out.shape[:2] != pre.shape[:2]:
        raise SystemExit(f"frame sizes differ: pre {pre.shape[:2]}, out {out.shape[:2]}")
    lut = np.array([pq_eotf(i / 255) for i in range(256)])
    pq = lut[np.rint(out * 255).astype(int)]
    sdr = out ** 2.2
    lum = lambda rgb: rgb @ [0.2126, 0.7152, 0.0722]

    def grad(img):
        p = np.log2(np.maximum(img[y0:y1, x0:x1], 1e-6))
        gy, gx = np.gradient(p)
        return float(np.mean(np.hypot(gx, gy)))

    g_pre, g_pq, g_sdr = grad(pre), grad(lum(pq)), grad(lum(sdr))
    print(f"patch {x0},{y0}-{x1},{y1}: mean |grad log2 L| in stops/pixel")
    print(f"  pre-tone-map light {g_pre:.4f}")
    print(f"  final read as PQ   {g_pq:.4f}  ratio {g_pq / g_pre:.2f}")
    print(f"  final read as 2.2  {g_sdr:.4f}  ratio {g_sdr / g_pre:.2f}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--gamma", type=float, default=2.2, help="output gamma for the generic curves (default 2.2)")
    ap.add_argument("--curve", action="append", default=[], help="measured curve CSV (scene_x,code_v)")
    ap.add_argument("--only-measured", action="store_true", help="skip the generic curves")
    ap.add_argument("--edge", nargs=3, metavar=("PRE_NPY", "OUT_PNG", "X0,Y0,X1,Y1"))
    a = ap.parse_args()

    if a.edge:
        edge(a.edge[0], a.edge[1], [int(v) for v in a.edge[2].split(",")])
        return
    if not a.only_measured:
        for name, tm in CURVES.items():
            table(f"{name}, gamma {a.gamma}", gamma_code(tm, a.gamma))
    for path in a.curve:
        table(f"measured: {os.path.basename(path)}", load_curve(path))


if __name__ == "__main__":
    main()
