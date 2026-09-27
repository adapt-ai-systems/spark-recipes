# MiMo V2.6 Flash — MXFP4 SGLang TP4

Track key: `mimo-flash` (controller record: `pipeline/tracks/mimo-flash.yaml`).

**Status:** candidate, not a current default. Source: [XiaomiMiMo/MiMo-V2.6-Flash-RL](https://huggingface.co/XiaomiMiMo/MiMo-V2.6-Flash-RL) revision `3b38d063180c3e4aed9691fdc735f3d10b266ee4`; local verified manifest: 90 files, 177,767,644,130 bytes. Image `sha256:381b27ffa19bfbade2bf69bb103395e59a7e82ab0adf176b15b492e9df5aaf7b` (`lmsysorg/sglang:dev-dsv41`), SGLang commit `da64c5cbb` reported in the campaign. Runtime needs a narrowly scoped store-dtype/model-config backport for native MXFP4 and text-only multimodal overrides; patch not yet published.

Four Sparks TP4, 131,072 configured context, full BF16 KV pool 262,144 tokens plus SWA pool 52,428. No speculation. Five cold requests around 9.37K input/256 output yielded 2.689 s median TTFT, a 3,487 tok/s cold prefill proxy, and 37.72 tok/s prose decode; five same-prefix follow-ups had 0.134 s TTFT. Code decode was not measured. Only ~9.4K depth was actually tested. Arithmetic, JSON and tool-call smoke passed; this is not a broad quality gate. Rollback: stop candidate on all four, then restore the saved preceding tenant worker-first. No public launcher is offered until the runtime backport is distributable.
