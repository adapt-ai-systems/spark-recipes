#!/usr/bin/env bash
# Run on each node: workers 1..5 first, then head rank 0. Reference template.
set -euo pipefail
for v in HEAD_IP RANK_IPS IMAGE WEIGHTS_DIR OVERLAY_DIR GPTQ_CODES_DIR HOST_IP RANK; do
  [ -n "${!v:-}" ] && [[ "${!v}" != *'_IP'* ]] && [[ "${!v}" != *'_DIR'* ]] && [[ "${!v}" != *'_NUMBER'* ]] && [[ "${!v}" != *'_BUILD'* ]] || { echo "set $v from your private mapping" >&2; exit 2; }
done
read -ra workers <<< "$RANK_IPS"
[ "${#workers[@]}" -eq 5 ] && [[ "$RANK" =~ ^[0-5]$ ]] || { echo 'TP6 requires five workers and rank 0..5' >&2; exit 2; }
for p in "$WEIGHTS_DIR" "$OVERLAY_DIR" "$GPTQ_CODES_DIR"; do [ -e "$p" ] || { echo "missing artifact: $p" >&2; exit 2; }; done
# The exact private GPTQ/D2/D3 overlay implementation is not included; refuse a false stock run.
[ -f "$OVERLAY_DIR/VERIFIED-EXACT-STACK" ] || { echo 'exact stack overlays not supplied; see README' >&2; exit 2; }
cmd=(docker run -d --name glm53-full-tp6 --network host --ipc host --gpus all
  --device /dev/infiniband:/dev/infiniband --ulimit nofile=1048576:1048576
  -v "$WEIGHTS_DIR:/model:ro" -v "$GPTQ_CODES_DIR:/d8gptq-w:ro"
  -e "VLLM_HOST_IP=$HOST_IP" -e GLM_D2_FP8=1 -e GLM_D8_W4=1 -e GLM_D8_W4_GROUP=32
  -e VLLM_MARLIN_USE_ATOMIC_ADD=1 "$IMAGE" vllm serve /model
  --served-model-name glm-5.3 --tensor-parallel-size 6 --nnodes 6 --node-rank "$RANK"
  --master-addr "$HEAD_IP" --max-model-len 360000 --max-num-seqs 4
  --speculative-config '{"num_speculative_tokens":2}'
  --compilation-config '{"cudagraph_mode":"FULL","cudagraph_capture_sizes":[3,6,9,12]}')
printf '%q ' "${cmd[@]}"; echo
[ "${DRY_RUN:-1}" = 1 ] || { echo 'Template cannot reproduce unpublished mounts; refusing execution' >&2; exit 2; }
