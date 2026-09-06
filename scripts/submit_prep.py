#!/usr/bin/env python3
"""Turn an `lmx speed-test run` output (run.json) + our power_window.json into the exact
POST /api/speed-tests payload, adding the Verified-run provenance fields the server checks
(promptSha256 / promptSample / outputSha256 / outputSample) and the measured gpuPowerWatts /
peakVramGb. Writes <dir>/payload.json. No network; no secrets.

usage: submit_prep.py runs/<name>/ [runs/<name2>/ ...]
"""
import hashlib, json, re, sys, pathlib

NONCE_RE = re.compile(r"^\[LocalMaxxing cache-bust nonce:[^\]]*\]\s*\n?", re.M)

SUBMIT_FIELDS = {
    "hfId","modelRevision","hardware","engineName","engineVersion","quantization","backend",
    "promptTokens","outputTokens","contextLength","batchSize","prefillTokens",
    "ttftMs","tokSOut","tokSPrefill","tokSTotal","peakVramGb","gpuPowerWatts","hardwareCost","notes","engineFlags",
    "promptSha256","promptSample","outputSha256","outputSample","engineTimingsRaw",
}
ENGINE_FLAG_FIELDS = {
    "commandSnippet","tensorParallel","pipelineParallel","gpuLayers","splitMode","kvCacheDtype","gpuMemUtil",
    "kvCacheSizeMb","prefixCaching","attentionBackend","flashAttn","chunkedPrefill","prefillChunkSize","contBatching",
    "cpuOffloadGb","cpuLayers","ropeScaling","ropeScale","yarnExtFactor","engineQuant","sglangQuant","maxRunningSeqs",
    "schedulerDelayFactor","numParallel","concurrency","specDecoding","specMethod","specModel","specNumTokens",
    "specNgramSize","specDraftTp","specDraftWindowSize","mtpEnabled","mtpDraftLayers","temperature","topP","topK",
    "minP","repeatPenalty","mirostat","extraFlags","specDraftTokens","specAcceptedTokens","specAcceptanceRate",
    "specMeanAcceptedLength",
}

def sample(text, head=3000, tail=1000, limit=4000):
    if len(text) <= limit:
        return text
    return text[:head] + "\n…\n" + text[-tail:]

def prep(d: pathlib.Path):
    run = json.load(open(d / "run.json"))
    pw = json.load(open(d / "power_window.json")) if (d / "power_window.json").exists() else {}
    meta = json.load(open(d / "meta.json")) if (d / "meta.json").exists() else {}
    p = {k: v for k, v in run.items() if k in SUBMIT_FIELDS and v is not None}
    ef = {k: v for k, v in (run.get("engineFlags") or {}).items() if k in ENGINE_FLAG_FIELDS and v is not None}
    ef.update({k: v for k, v in meta.get("engineFlags", {}).items() if v is not None})
    if "commandSnippet" not in ef and meta.get("commandSnippet"):
        ef["commandSnippet"] = meta["commandSnippet"]
    if ef:
        p["engineFlags"] = ef
    # Verified-run provenance (server hashes the prompt WITHOUT the nonce line)
    prompt = run.get("prompt") or ""
    clean = NONCE_RE.sub("", prompt)
    if clean:
        p["promptSha256"] = hashlib.sha256(clean.encode()).hexdigest()
        p["promptSample"] = clean[:2000]
    out = run.get("outputText") or ""
    if out:
        p["outputSha256"] = hashlib.sha256(out.encode()).hexdigest()
        p["outputSample"] = sample(out)
    if meta.get("engineTimingsRaw"):
        p["engineTimingsRaw"] = meta["engineTimingsRaw"]
    # measured power / VRAM from the 1 Hz nvidia-smi sampler over the timed window
    if pw.get("power_w_mean_active"):
        p["gpuPowerWatts"] = [round(pw["power_w_mean_active"], 1)]
    if pw.get("mem_mib_max") and "peakVramGb" not in p:
        p["peakVramGb"] = round(pw["mem_mib_max"] / 1024, 1)
    p["batchSize"] = p.get("batchSize", 1)
    for k in ("promptTokens", "outputTokens", "prefillTokens", "contextLength"):  # API wants ints; lmx medians can be x.5
        if isinstance(p.get(k), float):
            p[k] = int(round(p[k]))
    if "contextLength" not in p:  # llama.cpp remote runs: take it from the serve command (-c N / --max-model-len N)
        m = re.search(r"(?:\s-c\s+|--ctx-size\s+|--max-model-len\s+)(\d+)", ef.get("commandSnippet", ""))
        if m:
            p["contextLength"] = int(m.group(1))
    # never leak pod identifiers
    blob = json.dumps(p)
    for bad in re.findall(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", blob):
        if bad in ("127.0.0.1", "0.0.0.0"):  # loopback in the serve command is not a pod identifier
            continue
        raise SystemExit(f"IP-like string in payload {d}: {bad}")
    if re.search(r"bhk_[0-9a-f]{40}|hf_[A-Za-z0-9]{20,}", blob):
        raise SystemExit(f"secret-like string in payload {d}")
    json.dump(p, open(d / "payload.json", "w"), indent=1, ensure_ascii=False)
    conc = ef.get("concurrency", 1)
    ver_ok = (p.get("batchSize", 1) == 1 and conc in (None, 1) and p.get("outputTokens", 0) >= 256
              and "promptSha256" in p and "outputSample" in p)
    return p, ver_ok

if __name__ == "__main__":
    for a in sys.argv[1:]:
        d = pathlib.Path(a)
        p, ver = prep(d)
        print(f"{d.name}: tokSOut={p.get('tokSOut')} conc={p.get('engineFlags',{}).get('concurrency',1)} "
              f"power={p.get('gpuPowerWatts')} vram={p.get('peakVramGb')} verified-eligible={ver}"
              f"{'' if p.get('engineTimingsRaw') else ' (engineTimingsRaw missing -> badge needs it)'} -> {d/'payload.json'}")
