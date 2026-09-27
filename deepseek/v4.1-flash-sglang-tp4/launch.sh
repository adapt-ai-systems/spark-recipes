#!/usr/bin/env bash
# Use the pinned upstream implementation; do not duplicate its service/NFS lifecycle here.
set -euo pipefail
for v in HEAD_IP RANK_IPS UPSTREAM_CHECKOUT WEIGHTS_DIR ENGRAM_DIR; do
  [ -n "${!v:-}" ] && [[ "${!v}" != *'_IP'* ]] && [[ "${!v}" != *'_DIR'* ]] && [[ "${!v}" != *'PINNED_UPSTREAM'* ]] || { echo "set $v privately" >&2; exit 2; }
done
read -ra workers <<< "$RANK_IPS"
[ "${#workers[@]}" -eq 3 ] || { echo 'TP4 requires three workers' >&2; exit 2; }
for p in "$UPSTREAM_CHECKOUT" "$WEIGHTS_DIR" "$ENGRAM_DIR"; do [ -e "$p" ] || { echo "missing artifact: $p" >&2; exit 2; }; done
actual=$(git -C "$UPSTREAM_CHECKOUT" rev-parse --short=7 HEAD)
[ "$actual" = 7ac7123 ] || { echo "wrong upstream commit: $actual" >&2; exit 2; }
printf 'HEAD_IP=%q RANK_IPS=%q WEIGHTS_DIR=%q ENGRAM_DIR=%q %q serve\n' "$HEAD_IP" "$RANK_IPS" "$WEIGHTS_DIR" "$ENGRAM_DIR" "$UPSTREAM_CHECKOUT/start-tp4.sh"
[ "${DRY_RUN:-1}" = 1 ] || { echo 'Review and configure upstream deployment file before serving' >&2; exit 2; }
