# GLM 5.3 Flash — Blackfrost NVFP4 attention, D3, TP4

Track key: `glm-flash` (controller record: `pipeline/tracks/glm-flash.yaml`).

**Status:** production recipe as of 2026-09-27. Four DGX Sparks, TP4. Current recipe combines the previously validated g9r profile, runai weight loading, and D3 RoCE one-shot all-reduce.

## Pins and artifacts

- Image: local vLLM image `sha256:35c6f70ffcba62fd67d7b9d4b4e8300ad177201792ce9cdb1ea18fd449bc23b6`. The upstream source commit is reported as `unknown` in its Docker metadata; image digest is the reproducible pin.
- Weights: Blackfrost derisked-attention GLM 5.3 Flash NVFP4 conversion, plus separate DFlash2 draft. The conversion source, revision and complete weight manifest are **not yet publicly pinned**; bring independently verified copies. No weights are included here.
- Overlays: model/attention and sparse-indexer fixes plus D3 vLLM communicator, env and worker patches. `overlays/` holds the small D3 patch hunks that can be applied to the pinned image; remaining full-file mounts require source provenance and are not shipped. Do not mix these with stock vLLM.
- Topology: 4 × GB10, TP4, workers first. Dual-HCA RoCE, D3 all-reduce ≤256 KiB and all-gather ≤2 MiB.
- Context/KV: max request 500,000 tokens; FP8 E4M3 KV 24 GiB/rank, observed pool 3,642,578 tokens in the g9r profile. Max 64 sequences, max batched tokens 16,384, DFlash2 k=3. That pool is not a 3.6M single-request validation.

## Launch and verify

See `launch.sh` and `launch.env.example`. Required `HEAD_IP`, three ordered `RANK_IPS`, image, weight and overlay paths are private inputs. Launcher prints commands with `DRY_RUN=1`; it does not stop competing containers. Verify each rank, `/health`, served ID, JSON/tool-call smoke and a long-context retrieval case before promotion. The public template cannot boot without the missing private full-file overlays and weights.

## Measured evidence

2026-09-27 same-session fastbench, temperature 0, 512 output tokens: before D3 g9r 8K 2.99 s, 32K 11.13 s, prose 49.5 tok/s, code 64.1; D3 confirmation after reboot 8K 3.03 s (2,140 tok/s), 32K 11.49 s (2,112 tok/s), prose 54.8, code 70.9. The 3,642,578-token KV pool was observed on g9r, not remeasured after D3. Normalized decoding rounds/s improved 8.1% prose and 8.3% code. Tool call, strict JSON and three needles near 85K passed. 64K prefill was 21.77 s vs 21.16 s before, so prefill is not improved. Warm boot with runai was 187–200 s, versus a recorded 13m22s cold baseline on an older container; that comparison includes different profiles.

## Rollback

Stop D3 on all four ranks. Restore the stopped g9r container/launcher without the D3 mounts; start workers before head and smoke the endpoint. Starting much older NVFP4 containers has previously stalled at communicator initialization, so they are not the preferred rollback.
