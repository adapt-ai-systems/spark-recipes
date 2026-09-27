# GLM 5.3 full — EXL3 TR3 + GPTQ dense decode, TP6

Track key: `glm-full` (controller record: `pipeline/tracks/glm-full.yaml`).

**Status:** production recipe as of 2026-09-27. Six DGX Sparks, TP6, one head and five workers. This supersedes the TP4 resident profile. It is not a public, one-command rebuild: the EXL3 checkpoint and rank-specific GPTQ codes are locally produced and not redistributed here.

## Pins and artifacts

- Base runtime image: `glm53-six:e3-v2` (local image tag); **immutable image digest and upstream vLLM commit not yet recovered**. The tag alone is not a sufficient public pin. Do not build from `latest` and claim equivalence.
- Weights: GLM 5.3 EXL3 TR3 3.25 bpw, sharded six ways; source checkpoint manifest is not published. D8 GPTQ g32 dense codes are rank-specific; absent from this repository. Exact weights cannot be reconstructed from this page alone.
- Overlays: D2d FP8/W8A8 prefill, D3 RoCE one-shot all-reduce, D8 GPTQ g32 dense decode, MTP2. The campaign's D8 source overlays and GPTQ codes require independent provenance/scrub before publication; not shipped in this release. Apply against the exact image, never by filename alone.
- Topology: 6 × GB10, TP6, RoCE fabric. Worker ranks must start before head.
- Context/KV: configured 360,000 per request; measured KV pool 803,968 tokens for the D8 profile. MTP2, CUDA graph captures 3/6/9/12. `VLLM_MARLIN_USE_ATOMIC_ADD=1` in current launcher; it introduces BF16-rounding-level output drift, not bitwise equivalence.

## Launch and verify

`launch.sh` is a fail-closed command template. Set the image, weights and overlay directory from your own verified artifacts; set `HEAD_IP` and ordered `RANK_IPS` (five entries). It prints the per-rank commands when `DRY_RUN=1`. Do not launch alongside another model on these nodes. After worker-first startup, verify every rank, `/health`, served model ID and a smoke completion. The template does not reproduce the private campaign wrapper's quant-code mount; until that artifact is released, use it as a topology/flag reference only.

## Measured evidence

The 2026-09-27 D8 g32 screen reported 8K and 32K prefill proxies of 973 and 935 tok/s, prose decode 32.2 tok/s (three samples: 33.3/32.2/31.3), 49.3% draft acceptance. The KL gate passed: KL 0.0284, top-1 agreement 0.9651. Prefill was about 2.5% below the FP8 previous best; decode about 10% above its 29.3 tok/s comparison. A later atomic-add screen reported 32.89 tok/s, but did not establish a five-repeat capacity/quality result. These are local, workload-specific measurements, not a full task-quality validation.

## Rollback

Stop the six-rank process and restore the previously validated FP8 profile (D2d+D3+MTP2) with its **own** saved launcher and overlays, not the GPTQ mount. Check all ranks and smoke output before admitting traffic. Do not use the candidate D9 drafter or lossy lenient acceptance as fallback: both were rejected. A recurring prefill/RPC hang was investigated but not root-caused; an operator must watch first traffic after boot.
