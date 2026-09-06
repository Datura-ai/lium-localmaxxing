#!/bin/bash
# reproduce.sh — run ONE recipe end to end on a freshly rented Lium pod (PyTorch CUDA Ubuntu 24.04 template).
#
#   bash scripts/reproduce.sh <recipe> [all|bootstrap|serve|run|submit|stop]
#
# <recipe> = a file name in recipes/ without .env (parameters live at the top of that file: GPU, model, quant, concurrency,
# iterations, max tokens, the verbatim serve line). Steps:
#   bootstrap  engine + lmx CLI + weights (bootstrap.sh for vLLM, bootstrap_gguf.sh for llama.cpp), 1 Hz power sampler, hardware.json
#   serve      start the server from the recipe's SERVE_CMD, wait for /v1/models
#   run        lmx speed-test run (canonical reasoning-v1 prompt, greedy, 2 warm-ups, N timed iterations) + power window
#              + companion request -> /workspace/runs/<RUN_NAME>/{run.json,meta.json,power_window.json,payload.json}
#   submit     dry-run + POST the payload to LocalMaxxing under YOUR key (skipped, with instructions, if LMX_API_KEY is unset)
#   stop       stop the server and the sampler (the pod itself is torn down from your machine: lium rm <pod> -y)
# Secrets: LMX_API_KEY and HF_TOKEN are read from the environment (or /workspace/secrets/{lmx_api_key,hf_token}, mode 600).
# They are never printed. Do not run this with `set -x`.
# Everything runs on the pod. Run it detached (see README) — bootstrap + first server start can take 10-40 min.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(dirname "$HERE")
RECIPE=${1:?usage: reproduce.sh <recipe> [all|bootstrap|serve|run|submit|stop]   (recipes: $(ls "$REPO/recipes" 2>/dev/null | sed 's/\.env$//' | tr '\n' ' '))}
STEP=${2:-all}
ENV_FILE=$REPO/recipes/$RECIPE.env
[ -f "$ENV_FILE" ] || { echo "no such recipe: $RECIPE"; ls "$REPO/recipes" | sed 's/\.env$//'; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${ENGINE:?}" "${HF_ID:?}" "${SERVED_MODEL:?}" "${QUANT:?}" "${MODELS:?}" "${CONCURRENCY:?}" "${ITERATIONS:?}" "${MAX_TOKENS:?}" "${RUN_NAME:?}" "${SERVE_CMD:?}" "${NOTES:?}"

L=/workspace/lmx; LOGS=/workspace/logs; RUNS=/workspace/runs
mkdir -p $L $LOGS $RUNS /workspace/secrets; chmod 700 /workspace/secrets
[ -z "${HF_TOKEN:-}" ] && [ -f /workspace/secrets/hf_token ] && HF_TOKEN=$(cat /workspace/secrets/hf_token)
[ -n "${HF_TOKEN:-}" ] && export HF_TOKEN
[ -z "${LMX_API_KEY:-}" ] && [ -f /workspace/secrets/lmx_api_key ] && LMX_API_KEY=$(cat /workspace/secrets/lmx_api_key)
export LMX_API_KEY=${LMX_API_KEY:-}
export PATH=/workspace/bin:/root/.local/bin:$PATH
LLAMACPP_IMAGE=${LLAMACPP_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda}
GGUF_DIR=/workspace/gguf

# stage the measurement scripts where they expect to live (same paths as the original runs)
cp "$HERE"/{bootstrap.sh,bootstrap_gguf.sh,env.sh,run_speed.sh,srv.sh,power_sampler.sh,power_window.py,capture_meta.py,submit_prep.py,submit.py} $L/
cp "$REPO/configs/prompt_reasoning-v1.txt" $L/prompt_reasoning-v1.txt
echo "$SERVE_CMD" > $L/serve_current.txt
chmod +x $L/*.sh
log() { echo "$(date -u +%FT%TZ) [$RECIPE] $*"; }

sampler_start() {
  pgrep -f power_sampler.sh >/dev/null && return 0
  setsid nohup bash $L/power_sampler.sh $LOGS/power_sampler.csv >/dev/null 2>&1 < /dev/null &
  echo $! > $LOGS/power_sampler.pid
}
hardware_json() {
  # `lmx hardware` detects the GPU on the pod; gpuName must be one of LocalMaxxing's canonical names (lmx context ->
  # hardwareOptions.discreteGpuNames), e.g. "NVIDIA B200", "NVIDIA GeForce RTX 5090", "NVIDIA H100 80GB SXM", "NVIDIA H200 SXM".
  lmx hardware --out $L/hardware.json >/dev/null 2>&1 || true
  if ! lmx hardware validate $L/hardware.json >/dev/null 2>&1; then
    log "hardware.json did not validate — write it by hand, e.g.: lmx hardware template --gpu-name \"NVIDIA GeForce RTX 5090\" --gpu-count 1 --vram-gb 31.8 --cpu \"\$(lscpu | sed -n 's/Model name: *//p')\" --ram-gb \$(free -g | awk '/Mem:/{print \$2}') --os \"Ubuntu 24.04\" --out $L/hardware.json"
    return 1
  fi
  cat $L/hardware.json
}

do_bootstrap() {
  log "bootstrap ($ENGINE): $MODELS"
  if [ "$ENGINE" = vllm ]; then
    # shellcheck disable=SC2086
    bash $L/bootstrap.sh $MODELS 2>&1 | tee $LOGS/bootstrap.log | tail -n 5
    sampler_start
  else
    # shellcheck disable=SC2086
    bash $L/bootstrap_gguf.sh $MODELS 2>&1 | tee $LOGS/bootstrap.log | tail -n 5
  fi
  grep -q DL_FAIL $LOGS/downloads.log 2>/dev/null && { log "a download failed:"; cat $LOGS/downloads.log; return 1; }
  hardware_json || return 1
  log "bootstrap done"
}

