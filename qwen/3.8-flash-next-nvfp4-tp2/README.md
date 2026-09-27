# Qwen3.8 Flash Next — NVFP4, TF+D3+B1, TP2

Track key: `qwen-flash` (controller record: `pipeline/tracks/qwen-flash.yaml`).

**Status:** production recipe as of 2026-09-27. Two DGX Sparks, TP2+expert parallel. Supersedes the q10r and boot-v3 profiles.

## Pins and artifacts

- Base weights: `RadixArk/Qwen3.8-Flash-Next-NVFP4`; checkpoint revision and file manifest are **not yet recovered** from the local summary. Download and verify the exact source before claiming equivalence.
- Runtime: local `vllm/vllm-openai:qwen38-flash-next`, whose image digest and upstream source commit are **not yet recorded**. This is a provenance gap, not an implied moving-tag pin.
- Overlays: corrected Mamba-prefix cache scheduler, selective FP8, draft vocabulary 79,591 IDs, W8A16 split-K dense kernel, D3 RoCE communicator, and B1 balanced draft head. The required full overlay set is not published in this first release; do not claim stock vLLM equals this recipe. B1 balances draft rows by one load-time all-gather; the target verifier remains unchanged. W8A16 weights are lossy, quality-gated locally.
- Topology: 2 × GB10, TP2+EP, worker then head, dual-HCA RoCE. MTP k=4, 8 max sequences, 8192 batched tokens.
- Context/KV: configured 262,144 context; BF16 KV and measured pool 1,182,436 tokens after TF profile. This does not establish 262K retrieval quality.

## Launch and verify

`launch.sh` takes `HEAD_IP`, `RANK_IPS` (one worker), image, weights, and overlay directory; dry-run first. It is a flag/topology template until the image and overlays are published. Verify `/health`, served ID, tool/JSON checks and the actual Mamba cache-hit counter. A prefix hit aligned to the wrong 16-token block is not enough; the corrected scheduler uses the model's Mamba block granularity.

## Measured evidence

2026-09-27 local fastbench: boot-v3 baseline ~6.9K/~26.2K-token prefill proxies 3107/3144 tok/s, prose/code 46.4/83.7 tok/s. Final TF+D3+B1: 3106/3131 tok/s prefill on ~6.9K/~26.2K inputs (6,923/26,200 prompt tokens in the summary), 60.8/99.1 tok/s decode. The fastbench's 8K/32K size settings specify approximate input text length, not measured token counts. Step probe repeated 74.1/75.6/73.4 tok/s; quality checks passed, but teacher-forced NLL 2.261 versus reference 2.235–2.256 indicates small lossy drift. Four/sixteen/thirty-two-way concurrency smoke: 192/261/286 aggregate tok/s. These are mixed protocol-specific measures, not a generalized speed ranking.

## Rollback

Stop both ranks. Restore the saved boot-v3 profile if TF overlays fail; if that is unavailable, restore the earlier q10r measured profile. Worker must start before head. Do not fall back to the rejected custom EXL3 quantization packs or DFlash2 candidate.
