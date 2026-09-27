# Migration register

This register reconciles the older 27-row inventory with later dated campaigns. **Production** means current chosen recipe, not live state. A stopped container can still be the production recipe. Items without enough source/launcher evidence are explicitly not promoted.

| Earlier row or later campaign | Variant | Status here | Reason / evidence |
|---|---|---|---|
| 1, 2; six-Spark row 12; TP6 speed campaign | GLM full EXL3 TP4 MTP4; older MTP3; TP6 E3-v2 | TP4 retired; TP6 production | TP6 `best.sh` D8 g32 winner, 2026-09-27 ledger; previous FP8 best retained for rollback |
| 3 | GLM full Int4/Int8Mix TP4 | retired | older 200K vLLM stack, superseded by EXL3 |
| 4, 5; local tune, Flash night, boot speed | GLM Flash NVFP4 TP4 production; RedHat 1M; g9r; D3 | D3 production; other builds retired or rollback | D3 confirmation +8% decode rounds/s; RedHat container restart stall |
| 6, 7, 8 | GLM Flash EXL3 TP4 speed2, Mia lineage, uncensored | retired | stale experiments; uncensored launcher unverified |
| 9, 10 | GLM Flash ModelOpt NVFP4, RedHat MTP2 | retired | ModelOpt corruption path or superseded |
| 11; knapcio campaign | DeepSeek V4.1 Flash SGLang TP4 | production | un-retired 2026-09-25; pinned knapcio fork and local benchmark |
| 13, 14 | GLM 5.2 TP4; DeepSeek V4 Vision TP4 | retired | superseded models |
| 15; local tune, boot speed, TensorFold | Qwen Flash NVFP4 TP2 q10r, v2/v3, TF+D3+B1 | TF+D3+B1 production; older rollback | overnight 2026-09-27 profile measured and set as next-load default |
| 16, 17 | Qwen Flash native EXL3 TP2; TP4 registration | retired | native fresh TTFT much slower; TP4 launcher not verified |
| 18–20 | GLM Flash pair TP2 EXL3, official NVFP4, abliterated | retired | stale/broken provider wiring, no verified current resident |
| 21 | DeepSeek V4 Vision TP2 | retired | superseded |
| 22–24, 27 | Hemmingway, Qwen 27B, Bonsai 2, BGE | out of Spark scope | see single-GPU alternates page; status is not a current probe |
| 25, 26 | Other single-GPU launchers, Dwarfstar | retired | historical/hidden or explicitly retired |
| MiMo V2.6 Flash campaign | SGLang TP4, then TP2 screens | candidate | TP4 baseline proven; TP2 later screens inconclusive/no final promoted resident in this evidence set |
| MiMo V2.6 Pro campaign | SGLang TP6 | retired from tuning | stop instruction before MTP completed; best non-spec profile kept as research record |
| Qwen custom quant campaign | EXL3 mixed-K packs | candidate/rejected | quality/speed comparisons did not promote pack; corpus split caveat |
| DeepSeek prior MiaAI-Lab TP4 | earlier SGLang stack | retired | knapcio fork superseded it |

Migration evidence was read from the dated inventory and campaign summaries. This public register intentionally omits local paths, addresses, logs, pulse identifiers, and raw conversations. A future release should resolve the explicit runtime, overlay and weight pin gaps before calling any template independently reproducible.
