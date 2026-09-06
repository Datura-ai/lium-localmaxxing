# LocalMaxxing #1s on rented Lium GPUs — reproduce them in one script

One rented **B200** served Qwen3.6-35B-A3B at **14,499 tok/s** (rank 1 of 276 on LocalMaxxing's largest board); a **$0.59/h RTX 5090** streams Nemotron 3.5 Lightning to a single user at **681.5 tok/s** (Verified, #1); the same class of card runs gemma-4-26B-A4B in llama.cpp at **407 tok/s** (Verified, #1). Every number below is a live, third-party-hosted run; every command below is the one that produced it. Rent the same GPU on [lium.io](https://lium.io), run `scripts/reproduce.sh <recipe>`, get your own row.

**Disclosure:** we work at Lium. Every run was measured on a Lium node rented by the hour with the public `lium` CLI; the prices quoted are what `lium ps` showed for that node on 6 Sep 2026. Nothing here was run on hardware we own.

## What LocalMaxxing is, and what "Verified" means

[LocalMaxxing](https://www.localmaxxing.com) is a public leaderboard of local-inference speed tests: one page per Hugging Face model, every approved run (single-stream, speculative and batched alike) sorted by output tokens per second, submitted with the open-source `lmx` CLI ([localmaxxing-cli](https://github.com/LottoLottoLotto/localmaxxing-cli), MIT). Anyone can submit; the site publishes prompt, output sample, engine flags and power for each run.

A run gets the **Verified** badge only if the server can check it: the prompt is one of the two canonical prompts (`reasoning-v1`, sha256 `9000edaa…3445`, in `configs/`), the prompt and output samples are present, the engine's own timings object is attached (`engineTimingsRaw`), **batch 1 and concurrency 1**, ≥ 256 output tokens, speculative runs report draft/accepted token counts, and the result is below the card's theoretical decode ceiling × 1.15. Three Verified runs make a Verified user. Aggregate (concurrency > 1) rows *rank* on the board but are not badge-eligible by design — a 14,499 tok/s row is the sum of 256 streams, not what one user sees.

## Scoreboard (36 live runs, 20 Verified, #1 on 7 boards — `results/scoreboard.json`, 6 Sep 2026 10:38 UTC)

| Board | Our run (GPU ×1 · engine · quant · concurrency) | tok/s out | Rank (all / single-stream) | Verified | Run |
|---|---|---|---|---|---|
| Qwen/Qwen3.6-35B-A3B | **B200 · vLLM · FP8 · c256** | **14,499.4** | **1** / 276 | — | https://www.localmaxxing.com/en/runs/cmtpc0w6f02hwn701n1g0v9cg |
| Qwen/Qwen3.6-35B-A3B | H200 SXM · vLLM · FP8 · c256 | 12,005.2 | 2 / 276 | — | https://www.localmaxxing.com/en/runs/cmtpo9v4802vvn701bdaf2hih |
| Qwen/Qwen3.6-35B-A3B | H100 SXM · vLLM · FP8 · c256 | 9,867.8 | 3 / 276 | — | https://www.localmaxxing.com/en/runs/cmtpd8gg002ken701sprp66px |
| Qwen/Qwen3.6-35B-A3B | B200 · vLLM · FP8 · c128 | 9,790.9 | 4 / 276 | — | https://www.localmaxxing.com/en/runs/cmtpc574p02i5n701h59zlznq |
| Qwen/Qwen3.6-35B-A3B | H100 SXM · vLLM · FP8 · c128 | 7,509.4 | 5 / 276 | — | https://www.localmaxxing.com/en/runs/cmtpd9vtn02kkn7018z3ictdc |
| Qwen/Qwen3.6-35B-A3B | B200 · vLLM · FP8 · c64 | 6,171.9 | 6 / 276 | — | https://www.localmaxxing.com/en/runs/cmtpc6mh802i8n701u5iqqjjl |
| Qwen/Qwen3.6-35B-A3B | H100 SXM · vLLM · FP8 · c64 | 5,496.0 | 9 / 276 | — | https://www.localmaxxing.com/en/runs/cmtpdbb3u02kvn701nxbskbg6 |
| Qwen/Qwen3.6-35B-A3B | H100 SXM · vLLM · FP8 + MTP k=5 · c1 | 426.8 | 15 / 276 · **2** / 162 (top Verified row) | ✅ | https://www.localmaxxing.com/en/runs/cmtpnlmcy02von70163gi6lz4 |
| Qwen/Qwen3.6-35B-A3B | H200 SXM · vLLM · FP8 · c1 | 261.5 | 35 / 276 · 18 / 162 | ✅ | https://www.localmaxxing.com/en/runs/cmtpo8fky02vsn7011s4888ua |
| Qwen/Qwen3.6-35B-A3B | H100 SXM · vLLM · FP8 · c1 | 247.4 | 39 / 276 · 22 / 162 | ✅ | https://www.localmaxxing.com/en/runs/cmtpd70y302k8n701pd5s70a1 |
| Qwen/Qwen3.6-35B-A3B | B200 · vLLM · FP8 · c1 | 220.4 | 53 / 276 · 33 / 162 | ✅ | https://www.localmaxxing.com/en/runs/cmtpbtrij02hfn701rhbng1db |
| Qwen/Qwen3.8-27B | **B200 · vLLM · FP8 · c256** | **4,537.6** | **1** / 101 | — | https://www.localmaxxing.com/en/runs/cmtpc2chw02hzn701gaml5laj |
| Qwen/Qwen3.8-27B | B200 · vLLM · FP8 · c64 | 3,002.3 | 2 / 101 | — | https://www.localmaxxing.com/en/runs/cmtpc821402ibn701k99pfsca |
| Qwen/Qwen3.8-27B | B200 · vLLM · FP8 · c1 | 106.2 | 22 / 101 · 19 / 96 | ✅ | https://www.localmaxxing.com/en/runs/cmtpbv6tt02hin701q3p40kpp |
| google/gemma-4-26B-A4B-it | **B200 · vLLM · BF16 · c128** | **12,011.8** | **1** / 50 | — | https://www.localmaxxing.com/en/runs/cmtpc3rtv02i2n7016ygh4wrk |
| google/gemma-4-26B-A4B-it | B200 · vLLM · BF16 · c1 | 245.3 | 9 / 50 · 8 / 47 | ✅ | https://www.localmaxxing.com/en/runs/cmtpbwlyd02hln701b6cjx3lk |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-BF16 | **H200 SXM · vLLM · BF16 · c128** | **7,172.4** | **1** / 15 | — | https://www.localmaxxing.com/en/runs/cmtpohppj02w1n701g2k87gbb |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-BF16 | H100 SXM · vLLM · BF16 · c128 | 5,422.7 | 2 / 15 | — | https://www.localmaxxing.com/en/runs/cmtpdhzkn02lln701nmxn8ls7 |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-BF16 | H100 SXM · vLLM · BF16 · c64 | 3,662.0 | 3 / 15 | — | https://www.localmaxxing.com/en/runs/cmtpdjewg02lon701idty3eh4 |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-BF16 | **H100 SXM · vLLM · BF16 + DSpark · c1** | **481.4** | 4 / 15 · **1** / 12 | ✅ | https://www.localmaxxing.com/en/runs/cmtpmnqa102uln7017yv52ymp |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-BF16 | H200 SXM · vLLM · BF16 · c1 | 337.6 | 5 / 15 · 2 / 12 | ✅ | https://www.localmaxxing.com/en/runs/cmtpogafp02vyn701vst5xsmw |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-BF16 | H100 SXM · vLLM · BF16 · c1 | 280.9 | 6 / 15 · 3 / 12 | ✅ | https://www.localmaxxing.com/en/runs/cmtpdgjzo02lan701g4k1yrup |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | **RTX PRO 6000 Blackwell · vLLM · NVFP4 · c128** | **6,677.4** | **1** / 10 | — | https://www.localmaxxing.com/en/runs/cmtpe90yu02lsn701t2u5yd2j |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | RTX PRO 6000 Blackwell · vLLM · NVFP4 · c64 | 4,686.7 | 2 / 10 | — | https://www.localmaxxing.com/en/runs/cmtpeag9o02lvn701l72a4zfz |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | **RTX 5090 · vLLM · NVFP4 + DSpark · c1** | **681.5** | 3 / 10 · **1** / 8 | ✅ | https://www.localmaxxing.com/en/runs/cmtpif4s202qkn701l9rzs0ap |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | RTX PRO 6000 Blackwell · vLLM · NVFP4 + DSpark · c1 | 593.3 | 4 / 10 · 2 / 8 | ✅ | https://www.localmaxxing.com/en/runs/cmtpfctla02m9n701e9euvd3p |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | RTX PRO 6000 Blackwell · vLLM · NVFP4 + MTP · c1 | 512.1 | 5 / 10 · 3 / 8 | ✅ | https://www.localmaxxing.com/en/runs/cmtper3ox02m5n701jp29p474 |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | RTX PRO 6000 Blackwell · vLLM · NVFP4 + DFlash · c1 | 477.2 | 6 / 10 · 4 / 8 | ✅ | https://www.localmaxxing.com/en/runs/cmtpffiw502mcn701s1hjq7og |
| nvidia/…Nemotron-3.5-Lightning-30B-A3B-NVFP4 | RTX PRO 6000 Blackwell · vLLM · NVFP4 · c1 | 311.2 | 8 / 10 · 6 / 8 | ✅ | https://www.localmaxxing.com/en/runs/cmtpebve402lyn701ju8kn2xu |
| unsloth/Qwen3.6-35B-A3B-GGUF | **RTX 5090 · llama.cpp · UD-Q4_K_M + DFlash draft · c1** | **390.7** | **1** / 219 · **1** / 189 | ✅ | https://www.localmaxxing.com/en/runs/cmtphpop602p3n701z5cai7k7 |
| unsloth/Qwen3.6-35B-A3B-GGUF | RTX 5090 · llama.cpp · UD-Q4_K_M · c1 | 258.1 | 3 / 219 · 3 / 189 | ✅ | https://www.localmaxxing.com/en/runs/cmtphr3zz02p6n70190w33em2 |
| unsloth/Qwen3.6-35B-A3B-GGUF | B200 · llama.cpp · UD-Q4_K_M · c1 | 199.9 | 5 / 219 · 5 / 189 | ✅ | https://www.localmaxxing.com/en/runs/cmtpby1ag02hpn701l4hkexwh |
| unsloth/Qwen3.8-27B-GGUF | RTX 5090 · llama.cpp · UD-Q4_K_M + DFlash2 draft · c1 | 205.3 | 2 / 426 · 2 / 190 | ✅ | https://www.localmaxxing.com/en/runs/cmtpji5an02rkn70130cx0tvp |
| unsloth/Qwen3.8-27B-GGUF | B200 · llama.cpp · UD-Q4_K_M · c1 | 86.8 | 22 / 426 · 20 / 190 | ✅ | https://www.localmaxxing.com/en/runs/cmtpbzgly02htn701f9arg2ui |
| unsloth/gemma-4-26B-A4B-it-GGUF | **RTX 5090 · llama.cpp · UD-Q4_K_XL + MTP draft · c1** | **407.0** | **1** / 79 · **1** / 69 | ✅ | https://www.localmaxxing.com/en/runs/cmtplgojv02tcn701uyzagsof |
| unsloth/gemma-4-26B-A4B-it-GGUF | RTX 5090 · llama.cpp · UD-Q4_K_XL + DFlash draft · c1 | 383.0 | 2 / 79 · 2 / 69 | — (see below) | https://www.localmaxxing.com/en/runs/cmtpli44102tkn701jazwsc1p |

Rank = position on the model page by tok/s out when we last polled the public API; boards move. Submission log with timestamps: `results/SUBMITTED.md`.

## Reproduce in 15 minutes

Everything runs on the pod; you need the `lium` CLI, a funded account, and (only to submit) your own LocalMaxxing API key. "15 minutes" holds on datacenter nodes (B200/H100/H200 pulled weights at 0.4–1 GB/s); consumer-hosted RTX 5090 nodes downloaded at 10–30 MB/s, so those two recipes took 25–60 min wall time — mostly waiting for weights — while costing under $1.

```bash
uv tool install lium-io && lium init         # paste your Lium API key from lium.io — never commit it
lium ls --gpu B200                           # pick a node; prices are per hour, shown live
lium up --gpu B200 -c 1 -t e03e4d64-fec3-483b-9de9-b6e8a86b404b --name lmx --ttl 3h --no-ssh -y   # PyTorch CUDA Ubuntu 24.04 template
lium ps                                      # wait for RUNNING; the $/h column is the observed price
lium rsync lmx . /workspace/lmx-repo         # this repository (≈ 200 KB) onto the pod
# run one recipe end to end, detached (bootstrap → serve → measure → payload → submit if LMX_API_KEY is set → stop):
lium exec lmx -e HF_TOKEN="$HF_TOKEN" -e LMX_API_KEY="$LMX_API_KEY" \
  "nohup setsid bash /workspace/lmx-repo/scripts/reproduce.sh <recipe> > /workspace/reproduce.log 2>&1 < /dev/null &"
lium exec lmx "tail -n 5 /workspace/reproduce.log"                     # until REPRODUCE_DONE (or REPRODUCE_FAILED)
lium scp lmx /workspace/runs ./runs -d       # run.json, payload.json, power_window.json, meta.json, engine logs
lium rm lmx -y                               # you pay by the minute; the TTL is only a safety net
```

`HF_TOKEN` is optional (none of the models below is gated); `LMX_API_KEY` is **your** key from the LocalMaxxing dashboard — the rows above were submitted under ours, yours will appear under your account. Both are read from the environment (or `/workspace/secrets/*`, mode 600) and never printed. Steps can be run one at a time: `reproduce.sh <recipe> bootstrap|serve|run|submit|stop`.

### (a) `qwen36-35b-a3b-fp8-b200-c256` — Qwen3.6-35B-A3B FP8, one B200, 256 streams: 14,499 tok/s (#1 of 276)

```bash
lium up --gpu B200 -c 1 -t e03e4d64-fec3-483b-9de9-b6e8a86b404b --name lmx --ttl 3h --no-ssh -y      # observed $5.60/h
# bootstrap.sh: lmx v0.1.39 (checksum-verified) · uv venv · vLLM 0.28.0 (torch 2.13.0+cu130) · pip nvcc 13.0 for the DeepGEMM/FlashInfer JIT · hf download Qwen/Qwen3.6-35B-A3B-FP8 (37.5 GB; this node pulled ~1 GB/s)
vllm serve /workspace/models/Qwen3.6-35B-A3B-FP8 --served-model-name Qwen/Qwen3.6-35B-A3B-FP8 --host 127.0.0.1 --port 8000 --max-model-len 32768 --max-num-seqs 256 --gpu-memory-utilization 0.90 --enable-prefix-caching --limit-mm-per-prompt '{"image":0,"video":0}'
lmx speed-test run vllm --mode remote --base-url http://127.0.0.1:8000 --hf-id Qwen/Qwen3.6-35B-A3B-FP8 --served-model Qwen/Qwen3.6-35B-A3B-FP8 --quantization FP8 --backend cuda --hardware /workspace/lmx/hardware.json --prompt-file /workspace/lmx/prompt_reasoning-v1.txt --max-tokens 512 --temperature 0 --warmup 2 --iterations 3 --concurrency 256 --json --json-status --out /workspace/runs/q36a3b-fp8__b200x1__vllm__c256/run.json
python3 scripts/submit_prep.py /workspace/runs/q36a3b-fp8__b200x1__vllm__c256/     # run.json + power_window.json + meta.json → payload.json
python3 scripts/submit.py --dry-run /workspace/runs/q36a3b-fp8__b200x1__vllm__c256/ && python3 scripts/submit.py --submit /workspace/runs/q36a3b-fp8__b200x1__vllm__c256/   # POST /api/speed-tests with $LMX_API_KEY
```

Same server, `--iterations 5 --max-tokens 1024` and no `--concurrency` flag gives the Verified single-stream row (220.4 tok/s); `--concurrency 64` / `128` give the 6,172 / 9,791 rows. Measured: 764.8 W mean in the timed window, 162.6 GB peak VRAM, TTFT 857 ms at c256. Whole 11-run session on this card: 40.5 min, **$3.78**.

### (b) `nemotron35-lightning-nvfp4-dspark-rtx5090-c1` — Nemotron 3.5 Lightning NVFP4 + DSpark draft, one RTX 5090, single stream: 681.5 tok/s (Verified, #1)

```bash
lium up --gpu RTX5090 -c 1 -t e03e4d64-fec3-483b-9de9-b6e8a86b404b --name lmx --ttl 3h --no-ssh -y   # observed $0.59/h
# bootstrap.sh as above + hf download nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 (21.6 GB) and …-NVFP4-DSpark (the drafter); export MAX_JOBS=3 first (31 GB-RAM node)
vllm serve /workspace/models/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 --served-model-name nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 --host 127.0.0.1 --port 8000 --max-model-len 16384 --max-num-seqs 8 --gpu-memory-utilization 0.92 --enable-prefix-caching --async-scheduling --mamba-backend flashinfer --mamba-ssm-cache-dtype float16 --speculative-config '{"model":"/workspace/models/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-DSpark","num_speculative_tokens":3}'
lmx speed-test run vllm --mode remote --base-url http://127.0.0.1:8000 --hf-id nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 --served-model nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 --quantization NVFP4 --backend cuda --hardware /workspace/lmx/hardware.json --prompt-file /workspace/lmx/prompt_reasoning-v1.txt --max-tokens 1024 --temperature 0 --warmup 2 --iterations 5 --json --json-status --out /workspace/runs/nemotron35-nvfp4-dspark__rtx5090x1__vllm__c1/run.json
python3 scripts/submit_prep.py /workspace/runs/nemotron35-nvfp4-dspark__rtx5090x1__vllm__c1/ && python3 scripts/submit.py --dry-run /workspace/runs/nemotron35-nvfp4-dspark__rtx5090x1__vllm__c1/ && python3 scripts/submit.py --submit /workspace/runs/nemotron35-nvfp4-dspark__rtx5090x1__vllm__c1/
```

DSpark is lossless speculative decoding (output identical to plain decoding); the badge needs the draft/accepted counts, which `capture_meta.py` reads from vLLM's `/metrics` around the companion request (927 drafted, 714 accepted, 3.31 mean accepted length). Measured: 351.7 W, 30.1 GB peak VRAM, TTFT 76 ms. Without the drafter the same checkpoint does 311.2 tok/s (measured on an RTX PRO 6000, same stack; the 5090 no-draft row was not run). Server start took ~10 min on this node (FlashInfer sm_120 JIT + CUDA graphs).

### (c) `gemma4-26b-a4b-gguf-mtp-rtx5090-c1` — gemma-4-26B-A4B UD-Q4_K_XL + MTP draft in llama.cpp, one RTX 5090: 407 tok/s (Verified, #1 of 79)

```bash
lium up --gpu RTX5090 -c 1 -t e03e4d64-fec3-483b-9de9-b6e8a86b404b --name lmx --ttl 3h --no-ssh -y   # observed $0.60/h; needs an executor with docker-in-docker (`lium ls` shows it)
# bootstrap_gguf.sh: lmx v0.1.39 · docker pull ghcr.io/ggml-org/llama.cpp:server-cuda (build 10818 on 6 Sep 2026) · hf download unsloth/gemma-4-26B-A4B-it-GGUF --include "*UD-Q4_K_XL*.gguf" and "mtp-*.gguf" → /workspace/gguf (see "not reconstructed exactly")
docker run -d --name llamacpp --gpus all -v /workspace/gguf:/models -p 127.0.0.1:8000:8000 ghcr.io/ggml-org/llama.cpp:server-cuda -m /models/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf --alias gemma-4-26B-A4B-it-UD-Q4_K_XL -c 32768 -ngl 99 -fa on -np 1 --no-mmap --jinja --reasoning-format none --host 0.0.0.0 --port 8000 --spec-type draft-mtp -md /models/gemma-4-26B-A4B-it-GGUF/mtp-gemma-4-26B-A4B-it.gguf -ngld 99 --spec-draft-n-max 5
lmx speed-test run llama.cpp --mode remote --base-url http://127.0.0.1:8000 --hf-id unsloth/gemma-4-26B-A4B-it-GGUF --served-model gemma-4-26B-A4B-it-UD-Q4_K_XL --quantization Unsloth-Dynamic-Q4_K_XL --backend cuda --hardware /workspace/lmx/hardware.json --prompt-file /workspace/lmx/prompt_reasoning-v1.txt --max-tokens 1024 --temperature 0 --warmup 2 --iterations 5 --json --json-status --out /workspace/runs/gemma4-26b-a4b-udq4kxl-mtp-n5__rtx5090x1__llamacpp__c1/run.json
python3 scripts/submit_prep.py /workspace/runs/gemma4-26b-a4b-udq4kxl-mtp-n5__rtx5090x1__llamacpp__c1/ && python3 scripts/submit.py --dry-run /workspace/runs/gemma4-26b-a4b-udq4kxl-mtp-n5__rtx5090x1__llamacpp__c1/ && python3 scripts/submit.py --submit /workspace/runs/gemma4-26b-a4b-udq4kxl-mtp-n5__rtx5090x1__llamacpp__c1/
```

The MTP head is unsloth's small `mtp-gemma-4-26B-A4B-it.gguf` from the same repo (lossless). llama.cpp reports `draft_n` / `draft_n_accepted` in its `timings` (1,264 / 769 on the companion request). Measured: 383.6 W, 18.1 GB peak VRAM, TTFT 258 ms. Plain, no draft: 214.0 tok/s on the same card; the n-max sweep gave 323.8 / 373.7 / 390.6 / 398.1 / **407.0** / 380.3 for n = 1 / 2 / 3 / 4 / 5 / 6. Session: 27 min, **$0.27**.

### The other boards, one line each (same `bootstrap.sh` → serve → `run_speed.sh` flow; serve lines verbatim from the run payloads)

- **Qwen3.8-27B agg #1** — `lium up --gpu B200` ($5.60/h): `vllm serve /workspace/models/Qwen3.8-27B-FP8 --served-model-name Qwen/Qwen3.8-27B-FP8 --host 127.0.0.1 --port 8000 --max-model-len 32768 --max-num-seqs 256 --gpu-memory-utilization 0.90 --enable-prefix-caching --limit-mm-per-prompt '{"image":0,"video":0}'` → c256 4,537.6 (the card hits its 1,000 W cap: 942 W mean), c64 3,002, c1 106.2 Verified.
- **gemma-4-26B-A4B-it agg #1** — B200: `vllm serve /workspace/models/gemma-4-26B-A4B-it --served-model-name google/gemma-4-26B-A4B-it --host 127.0.0.1 --port 8000 --max-model-len 32768 --max-num-seqs 256 --gpu-memory-utilization 0.90 --enable-prefix-caching --limit-mm-per-prompt '{"image":0,"video":0,"audio":0}'` → c128 12,011.8, c1 245.3 Verified.
- **Nemotron BF16 single-stream #1** — `lium up --gpu H100` ($1.20/h, SXM): `vllm serve /workspace/models/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-BF16 --served-model-name nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-BF16 --host 127.0.0.1 --port 8000 --max-model-len 32768 --max-num-seqs 32 --gpu-memory-utilization 0.92 --enable-prefix-caching --async-scheduling --speculative-config '{"model":"/workspace/models/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-DSpark","num_speculative_tokens":3}'` → 481.4 Verified (the bf16 DSpark drafter also serves the BF16 target).
- **Nemotron BF16 agg #1** — `lium up --gpu H200` ($3.00/h): same serve line with `--max-num-seqs 128` and without `--speculative-config` / `--async-scheduling` → c128 7,172.4; on H100 5,422.7.
- **Nemotron NVFP4 agg #1** — `lium up --gpu pro6000` ($1.19/h): `vllm serve /workspace/models/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 --served-model-name nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4 --host 127.0.0.1 --port 8000 --max-model-len 32768 --max-num-seqs 128 --gpu-memory-utilization 0.90 --enable-prefix-caching --async-scheduling --mamba-backend flashinfer --mamba-ssm-cache-dtype float16` → c128 6,677.4, c64 4,686.7, c1 311.2 Verified; add the DSpark / `{"method":"mtp","num_speculative_tokens":3}` / DFlash `--speculative-config` for 593.3 / 512.1 / 477.2.
- **Qwen3.6-35B-A3B-GGUF #1** — RTX 5090 ($0.59/h), `bootstrap_gguf.sh`: `docker run --gpus all -v /workspace/gguf:/models -p 127.0.0.1:8000:8000 ghcr.io/ggml-org/llama.cpp:server-cuda -m /models/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf --alias Qwen3.6-35B-A3B-UD-Q4_K_M -c 32768 -ngl 99 -fa on -np 1 --no-mmap --jinja --reasoning-format none --host 0.0.0.0 --port 8000 --spec-type draft-dflash -md /models/dflash/anbeeld-dflash-Q8_0.gguf -ngld 99 --spec-draft-n-max 6` (drafter = `Anbeeld/Qwen3.6-35B-A3B-DFlash-GGUF` Q8_0) → 390.7 Verified; plain 258.1.
- **Qwen3.6-35B-A3B top Verified single stream** — H100: the (a) serve line with `--max-num-seqs 32 --speculative-config '{"method":"mtp","num_speculative_tokens":5}'` → 426.8 (k = 2/3/4/6/8 gave 314 / 361 / 401 / 418 / 377). #1 on that sub-board is an unverified 494.6 n-gram run.
- **Qwen3.8-27B-GGUF #2** — RTX 5090: the GGUF line above with `-m /models/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q4_K_M.gguf --alias Qwen3.8-27B-UD-Q4_K_M … --spec-type draft-dflash -md /models/dflash2/Qwen3.8-27B-DFlash2-Q8_0.gguf -ngld 99 --spec-draft-n-max 7` (`z-lab/Qwen3.8-27B-DFlash2-GGUF`) → 205.3 Verified; the 217.9 #1 is a 110-token counting-task run we chose not to imitate.

## What it costs

$/M output tokens = ($/h) ÷ (tok/s × 3,600 / 10⁶), using the observed price and the measured median tok/s (`results/*/payload.json`):

| Qwen3.6-35B-A3B FP8 on one B200 at $5.60/h | c1 | c64 | c128 | c256 |
|---|---|---|---|---|
| tok/s (sum of streams) | 220.4 | 6,171.9 | 9,790.9 | 14,499.4 |
| $/M output tokens | **$7.06** | **$0.25** | **$0.16** | **$0.107** |

OpenRouter listed the same open model at **$0.70 per million output tokens** ($0.05 input) on 6 Sep 2026 (openrouter.ai model page; some providers showed $0.90–1.00 that week — we quote the lowest). At 256 streams the rented card is 6.5× cheaper; input tokens ride inside the same rented hour. **Break-even is ~23 concurrent streams** (2,222 tok/s = $5.60/h ÷ $0.70/M; per-stream rate at c64 is 96.4 tok/s). **A single user is 10× more expensive than the API** ($7.06 vs $0.70). Rent for batch, evaluation and bulk jobs; do not rent a B200 for one chat window. Same arithmetic on the other rows: the biggest number is not the cheapest token — Qwen3.6 at c256 costs $0.034/M on the H100 ($1.20/h, 9,868 tok/s) and $0.069/M on the H200 ($3.00/h, 12,005 tok/s) versus $0.107/M on the B200; single-stream on the RTX 5090 costs $0.24/M for Nemotron + DSpark and $0.41/M for gemma + MTP.

## How we measured

- `lmx speed-test run … --mode remote` against the pod's own server: **2 untimed warm-ups, then N timed iterations (5 single-stream, 3 aggregate); the reported tok/s is the median (p50)**; per-iteration samples are in `run.json → samples/sampleStats` (c256 σ = 108 tok/s; plain vLLM c1 rows σ ≤ 0.2 tok/s; speculative rows move more — σ 7.2 for (b), 12.0 for (c) — because acceptance varies with the text).
- Prompt: the canonical `reasoning-v1` prompt (`configs/prompt_reasoning-v1.txt`, ~305 tokens as tokenised by these models) with the CLI's unique per-request nonce so prefix caches cannot help; **greedy** (`--temperature 0`); `max_tokens` 1024 single-stream, 512 per stream for aggregates. Decode throughput is measured client-side from first to last streamed token; aggregate = sum of the per-stream rates of N concurrent requests.
- Power: `power_sampler.sh` logs `nvidia-smi` at 1 Hz; `power_window.py` cuts the timed window and reports the mean over samples with GPU utilisation ≥ 50 % (that is `gpuPowerWatts`) plus peak `memory.used` (`peakVramGb`). No TDP guesses.
- `capture_meta.py` sends one non-streamed companion request on the same server right after the run and stores the engine's own `usage` / `timings` object (`engineTimingsRaw`), the exact serve command (`commandSnippet`), and for speculative runs the draft/accepted counters (vLLM `/metrics` delta; llama.cpp `timings.draft_n`). `submit_prep.py` assembles the POST body and adds `promptSha256` / `promptSample` (nonce stripped) / `outputSha256` / `outputSample`. Everything the server checks for the badge is measured on the pod; nothing is typed in.
- The site's decode-ceiling check models a MoE as dense: our gemma + DFlash n-max 4 row (383 tok/s) is approved but not Verified because it exceeds that ceiling (329 tok/s), while the MTP row (407) passed on its own accepted-length accounting. Reported as-is.
- `notes` on every row say the run was rented on Lium; there is no provider field in the schema.

## What did not work (so you do not pay to learn it)

- **B200 single-stream loses to an RTX 5090** for every ≤ 35B model here: 220 tok/s (Qwen3.6-A3B), 106 (Qwen3.8-27B), 245 (gemma) at batch 1 — below the 5090 records (261 / 116 / 296). Batch-1 decode of the Qwen3.x Gated-DeltaNet/MoE stack is launch-bound, not bandwidth-bound (Q8_0 vs Q4_K_M on 27B: 86 vs 92 tok/s); the 5090's 2.9 GHz SM clock beats the B200's 1.97 GHz. Rent B200/H200 for aggregate rows, a 5090 for GGUF single-stream boards.
- **The H100 beat the B200 at batch 1** on Qwen3.6-FP8 (247 vs 220): vLLM 0.28's FP8 block-quant MoE takes the DeepGEMM path on Hopper. **On sm_120 (RTX PRO 6000) FP8 has no DeepGEMM path** — 181.6 tok/s c1, below the board's existing PRO 6000 rows (253.7), so we did not submit those.
- **z-lab DFlash in vLLM 0.28 on Hopper is drafter-bound**: mean accepted length 4.7 but only ~63 target passes/s → k=15 296 tok/s, k=7 256, both below the native MTP head (426.8 at k=5). Not submitted. The jcuypers DFlash GGUF is a non-mainline `dflash-draft` architecture; Anbeeld's GGUF works with llama.cpp b10818.
- **Consumer-hosted RTX 5090 nodes**: advertised ≤ 276 Mbps, measured 10–30 MB/s and intermittent (one node burst 117 MB/s then throttled). Four 5090 pods were dropped within minutes (≈ $0.31 total); the one we kept spent most of 122 min downloading. A 31 GB-RAM node OOM-killed the FlashInfer sm_120 JIT until `MAX_JOBS=3`. Docker-in-docker cannot bind-mount the encrypted `/root` volume → GGUFs live on `/workspace`.
- **`lium ls` does not distinguish H100 SXM from PCIe**: a $1.00/h "H100" was a PCIe card; dropped after 3 min ($0.05). Check `nvidia-smi -L` right after `lium up`.
- vLLM 0.28 on the template needs `nvcc` for DeepGEMM/FlashInfer JIT and the template has no `/usr/local/cuda` → `bootstrap.sh` pins the pip CUDA 13.0 toolchain and symlinks it (see `env.sh`). DeepGEMM warm-up compiles ~1,250 kernels (~5 min) on every fresh start.
- `lmx speed-test run` v0.1.39 has no `engineVersion`/`notes` flags → injected post-hoc with `lmx speed-test runs edit`; spec runs without draft/accepted counts do not get the badge → we deleted one such submission and re-ran with `/metrics` capture.
- Not taken: Qwen3.6-35B-A3B single-stream #1 (494.6, unverified n-gram run on a 7900 XTX), Qwen3.8-27B-GGUF #1 (217.9, a 110-token counting-task run; we are 3 % short with a 1,024-token reasoning prompt), eval boards (out of budget).

## Not reconstructed exactly

- The `hf download --include` globs for the gemma recipe (`*UD-Q4_K_XL*.gguf`, `mtp-*.gguf`) are inferred from the files that were served; the original bootstrap invocation was not preserved in a log. All other download targets are whole repos.
- `hardware.json` for the vLLM pods was produced with `lmx hardware` and, where detection was incomplete, hand-completed; the exact objects submitted are in `results/*/payload.json → hardware`. `reproduce.sh` runs `lmx hardware --out` + `validate` and tells you how to write the file if it does not validate.
- The B200 session was driven interactively, not by a saved batch script; its parameters (serve line, 3 iterations, `max_tokens` 512, concurrency 256) are recovered from `payload.json` / `run.json` and are what `recipes/qwen36-35b-a3b-fp8-b200-c256.env` encodes.
- The llama.cpp image tag `server-cuda` is floating; it resolved to build 10818 (commit 4d9176092) on 6 Sep 2026 — pin `LLAMACPP_IMAGE` to the matching `server-cuda-b10818` tag if you need that exact build (untested by us).
- Submission went through `submit.py` (raw `POST /api/speed-tests` with `payload.json`), not `lmx speed-test runs submit`; the CLI's `lmx speed-test submit payload.json` should be equivalent but we did not use it.

## Models and licences (weights are downloaded at run time, never bundled)

| Model (Hugging Face id, revision `main`) | Licence | Used in |
|---|---|---|
| `Qwen/Qwen3.6-35B-A3B-FP8`, `Qwen/Qwen3.8-27B-FP8`, `unsloth/Qwen3.6-35B-A3B-GGUF`, `unsloth/Qwen3.8-27B-GGUF` | Apache-2.0 | (a), Qwen boards |
| `nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4`, `…-BF16`, `…-NVFP4-DSpark`, `…-NVFP4-DFlash` | OpenMDW-1.1 — Open Model, Data and Weights License (openmdw.ai/license/1-1); HF card tag `other` | (b), Nemotron boards |
| `google/gemma-4-26B-A4B-it`, `unsloth/gemma-4-26B-A4B-it-GGUF` (+ its MTP head) | Apache-2.0 per the model cards, with Google's Gemma 4 licence page linked from them | (c), gemma boards |
| `Anbeeld/Qwen3.6-35B-A3B-DFlash-GGUF`, `Anbeeld/gemma-4-26B-A4B-it-DFlash-GGUF` (from `z-lab/*-DFlash`), `z-lab/Qwen3.8-27B-DFlash2-GGUF` | Apache-2.0 | DFlash draft rows |

Licences were read from each model card via the Hugging Face API on 6 Sep 2026; none of these repos is gated. Software: vLLM 0.28.0 (Apache-2.0), llama.cpp build 10818 via `ghcr.io/ggml-org/llama.cpp:server-cuda` (MIT), `lmx` v0.1.39 (MIT), `uv`, `huggingface_hub`. Scripts and recipes in this repository: MIT (`LICENSE`).

## Layout

`scripts/` — `reproduce.sh` (wrapper), `bootstrap.sh` / `bootstrap_gguf.sh` (engine + CLI + weights), `env.sh` (CUDA 13 toolchain paths), `srv.sh` (vLLM start/stop), `run_speed.sh` (one measurement), `power_sampler.sh` + `power_window.py` (power/VRAM), `capture_meta.py` (engine timings + spec counters), `submit_prep.py` (payload), `submit.py` (dry-run + POST). `recipes/*.env` — one file per headline run, parameters at the top, serve line verbatim. `configs/prompt_reasoning-v1.txt` — the canonical prompt. `results/` — `SUBMITTED.md`, `scoreboard.json`, and the three sanitised `payload.json` bodies exactly as posted. Made on lium.io GPUs.
