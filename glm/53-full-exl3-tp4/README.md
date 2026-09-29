# GLM 5.3 full: EXL3 TR3 + GPTQ dense decode, TP4

Track key: `glm-full` (controller record: `pipeline/tracks/glm-full.yaml`).

**Status:** production 4-Spark profile as of 2026-09-29. Four DGX Sparks, TP4 with decode context parallel 2 (DCP2), one head and three workers. This is the [TP6 recipe](../53-full-exl3-tp6/README.md)'s speed stack applied to four boxes. Like TP6, it is not a public one-command rebuild: the EXL3 checkpoint shards, the TP4 prefill runtime and the rank-specific GPTQ codes were produced locally and are not redistributed here.

## Pins and artifacts

- Base runtime image: local vLLM build, image ID `sha256:cab56083ce3d2f4fb8bd148abd15895366abef711301c494dcdfe736cd4665a0` (`VLLM_BUILD_COMMIT=unknown`). The **upstream vLLM commit is not recovered**. The vLLM base files are byte-identical to the TP6 image's (checked 2026-09-29).
- Weights: the starting quant is [davidsyoung/GLM-5.3-EXL3-TR3-3.25bpw](https://huggingface.co/davidsyoung/GLM-5.3-EXL3-TR3-3.25bpw) (EXL3, 3.25 bits per weight, weight-only). The TR3 prepared cache and D8 GPTQ g32 codes are rank-specific and not included.
- Overlays (not shipped): TP4 E3 prefill runtime, DCP2 MLA attention, MTP draft-slot proposer, D2d FP8/W8A8 dense prefill, D3 RoCE one-shot all-reduce/all-gather, D8 GPTQ g32 dense decode, fast weight loading. Apply them only against the exact image, never by filename.
- Topology: 4 × GB10, TP4 + DCP2, both RoCE rails (`NCCL_IB_MERGE_NICS=1`). Start the worker ranks before the head.
- Context/KV: `--max-model-len 360000`, `--kv-cache-memory-bytes 20e9`, which gives a measured KV pool of 730,750 tokens. FP8 MLA KV cache, MTP k=4, FULL CUDA graphs 5/10/15/20, `--max-num-seqs 4`, `--max-num-batched-tokens 4096`.

## Launch and verify

`launch.sh` is a fail-closed command template. Set the image, weights, overlay and GPTQ-code directories from your own verified artifacts, plus `HEAD_IP` and three ordered `RANK_IPS`. With `DRY_RUN=1` it prints the per-rank command. Don't run it alongside another model on the same nodes. After a worker-first start, check every rank, `/health`, the served model ID and a smoke completion.

**Bad-boot check:** about 1 in 4 boots with fast weight loading came up slow (8K prefill ~500 tok/s instead of ~780). Probe an 8K cold prefill after boot and reboot once if it comes in under 580 tok/s.

## Measured evidence (2026-09-29)

Each step was added one at a time on one boot, and only kept if it was faster and passed a fidelity check. Single-stream, clocks uncapped. Prefill is cold input tokens / client TTFT. Decode is prose (one run) and structured/code (median of 5).

| Step | Added | 8K prefill | 32K prefill | Prose | Structured | Code |
|---|---|---:|---:|---:|---:|---:|
| S0 | control (TP4 + DCP2, MTP4) | 648.7 | 642.2 | 14.96 | 32.62 | 25.10 |
| S1 | D2d FP8 dense prefill | 658.0 | 651.8 | 18.76 | 38.43 | 31.97 |
| S2 | both RoCE rails in NCCL | 777.9 | 763.1 | 18.70 | 39.36 | 31.25 |
| S3 | D3 RoCE one-shot AR/AG | 782.0 | 765.7 | 19.49 | 40.00 | 32.04 |
| **S4** | **GPTQ int4 g32 dense decode + Marlin atomic-add** | **783.2** | **769.4** | **19.78** | **42.63** | **35.15** |

Against the control: prefill +21% / +20%, prose +32%, structured +31%, code +40%. Draft acceptance at S4 was 0.284 (2.14 tokens per round).

Tried and rejected: `--max-num-batched-tokens 8192`. The TP4 E3 prefill kernel only accepts capacity 2048 or 4096, so the boot fails.

### Versus the TP6 recipe

| tok/s | TP4 (this page) | TP6 |
|---|---:|---:|
| Prefill 8K / 32K | 783 / 769 | 995 / 958 |
| Prose | 19.8 | ~33 |
| Structured | 42.6 | ~40 |
| Code | 35.2 | ~32 |

TP4 matches or beats TP6 on single-stream structured and code decode, and trails on prefill and prose. The TP6 numbers come from its own earlier campaign, on a different day and stack, so this is not a same-window A/B.

## How far this recipe drifts from the starting quant

KL gate for the GPTQ int4 g32 step, using the same method as TP6 (16 prompts × 256 tokens, top-20 logprobs, against the starting quant with BF16 dense layers):

| | KL vs reference | Picks the same next token |
|---|---:|---:|
| Gate | ≤ 0.03242 | ≥ 96.12% |
| **This recipe** | **0.02676** | **96.24%** |

It passed, but the top-1 margin is thin (0.12 points). The same GPTQ solve scored 96.04% (fail) on an earlier stack without D3, dual rails and atomic-add. The fallback we planned (keep `shared_experts.down_proj` out of int4) wasn't needed. **Not measured:** the starting quant against the original GLM-5.3 weights, and full task quality.

## Not done

DCP1 (expected faster decode, but it halves the KV pool to ~365K) is on hold.

## Rollback

Stop the four-rank process and restore the saved TP4 control profile (S0) with its **own** launcher and overlays. Check all ranks and a smoke output before admitting traffic.
