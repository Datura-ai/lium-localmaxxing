#!/bin/bash
# Light bootstrap for the llama.cpp recipes (no vLLM): lmx CLI, hf downloader, power sampler, hardware.json,
# the official llama.cpp CUDA server container, and GGUF downloads onto /workspace/gguf.
# /workspace/gguf (overlay FS) on purpose: docker-in-docker cannot bind-mount the encrypted /root volume on this template.
# usage (detached): nohup setsid bash /workspace/lmx/bootstrap_gguf.sh "org/repo::<include-glob>" ... > /workspace/logs/bootstrap.log 2>&1 &
# HF_TOKEN (optional) is read from the environment by `hf download`.
set -uo pipefail
LMX_VERSION=${LMX_VERSION:-v0.1.39}
LLAMACPP_IMAGE=${LLAMACPP_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda}   # resolved to build 10818 (commit 4d9176092) on 6 Sep 2026
mkdir -p /workspace/{lmx,gguf,runs,logs,bin}
cd /workspace

if [ ! -x /workspace/bin/lmx ]; then
  curl -fsSL -o /workspace/lmx-linux-amd64.tar.gz "https://github.com/LottoLottoLotto/localmaxxing-cli/releases/download/$LMX_VERSION/lmx-linux-amd64.tar.gz"
  curl -fsSL -o /workspace/lmx.sums "https://github.com/LottoLottoLotto/localmaxxing-cli/releases/download/$LMX_VERSION/checksums.txt"
  (cd /workspace && grep lmx-linux-amd64.tar.gz lmx.sums | sha256sum -c -) || { echo LMX_CHECKSUM_FAIL; exit 1; }
  tar -xzf /workspace/lmx-linux-amd64.tar.gz -C /workspace/bin lmx && chmod +x /workspace/bin/lmx
fi
export PATH=/workspace/bin:$PATH
lmx --version
lmx hardware --out /workspace/lmx/hardware.json >/dev/null 2>&1; cat /workspace/lmx/hardware.json
if ! pgrep -f power_sampler.sh >/dev/null; then
  setsid nohup bash /workspace/lmx/power_sampler.sh /workspace/logs/power_sampler.csv >/dev/null 2>&1 < /dev/null &
  echo $! > /workspace/logs/power_sampler.pid
fi

pip install -q --break-system-packages "huggingface_hub[hf_transfer]" 2>&1 | tail -1   # template python is PEP 668 "externally managed"
export PATH=/root/.local/bin:$PATH HF_HUB_ENABLE_HF_TRANSFER=1
command -v hf >/dev/null || { echo HF_CLI_MISSING; exit 1; }
(docker pull -q "$LLAMACPP_IMAGE" >/dev/null 2>&1 && echo DOCKER_PULL_DONE >> /workspace/logs/downloads.log || echo DOCKER_PULL_FAIL >> /workspace/logs/downloads.log) &

for A in "$@"; do   # "org/repo::<include-glob>" -> /workspace/gguf/<basename repo>/
  M=${A%%::*}; INC=""; [ "$A" != "$M" ] && INC="--include ${A##*::}"
  name=$(basename "$M")
  ( hf download "$M" $INC --local-dir "/workspace/gguf/$name" > "/workspace/logs/dl_$name.log" 2>&1 && echo "DL_DONE $M" >> /workspace/logs/downloads.log || echo "DL_FAIL $M" >> /workspace/logs/downloads.log ) &
done
wait
echo BOOTSTRAP_DONE
