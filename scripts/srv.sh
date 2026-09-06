#!/bin/bash
# vLLM server lifecycle. usage:
#   srv.sh start <serve_cmd_file> <logname>   -> runs the `vllm serve ...` line in the file verbatim (quoting preserved) inside the
#                                               venv, detached; waits until /v1/models answers or exits 1 after $SRV_TIMEOUT s (default 1500)
#   srv.sh stop                               -> stops the server (process group from the PID file, then pattern fallback) and waits for VRAM to free
source /workspace/lmx/env.sh
PIDF=/workspace/logs/serve.pid
case "$1" in
  start)
    F=$2; LOG=/workspace/logs/$3.log
    { echo '#!/bin/bash'; echo 'source /workspace/lmx/env.sh'; cat "$F"; } > /workspace/lmx/_serve_current.sh
    setsid nohup bash /workspace/lmx/_serve_current.sh > "$LOG" 2>&1 < /dev/null &
    echo $! > "$PIDF"
    T=${SRV_TIMEOUT:-1500}; t=0
    while ! curl -sf http://127.0.0.1:8000/v1/models >/dev/null; do
      sleep 5; t=$((t+5))
      if ! pgrep -f "venv/bin/vllm serve" >/dev/null; then echo "SERVER_DIED $3"; tr '\r' '\n' < "$LOG" | grep -E "Error|error" | grep -vE 'File "|\^\^\^|core.py:[0-9]+\]   ' | tail -5 | cut -c1-300; exit 1; fi
      [ $t -ge $T ] && { echo "SERVER_TIMEOUT $3"; exit 1; }
    done
    echo "SERVER_READY $3 after ${t}s"; tr '\r' '\n' < "$LOG" | grep -E "KV cache size|Maximum concurrency" | tail -1 | cut -c1-200 ;;
  stop)
    if [ -f "$PIDF" ]; then kill -TERM -- "-$(cat "$PIDF")" 2>/dev/null; fi
    sleep 6
    pkill -f "venv/bin/vllm serve" 2>/dev/null; pkill -f "VLLM::EngineCore" 2>/dev/null
    while pgrep -f "VLLM::EngineCore" >/dev/null; do sleep 2; done
    rm -f "$PIDF"
    nvidia-smi --query-gpu=memory.used --format=csv,noheader ;;
esac
