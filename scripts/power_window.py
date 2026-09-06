#!/usr/bin/env python3
"""Cut the sampler CSV to [t0,t1] and summarise -> power_window.json (+ power_window.csv)
usage: power_window.py <sampler.csv> <t0_epoch> <t1_epoch> <outdir>"""
import sys, json, statistics, pathlib, datetime
src, t0, t1, out = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), pathlib.Path(sys.argv[4])
rows = []
for line in open(src):
    f = line.strip().split(",")
    if len(f) < 7: continue
    try: t = float(f[0])
    except ValueError: continue
    if t0 - 0.5 <= t <= t1 + 0.5:
        rows.append(f)
(out / "power_window.csv").write_text("".join(",".join(r) + "\n" for r in rows))
act = [r for r in rows if float(r[2]) >= 50]  # GPU busy samples
P = lambda rs, i: [float(r[i]) for r in rs]
iso = lambda t: datetime.datetime.utcfromtimestamp(t).strftime("%Y-%m-%dT%H:%M:%SZ")
summ = {
    "window_utc": [iso(t0), iso(t1)], "samples": len(rows), "active_samples": len(act),
    "power_w_mean_active": round(statistics.mean(P(act, 1)), 1) if act else None,
    "power_w_median_active": round(statistics.median(P(act, 1)), 1) if act else None,
    "power_w_max": round(max(P(rows, 1)), 1) if rows else None,
    "mem_mib_max": int(max(P(rows, 3))) if rows else None,
    "sm_clock_mhz_mean_active": int(statistics.mean(P(act, 4))) if act else None,
    "mem_clock_mhz": int(statistics.median(P(rows, 5))) if rows else None,
    "temp_c_max": int(max(P(rows, 6))) if rows else None,
}
json.dump(summ, open(out / "power_window.json", "w"), indent=1)
print(json.dumps(summ))
