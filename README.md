# Spark serving recipes

Reproducibility notes for model serving on NVIDIA DGX Spark. **Status is a recipe status, not a claim that a model is serving right now.** A production recipe is the validated default to use on the next load; candidates are tested but not promoted; retired recipes remain in the migration register. This repository does not contain weights, local network configuration, private artifacts, or a live-state inventory.

| Family / variant | Status | Topology | Engine |
|---|---|---|---|
| [GLM 5.3 full EXL3 GPTQ](glm/53-full-exl3-tp6/README.md) | production | 6 Spark TP6 | vLLM fork |
| [GLM 5.3 Flash NVFP4 D3](glm/53-flash-nvfp4-tp4/README.md) | production | 4 Spark TP4 | vLLM fork |
| [DeepSeek V4.1 Flash](deepseek/v4.1-flash-sglang-tp4/README.md) | production | 4 Spark TP4 | SGLang |
| [Qwen3.8 Flash Next NVFP4](qwen/3.8-flash-next-nvfp4-tp2/README.md) | production | 2 Spark TP2 | vLLM fork |
| [MiMo V2.6 Flash](mimo/v2.6-flash-tp4/README.md) | candidate | 4 Spark TP4 | SGLang |
| [MiMo V2.6 Pro](mimo/v2.6-pro-tp6/README.md) | retired from tuning | 6 Spark TP6 | SGLang |
| [Single-GPU alternates](other/5090-alternates/README.md) | out of Spark scope | 1 desktop GPU | mixed |

[Migration register](MIGRATION.md) records the older builds and unpromoted variants, including the inventory rows and campaigns after it. Do not silently substitute an unpinned image, checkpoint, or overlay. An unresolved pin is called out in the variant page; those recipes require provenance work before independent reproduction.

## Using the templates

Each production variant has a `launch.env.example` and `launch.sh`. Copy the example to an **untracked private location**, fill `HEAD_IP`, `RANK_IPS`, model and overlay paths, then review the command before execution. Launchers intentionally refuse to run when required local inputs are unset. They are portable command templates, **not a claim that a clean Spark will boot without the private overlay/quantized weights**. No script in this repository stops containers or changes clocks. Follow the variant's rank order and rollback section when operating a fleet.

The public scrub gate runs on tracked files and commit history. Install the local hook with `git config core.hooksPath .githooks`; CI runs the same check. This cannot police data kept outside this repository.

## What we learned from public recipe projects

[MiaAI-Lab's Spark projects](https://github.com/MiaAI-Lab) demonstrate that deployment scripts, model links, topology, and measured results belong together. [NVIDIA's Spark playbooks](https://github.com/NVIDIA/dgx-spark-playbooks) add prerequisites, verification and troubleshooting. We kept those practical elements but separate measured local results from public claims, and record exact rollback, known gaps and status. We did not copy upstream scripts or publish local logs. Upstream licenses govern any independently obtained runtime or weights.

No benchmark in this repository is a cross-hardware performance promise. Numbers are copied from dated local campaign summaries, with sample counts and caveats where recorded. See each page's evidence section.

## Per-model tuning tracks

The separate controller owns `pipeline/tracks/<model>.yaml` and `pipeline/focus.yaml`. Recipe pages here carry matching track keys: `glm-flash`, `glm-full`, `qwen-flash`, `ds41-flash`, and `mimo-flash`. Scheduling shares and backlog are not duplicated in this public recipe repository.
