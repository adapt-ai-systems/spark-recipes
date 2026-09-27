#!/usr/bin/env bash
# Run worker 1 before head 0; reference until exact image/overlays are published.
set -euo pipefail
for v in HEAD_IP RANK_IPS IMAGE WEIGHTS_DIR OVERLAY_DIR HOST_IP RANK; do
  [ -n "${!v:-}" ] && [[ "${!v}" != *'_IP'* ]] && [[ "${!v}" != *'_DIR'* ]] && [[ "${!v}" != *'_NUMBER'* ]] && [[ "${!v}" != *'_BUILD'* ]] || { echo "set $v from private mapping" >&2; exit 2; }
done
read -ra workers <<< "$RANK_IPS"
[ "${#workers[@]}" -eq 1 ] && [[ "$RANK" =~ ^[01]$ ]] || { echo 'TP2 requires one worker and rank 0 or 1' >&2; exit 2; }
for p in "$WEIGHTS_DIR" "$OVERLAY_DIR"; do [ -e "$p" ] || { echo "missing artifact: $p" >&2; exit 2; }; done
[ -f "$OVERLAY_DIR/VERIFIED-EXACT-STACK" ] || { echo 'exact full-file overlays not supplied; see README' >&2; exit 2; }
cmd=(docker run -d --name qwen38-flash-d3b1 --network host --ipc host --gpus all
  --device /dev/infiniband:/dev/infiniband --ulimit nofile=1048576:1048576
  -v "$WEIGHTS_DIR:/model:ro" -e "VLLM_HOST_IP=$HOST_IP"
  -e VLLM_ENABLE_ROCE_ALLREDUCE=1 -e QWEN38_DRAFT_BALANCE=1
  -e QWEN38_W8A16=1 -e QWEN38_W8A16_DENSE=1
  "$IMAGE" vllm serve /model --served-model-name Qwen3.8-Flash-Next-NVFP4
  --tensor-parallel-size 2 --enable-expert-parallel --nnodes 2
  --node-rank "$RANK" --master-addr "$HEAD_IP" --max-model-len 262144
  --max-num-seqs 8 --max-num-batched-tokens 8192 --kv-cache-dtype auto
  --speculative-config '{"method":"mtp","num_speculative_tokens":4,"index_share_for_mtp_iteration":true,"use_local_argmax_reduction":true}'
  --load-format runai_streamer --model-loader-extra-config '{"distributed":false,"concurrency":32,"memory_limit":17179869184}')
printf '%q ' "${cmd[@]}"; echo
[ "${DRY_RUN:-1}" = 1 ] || { echo 'Template cannot reproduce unpublished mounts; refusing execution' >&2; exit 2; }
