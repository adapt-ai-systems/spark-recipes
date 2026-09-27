# DeepSeek V4.1 Flash — SGLang TP4

Track key: `ds41-flash` (controller record: `pipeline/tracks/ds41-flash.yaml`).

**Status:** production recipe as of 2026-09-25; interchangeable ring tenant, not necessarily the live resident.

## Pins and artifacts

- Upstream runtime/recipe: [knapcio/DeepSeek-V4.1-Flash-4x-DGX-Spark-TP4](https://github.com/knapcio/DeepSeek-V4.1-Flash-4x-DGX-Spark-TP4) at `7ac7123` (MiaAI-Lab TP4 production lineage). The locally measured container was built from the pinned upstream recipe; its immutable image digest is **not recorded** in the local summary.
- Weights: DeepSeek V4.1 Flash checkpoint shared from head to workers; separate Engram on every rank. Weight repository revision and manifest are **not verified in the summary**; source them from the pinned upstream instructions and verify locally.
- `topology.patch` ships a generic diff against the pinned upstream `start.sh` and `files/nfs-share.sh`: it permits per-rank NIC/HCA overrides and handles an NFS share whose export root is already the model directory. Apply it only if those topology conditions match; configure interface and export values privately. The upstream launcher remains the base implementation.
- Topology: 4 × GB10, SGLang TP4, EP size 1. Configure switched RoCE and validate each interface. Do not substitute stale interface examples from a different topology.
- Context/KV: configured 1,000,000 max context; reported KV pool 7,079,168 tokens. Near-1M reliability was not established by the local bench; a previous stack aborted around 590K on head memory.

## Launch and verify

Use the pinned upstream `start-tp4.sh` with its `deploy.env.tp4` copied to a private location. `launch.sh` validates placeholder inputs and prints the upstream invocation; it does not reimplement or modify that upstream code. Enable metrics, verify all four ranks, `/metrics`, model ID, smoke output, and context depth needed for your workload.

## Measured evidence

2026-09-25 local bench with clocks capped below the upstream author's run: seven prose single-stream samples, median 82.55 tok/s in round 2; code single-stream 119.9 tok/s. Round-2 cold 32K prefill was 5,236.54 and 5,255.04 tok/s (two passes, rounded to 5,237–5,255 in the catalog). A 262K input took about 66 s TTFT in the two round-2 prefill passes. Local qeval: 72/75. A dashboard collector caused measurable interference at higher concurrency, so round-2 numbers (collector stopped) are preferred. Clock and workload differ from upstream figures.

## Rollback

Use upstream `stop` to release the SGLang stack and its share helper; verify ranks are clear, then load the saved prior tenant from its own recipe. A plain container stop is not equivalent to the upstream stop procedure.