llama_start() {
  docker rm -f llamacpp >/dev/null 2>&1
  # shellcheck disable=SC2086
  docker run -d --name llamacpp --gpus all -v $GGUF_DIR:/models -p 127.0.0.1:8000:8000 "$LLAMACPP_IMAGE" $SERVE_CMD > $LOGS/llamacpp.cid 2>&1 || { cat $LOGS/llamacpp.cid; return 1; }
  local t=0
  until curl -sf http://127.0.0.1:8000/v1/models >/dev/null; do
    sleep 5; t=$((t+5))
    docker ps -q -f name=llamacpp | grep -q . || { log "LLAMA_DIED"; docker logs llamacpp 2>&1 | tail -5 | cut -c1-200; return 1; }
    [ $t -ge 900 ] && { log "LLAMA_TIMEOUT"; return 1; }
  done
  log "LLAMA_READY after ${t}s"
}
do_serve() {
  log "serve: $SERVE_CMD"
  if [ "$ENGINE" = vllm ]; then
    SRV_TIMEOUT=${SRV_TIMEOUT:-2400} bash $L/srv.sh start $L/serve_current.txt serve_$RUN_NAME || return 1
  else
    llama_start || return 1
  fi
}
do_stop() {
  if [ "$ENGINE" = vllm ]; then bash $L/srv.sh stop; else docker logs llamacpp > $LOGS/llamacpp_$RUN_NAME.log 2>&1; docker rm -f llamacpp >/dev/null 2>&1; fi
  [ -f $LOGS/power_sampler.pid ] && kill "$(cat $LOGS/power_sampler.pid)" 2>/dev/null && rm -f $LOGS/power_sampler.pid
  log "stopped"
}

engine_version() {
  if [ "$ENGINE" = vllm ]; then /workspace/venv/bin/python -c "import vllm;print(vllm.__version__)"
  else docker run --rm "$LLAMACPP_IMAGE" --version 2>&1 | grep -oE "version: .*" | head -1 | sed 's/version: //'; fi
}
do_run() {
  curl -sf http://127.0.0.1:8000/v1/models >/dev/null || { log "no server on :8000 — run the serve step first"; return 1; }
  [ -f $L/hardware.json ] || hardware_json || return 1
  sampler_start
  EV=$(engine_version); log "engine version: $EV"
  bash $L/run_speed.sh "$RUN_NAME" "$ENGINE" "$HF_ID" "$SERVED_MODEL" "$QUANT" "$EV" "$CONCURRENCY" "$ITERATIONS" "$MAX_TOKENS" \
    "$NOTES Reproduction from the public recipe ($RECIPE)." $L/serve_current.txt | tee $LOGS/run_$RUN_NAME.log | grep -E "^(lmx rc|RESULT|meta:)" | cut -c1-300
  python3 $L/submit_prep.py "$RUNS/$RUN_NAME/"
  python3 - "$RUNS/$RUN_NAME/payload.json" "${MEASURED_TOKS_OUT:-0}" <<'EOF'
import json, sys
p = json.load(open(sys.argv[1])); ours = float(sys.argv[2])
t = p.get("tokSOut"); w = (p.get("gpuPowerWatts") or ["?"])[0]
print(f"\n==> {p['hfId']} on {p['hardware']['gpuName']} x{p['hardware']['gpuCount']} · {p['engineName']} {p.get('engineVersion','')} · {p.get('quantization')} · concurrency {(p.get('engineFlags') or {}).get('concurrency', 1)}")
print(f"    tokSOut {t} tok/s (median of timed iterations) · TTFT {p.get('ttftMs')} ms · {p.get('outputTokens')} output tokens · {w} W · peak VRAM {p.get('peakVramGb')} GB")
if ours: print(f"    our measured run: {ours} tok/s -> yours is {t/ours*100:.1f}% of it")
print(f"    payload: {sys.argv[1]}")
EOF
}

do_submit() {
  local D=$RUNS/$RUN_NAME
  [ -f $D/payload.json ] || { log "no payload yet — run the run step first"; return 1; }
  if [ -z "$LMX_API_KEY" ]; then
    log "LMX_API_KEY is not set — not submitting. To submit under your own account: create a key in the LocalMaxxing dashboard,"
    log "  export LMX_API_KEY=bhk_...   (or write it to /workspace/secrets/lmx_api_key, mode 600) and re-run:  reproduce.sh $RECIPE submit"
    return 0
  fi
  log "dry-run (server-side validation, no write)"
  python3 $L/submit.py --dry-run "$D/" || return 1
  log "submitting (1 request; the API allows 1/min, 30/h)"
  python3 $L/submit.py --submit "$D/"
}

case "$STEP" in
  bootstrap) do_bootstrap ;;
  serve)     do_serve ;;
  run)       do_run ;;
  submit)    do_submit ;;
  stop)      do_stop ;;
  all)
    do_bootstrap && do_serve && do_run && do_submit; RC=$?
    do_stop
    [ $RC -eq 0 ] && echo "REPRODUCE_DONE $RECIPE -> $RUNS/$RUN_NAME/payload.json" || echo "REPRODUCE_FAILED $RECIPE (rc=$RC) — see $LOGS/"
    exit $RC ;;
  *) echo "unknown step: $STEP"; exit 2 ;;
esac
