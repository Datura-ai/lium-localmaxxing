#!/usr/bin/env python3
"""Dry-run and submit LocalMaxxing speed-test payloads (POST /api/speed-tests — the exact path every run in
results/ took). The key is read from $LMX_API_KEY, or from /workspace/secrets/lmx_api_key (mode 600) — never argv, never
logs. Writes <dir>/submit_response.json. Rate limit: 1 submission/min, 30/h per key.

usage: submit.py [--dry-run|--submit] /workspace/runs/<dir>/ [...]
"""
import json, os, sys, time, pathlib, urllib.request, urllib.error

def _key():
    k = os.environ.get("LMX_API_KEY", "").strip()
    f = pathlib.Path("/workspace/secrets/lmx_api_key")
    if not k and f.exists():
        k = f.read_text().strip()
    if not k:
        sys.exit("LMX_API_KEY not set (export it, or write it to /workspace/secrets/lmx_api_key with mode 600)")
    return k

KEY = _key()
BASE = "https://www.localmaxxing.com"

def post(path, body):
    req = urllib.request.Request(BASE + path, data=json.dumps(body).encode(),
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                                          "User-Agent": "lium-localmaxxing-repro/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.load(r), dict(r.headers)
    except urllib.error.HTTPError as e:
        try: body = json.load(e)
        except Exception: body = {"raw": e.read().decode(errors="ignore")[:500]}
        return e.code, body, dict(e.headers)

def main():
    mode = sys.argv[1]; dirs = [pathlib.Path(a) for a in sys.argv[2:]]
    for i, d in enumerate(dirs):
        p = json.load(open(d / "payload.json"))
        if mode == "--dry-run":
            st, b, h = post("/api/speed-tests/dry-run", p)
            print(f"{d.name}: {st} {json.dumps(b)[:300]}")
            json.dump({"status": st, "body": b}, open(d / "dryrun_response.json", "w"), indent=1)
        else:
            if (d / "submit_response.json").exists() and json.load(open(d / "submit_response.json")).get("status") == 201:
                print(f"{d.name}: already submitted, skipping"); continue
            st, b, h = post("/api/speed-tests", p)
            rid = b.get("id"); ver = b.get("verifiedRun"); issues = b.get("verificationIssues")
            user = b.get("user", {}) if isinstance(b.get("user"), dict) else {}
            print(f"{d.name}: {st} id={rid} status={b.get('status')} verifiedRun={ver} issues={issues} "
                  f"user.verified={user.get('verified')} remaining={h.get('X-RateLimit-Remaining')} "
                  f"url={BASE}/en/runs/{rid if rid else '?'}")
            if st != 201: print("   body:", json.dumps(b)[:600])
            json.dump({"status": st, "body": b, "submittedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                       "url": f"{BASE}/en/runs/{rid}" if rid else None}, open(d / "submit_response.json", "w"), indent=1)
            if i < len(dirs) - 1:
                wait = 65
                if st == 429:
                    wait = int(b.get("retryAfterMs", 65000)) / 1000 + 2
                time.sleep(wait)

if __name__ == "__main__":
    main()
