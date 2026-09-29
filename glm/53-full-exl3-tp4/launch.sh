#!/usr/bin/env bash
# Run on each node: workers 1..3 first, then head rank 0. Reference template.
set -euo pipefail
for v in HEAD_IP RANK_IPS IMAGE WEIGHTS_DIR OVERLAY_DIR GPTQ_CODES_DIR HOST_IP RANK; do
  [ -n "${!v:-}" ] && [[ "${!v}" != *'_IP'* ]] && [[ "${!v}" != *'_DIR'* ]] && [[ "${!v}" != *'_NUMBER'* ]] && [[ "${!v}" != *'_BUILD'* ]] || { echo "set $v from your private mapping" >&2; exit 2; }
done
read -ra workers <<< "$RANK_IPS"
[ "${#workers[@]}" -eq 3 ] && [[ "$RANK" =~ ^[0-3]$ ]] || { echo 'TP4 requires three workers and rank 0..3' >&2; exit 2; }
for p in "$WEIGHTS_DIR" "$OVERLAY_DIR" "$GPTQ_CODES_DIR"; do [ -e "$p" ] || { echo "missing artifact: $p" >&2; exit 2; }; done
# The TP4 E3/DCP2/D2/D3/GPTQ overlay implementation is not included; refuse a false stock run.
[ -f "$OVERLAY_DIR/VERIFIED-EXACT-STACK" ] || { echo 'exact stack overlays not supplied; see README' >&2; exit 2; }
cmd=(docker run -d --name glm53-full-tp4 --network host --ipc host --gpus all
  --device /dev/infiniband:/dev/infiniband --ulimit nofile=1048576:1048576
  -v "$WEIGHTS_DIR:/model:ro" -v "$GPTQ_CODES_DIR:/d8gptq-w:ro"
  -e "VLLM_HOST_IP=$HOST_IP" -e TP4_E3_PREFILL=1 -e VLLM_EXL3_PREFILL_CAPACITY=4096
  -e GLM_D2_FP8=1 -e GLM_D2_FP8_BIG=w8a8 -e GLM_D8_W4=1 -e GLM_D8_W4_GROUP=32 -e GLM_D8_GPTQ_DIR=/d8gptq-w
  -e NCCL_IB_MERGE_NICS=1 -e VLLM_ENABLE_ROCE_ALLREDUCE=1
  -e VLLM_ROCE_ALLREDUCE_MAX_SIZE=256KB -e VLLM_ROCE_ALLGATHER_MAX_SIZE=2MB
  -e VLLM_MARLIN_USE_ATOMIC_ADD=1 "$IMAGE" vllm serve /model
  --served-model-name glm-5.3 --tensor-parallel-size 4 --decode-context-parallel-size 2
  --nnodes 4 --node-rank "$RANK" --master-addr "$HEAD_IP" --distributed-executor-backend mp
  --quantization exl3 --dtype bfloat16 --kv-cache-dtype fp8_ds_mla
  --attention-backend FLASHINFER_MLA_SPARSE_SM120 --disable-custom-all-reduce
  --max-model-len 360000 --max-num-seqs 4 --max-num-batched-tokens 4096
  --gpu-memory-utilization 0.85 --kv-cache-memory-bytes 20000000000 --enable-prefix-caching
  --enable-auto-tool-choice --tool-call-parser glm47 --reasoning-parser glm45
  --speculative-config '{"method":"mtp","num_speculative_tokens":4,"draft_tensor_parallel_size":4}'
  --compilation-config '{"cudagraph_mode":"FULL","cudagraph_capture_sizes":[5,10,15,20]}')
printf '%q ' "${cmd[@]}"; echo
[ "${DRY_RUN:-1}" = 1 ] || { echo 'Template cannot reproduce unpublished mounts; refusing execution' >&2; exit 2; }
