#!/bin/bash
# Pod bootstrap for the vLLM recipes: lmx CLI (checksum-verified release), uv venv + vLLM 0.28.0,
# the CUDA 13 JIT toolchain vLLM needs on this template, and parallel model downloads.
# Tested on the Lium "PyTorch CUDA Ubuntu 24.04" template (no /usr/local/cuda, pip is PEP 668-managed).
# usage (detached): nohup setsid bash /workspace/lmx/bootstrap.sh "org/repo" ["org/repo::<include-glob>" ...] > /workspace/logs/bootstrap.log 2>&1 &
# HF_TOKEN (optional, only for gated repos / higher rate limits) is read from the environment by `hf download`.
set -euo pipefail
LMX_VERSION=${LMX_VERSION:-v0.1.39}      # the release every run in results/ was measured with
VLLM_VERSION=${VLLM_VERSION:-0.28.0}     # unpinned `vllm` resolved to 0.28.0 (torch 2.13.0+cu130) on 6 Sep 2026; pinned here
mkdir -p /workspace/{lmx,models,runs,logs,bin}
cd /workspace

# lmx CLI (release tarball, checksum-verified)
if [ ! -x /workspace/bin/lmx ]; then
  curl -fsSL -o /workspace/lmx-linux-amd64.tar.gz "https://github.com/LottoLottoLotto/localmaxxing-cli/releases/download/$LMX_VERSION/lmx-linux-amd64.tar.gz"
  curl -fsSL -o /workspace/lmx.sums "https://github.com/LottoLottoLotto/localmaxxing-cli/releases/download/$LMX_VERSION/checksums.txt"
  (cd /workspace && grep lmx-linux-amd64.tar.gz lmx.sums | sha256sum -c -)
  tar -xzf /workspace/lmx-linux-amd64.tar.gz -C /workspace/bin lmx && chmod +x /workspace/bin/lmx
fi
/workspace/bin/lmx --version

# uv + venv + vLLM
if [ ! -x /root/.local/bin/uv ]; then curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null; fi
export PATH=/root/.local/bin:/workspace/bin:$PATH
[ -d /workspace/venv ] || uv venv /workspace/venv --python 3.12 >/dev/null
uv pip install --python /workspace/venv/bin/python -q "vllm==$VLLM_VERSION" "huggingface_hub[hf_transfer]" 2>&1 | tail -3
/workspace/venv/bin/python -c "import vllm, torch; print('vllm', vllm.__version__, 'torch', torch.__version__)"
# JIT toolchain (DeepGEMM / FlashInfer need nvcc; the template has no /usr/local/cuda): pin pip nvcc to the runtime's CUDA 13.0, add dev symlinks
uv pip install --python /workspace/venv/bin/python -q "nvidia-cuda-nvcc==13.0.*" "nvidia-cuda-cccl==13.0.*" "nvidia-cuda-crt==13.0.*" "nvidia-nvvm==13.0.*"
C=/workspace/venv/lib/python3.12/site-packages/nvidia/cu13
(cd $C/lib && for f in lib*.so.[0-9]*; do b=${f%%.so.*}.so; [ -e "$b" ] || ln -sf "$f" "$b"; done; ln -sf /usr/lib/x86_64-linux-gnu/libcuda.so libcuda.so 2>/dev/null || true)
[ -e $C/lib64 ] || ln -s lib $C/lib64
$C/bin/nvcc --version | tail -1

# model downloads (parallel), pod-local under /workspace/models/<repo-basename>
export HF_HUB_ENABLE_HF_TRANSFER=1
for A in "$@"; do   # "org/repo" or "org/repo::<include-glob>" (GGUF repos: fetch one quant only)
  M=${A%%::*}; INC=""; [ "$A" != "$M" ] && INC="--include ${A##*::}"
  name=$(basename "$M")
  ( /workspace/venv/bin/hf download "$M" $INC --local-dir "/workspace/models/$name" > "/workspace/logs/dl_$name.log" 2>&1 && echo "DL_DONE $M" >> /workspace/logs/downloads.log || echo "DL_FAIL $M" >> /workspace/logs/downloads.log ) &
done
wait
echo BOOTSTRAP_DONE
