#!/usr/bin/env python3
"""Companion non-streamed request on the same server/config right after the lmx run.
Captures the engine's verbatim usage (vLLM) / timings (llama.cpp) object -> meta.json engineTimingsRaw,
plus commandSnippet (exact serve command) and engineFlags derived from it.
usage: capture_meta.py <rundir> <engine> <served_model> <max_tokens> <serve_cmd_file> <concurrency>"""
import json, sys, re, secrets, urllib.request, pathlib
d, engine, served, maxtok, servefile, conc = sys.argv[1:]
d = pathlib.Path(d)
prompt = open("/workspace/lmx/prompt_reasoning-v1.txt").read()
nonce = f"[LocalMaxxing cache-bust nonce: {secrets.token_hex(8)}]\n"
body = {"model": served, "messages": [{"role": "user", "content": nonce + prompt}],
        "max_tokens": int(maxtok), "temperature": 0, "stream": False}
def spec_metrics():
    """vLLM Prometheus counters for speculative decoding (None if the server has none)."""
    try:
        with urllib.request.urlopen("http://127.0.0.1:8000/metrics", timeout=30) as r:
            txt = r.read().decode()
    except Exception:
        return None
    out = {}
    for line in txt.splitlines():
        for key in ("spec_decode_num_draft_tokens_total", "spec_decode_num_accepted_tokens_total", "spec_decode_num_drafts_total"):
            if line.startswith("vllm:" + key):
                out[key] = out.get(key, 0.0) + float(line.rsplit(" ", 1)[1])
    return out or None

m0 = spec_metrics()
req = urllib.request.Request("http://127.0.0.1:8000/v1/chat/completions", data=json.dumps(body).encode(),
                             headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req, timeout=900) as r:
    resp = json.load(r)
m1 = spec_metrics()
json.dump(resp, open(d / "companion_response.json", "w"), indent=1)
raw = resp.get("timings") or resp.get("usage")
cmd = open(servefile).read().strip()
ef = {"temperature": 0}
m = re.search(r"--tensor-parallel-size\s+(\d+)|-tp\s+(\d+)", cmd); ef["tensorParallel"] = int(next(g for g in m.groups() if g)) if m else 1
m = re.search(r"--gpu-memory-utilization\s+([\d.]+)", cmd); ef["gpuMemUtil"] = float(m.group(1)) if m else None
ef["prefixCaching"] = "--enable-prefix-caching" in cmd or ("--no-enable-prefix-caching" not in cmd and engine == "vllm")
m = re.search(r"--max-num-seqs\s+(\d+)", cmd); ef["maxRunningSeqs"] = int(m.group(1)) if m else None
m = re.search(r"--kv-cache-dtype\s+(\S+)", cmd); ef["kvCacheDtype"] = m.group(1) if m else None
m = re.search(r"--attention-backend\s+(\S+)", cmd); ef["attentionBackend"] = m.group(1) if m else None
if "--speculative-config" in cmd:
    ef["specDecoding"] = True
    m = re.search(r'"method"\s*:\s*"([^"]+)"', cmd); ef["specMethod"] = m.group(1) if m else None
    m = re.search(r'"num_speculative_tokens"\s*:\s*(\d+)', cmd); ef["specNumTokens"] = int(m.group(1)) if m else None
    m = re.search(r'"model"\s*:\s*"([^"]+)"', cmd); ef["specModel"] = m.group(1).split("/")[-1] if m else None
    if not ef.get("specMethod") and ef.get("specModel"):
        low = ef["specModel"].lower(); ef["specMethod"] = "dspark" if "dspark" in low else "dflash" if "dflash" in low else "draft_model"
    if ef.get("specMethod") == "mtp": ef["mtpEnabled"] = True
if ef.get("specDecoding") and m0 and m1:
    dr = m1.get("spec_decode_num_draft_tokens_total", 0) - m0.get("spec_decode_num_draft_tokens_total", 0)
    ac = m1.get("spec_decode_num_accepted_tokens_total", 0) - m0.get("spec_decode_num_accepted_tokens_total", 0)
    nd = m1.get("spec_decode_num_drafts_total", 0) - m0.get("spec_decode_num_drafts_total", 0)
    if dr > 0:
        ef["specDraftTokens"] = int(dr); ef["specAcceptedTokens"] = int(ac)
        ef["specAcceptanceRate"] = round(ac / dr, 4)
        if nd > 0: ef["specMeanAcceptedLength"] = round(1 + ac / nd, 3)
        meta_spec = {"draftTokens": int(dr), "acceptedTokens": int(ac), "drafts": int(nd),
                     "source": "vLLM /metrics counters delta around the companion request"}
    else:
        meta_spec = {"note": "no spec_decode counters moved during the companion request"}
elif isinstance(raw, dict) and raw.get("draft_n"):  # llama.cpp timings carry per-request draft stats
    ef["specDecoding"] = True
    ef["specDraftTokens"] = int(raw["draft_n"]); ef["specAcceptedTokens"] = int(raw.get("draft_n_accepted", 0))
    ef["specAcceptanceRate"] = round(ef["specAcceptedTokens"] / ef["specDraftTokens"], 4)
    meta_spec = {"draftTokens": ef["specDraftTokens"], "acceptedTokens": ef["specAcceptedTokens"], "source": "llama.cpp timings.draft_n / draft_n_accepted of the companion request"}
else:
    meta_spec = None
if engine != "vllm":  # llama.cpp flags
    m = re.search(r"\s-c\s+(\d+)", cmd); ef["gpuLayers"] = 99 if re.search(r"-ngl\s+(99|999)", cmd) else None
    ef["flashAttn"] = bool(re.search(r"-fa\s+on|--flash-attn\s+on", cmd)) or None
    m = re.search(r"--spec-type\s+(\S+)", cmd)
    if m:
        ef["specDecoding"] = True; ef["specMethod"] = m.group(1)
        m2 = re.search(r"--spec-draft-n-max\s+(\d+)", cmd); ef["specNumTokens"] = int(m2.group(1)) if m2 else None
        m3 = re.search(r"\s-md\s+(\S+)", cmd); ef["specModel"] = m3.group(1).split("/")[-1] if m3 else None
    ef.pop("gpuMemUtil", None); ef.pop("maxRunningSeqs", None); ef["prefixCaching"] = None
ef["contBatching"] = True
if int(conc) > 1: ef["concurrency"] = int(conc)
ef = {k: v for k, v in ef.items() if v is not None}
meta = {"engineTimingsRaw": raw, "commandSnippet": cmd,
        "engineTimingsRawNote": f"companion non-streamed request on the same server/config right after the lmx run; canonical reasoning-v1 prompt + nonce; max_tokens {maxtok}, greedy",
        "engineFlags": ef, "specStats": meta_spec}
json.dump(meta, open(d / "meta.json", "w"), indent=1)
print("meta:", json.dumps(raw))
