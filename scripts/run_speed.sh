#!/bin/bash
# One LocalMaxxing speed test against a running OpenAI-compatible server on the pod, with a power window and a
# companion request for engineTimingsRaw. Produces
#   /workspace/runs/<OUT>/{run.json,lmx_status.jsonl,power_window.json,power_window.csv,meta.json,hardware.json,nvidia-smi-q.txt,companion_response.json}
# usage: run_speed.sh <OUT> <ENGINE vllm|llama.cpp> <HFID> <SERVED> <QUANT> <ENGINE_VERSION> <CONC> <ITER> <MAXTOK> <NOTES> <SERVE_CMD_FILE> [extra lmx flags...]
# This is the exact invocation behind every run in results/: canonical reasoning-v1 prompt, greedy, 2 untimed warm-ups,
# <ITER> timed iterations (median reported), --concurrency <CONC> for aggregate runs.
set -uo pipefail
OUT=$1; ENGINE=$2; HFID=$3; SERVED=$4; QUANT=$5; EVER=$6; CONC=$7; ITER=$8; MAXTOK=$9; NOTES=${10}; SERVECMD=${11}; shift 11
BASE=http://127.0.0.1:8000
export PATH=/workspace/bin:$PATH
D=/workspace/runs/$OUT; mkdir -p "$D"
CONCFLAG=""; [ "$CONC" != "1" ] && CONCFLAG="--concurrency $CONC"
SAMPLER=/workspace/logs/power_sampler.csv

T0=$(date +%s.%N)
lmx speed-test run $ENGINE --mode remote --base-url $BASE --hf-id "$HFID" --served-model "$SERVED" \
  --quantization "$QUANT" --backend cuda --hardware /workspace/lmx/hardware.json \
  --prompt-file /workspace/lmx/prompt_reasoning-v1.txt --max-tokens "$MAXTOK" --temperature 0 \
  --warmup 2 --iterations "$ITER" $CONCFLAG "$@" \
  --json --json-status --out "$D/run.json" > "$D/lmx_stdout.json" 2> "$D/lmx_status.jsonl"
RC=$?
T1=$(date +%s.%N)
echo "lmx rc=$RC"
nvidia-smi -q -d CLOCK,POWER,MEMORY > "$D/nvidia-smi-q.txt"
cp /workspace/lmx/hardware.json "$D/hardware.json"
python3 /workspace/lmx/power_window.py "$SAMPLER" "$T0" "$T1" "$D"

# engineVersion + notes (flags not supported by `run` in lmx v0.1.39): inject post-hoc
lmx speed-test runs edit "$D/run.json" --set-json "{\"engineVersion\":\"$EVER\",\"notes\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$NOTES")}" >/dev/null 2>&1 || \
python3 - "$D/run.json" "$EVER" "$NOTES" <<'EOF'
import json,sys; f,ev,n=sys.argv[1:]; r=json.load(open(f)); r["engineVersion"]=ev; r["notes"]=n; json.dump(r,open(f,"w"),indent=1)
EOF

# companion request: verbatim engine usage/timings object -> engineTimingsRaw (+ spec-decode draft/accepted counts)
python3 /workspace/lmx/capture_meta.py "$D" "$ENGINE" "$SERVED" "$MAXTOK" "$SERVECMD" "$CONC"
python3 -c "
import json; r=json.load(open('$D/run.json')); s=r.get('sampleStats',{})
print('RESULT $OUT tokSOut=',r.get('tokSOut'),'ttftMs=',r.get('ttftMs'),'outTok=',r.get('outputTokens'),'promptTok=',r.get('promptTokens'),'stats=',json.dumps(s)[:300])"
