#!/usr/bin/env bash
# Run workers 1..3 before head 0; reference until full overlay set is published.
set -euo pipefail
for v in HEAD_IP RANK_IPS IMAGE WEIGHTS_DIR DRAFT_DIR OVERLAY_DIR HOST_IP RANK; do
  [ -n "${!v:-}" ] && [[ "${!v}" != *'_IP'* ]] && [[ "${!v}" != *'_DIR'* ]] && [[ "${!v}" != *'_NUMBER'* ]] || { echo "set $v from private mapping" >&2; exit 2; }
done
read -ra workers <<< "$RANK_IPS"
[ "${#workers[@]}" -eq 3 ] && [[ "$RANK" =~ ^[0-3]$ ]] || { echo 'TP4 requires three workers and rank 0..3' >&2; exit 2; }
for p in "$WEIGHTS_DIR" "$DRAFT_DIR" "$OVERLAY_DIR"; do [ -e "$p" ] || { echo "missing artifact: $p" >&2; exit 2; }; done
[ -f "$OVERLAY_DIR/VERIFIED-EXACT-STACK" ] || { echo 'exact full-file overlays not supplied; see README' >&2; exit 2; }
cmd=(docker run -d --name glm53-flash-d3 --network host --ipc host --gpus all
  --device /dev/infiniband:/dev/infiniband --ulimit nofile=1048576:1048576
  -v "$WEIGHTS_DIR:/model:ro" -v "$DRAFT_DIR:/draft:ro"
  -e "VLLM_HOST_IP=$HOST_IP" -e VLLM_ENABLE_ROCE_ALLREDUCE=1
  -e VLLM_ROCE_ALLREDUCE_MAX_SIZE=256KB -e VLLM_ROCE_ALLGATHER_MAX_SIZE=2MB
  "$IMAGE" vllm serve /model --served-model-name glm-5.3-flash
  --tensor-parallel-size 4 --nnodes 4 --node-rank "$RANK" --master-addr "$HEAD_IP"
  --max-model-len 500000 --max-num-seqs 64 --max-num-batched-tokens 16384
  --kv-cache-dtype fp8_e4m3 --kv-cache-memory 25769803776 --moe-backend marlin
  --linear-backend humming --speculative-config '{"method":"dflash","model":"/draft","num_speculative_tokens":3}'
  --load-format runai_streamer
  --model-loader-extra-config '{"distributed":false,"concurrency":16,"memory_limit":17179869184}')
printf '%q ' "${cmd[@]}"; echo
[ "${DRY_RUN:-1}" = 1 ] || { echo 'Template cannot reproduce unpublished mounts; refusing execution' >&2; exit 2; }
