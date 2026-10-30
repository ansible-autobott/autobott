#!/bin/bash
# ============================================================================================================
# Remove the iptables rules and bridges Docker leaves behind
# ============================================================================================================
# Stopping or uninstalling Docker does not remove its iptables rules, chains and bridges: they stay until the
# next reboot. Its FORWARD -> DOCKER-USER jump in particular keeps filtering all forwarded traffic (e.g. k3s's
# ingress). In iptables and ip6tables, this removes:
#
#   - the rules of other chains that jump to a Docker chain (DOCKER*) or match a Docker bridge (docker0,
#     br-<network id>),
#   - Docker's chains, except a DOCKER-USER that holds UFW's rules: the firewall role defines it in UFW's
#     after.rules (ufw-docker), so UFW recreates it on every start. Without the jump from FORWARD it filters
#     nothing.
#
# and deletes the bridges. Nothing else is touched.
#
# Run it only after Docker is stopped: a running dockerd recreates its rules.
# Prints one line per removed item (nothing when Docker left nothing behind).
set -euo pipefail

bridges='(docker0|br-[0-9a-f]{12})'

for ipt in iptables ip6tables; do
  command -v "$ipt" >/dev/null || continue
  for table in filter nat mangle raw; do
    rules="$("$ipt" -t "$table" -S 2>/dev/null)" || continue

    # Rules outside Docker's chains that point at them (the rules inside go with their chain)
    while IFS= read -r rule; do
      eval "$ipt -t $table -D ${rule#-A }"
      echo "$ipt -t $table: deleted rule: $rule"
    done < <(printf '%s\n' "$rules" | grep -E '^-A ' | grep -vE '^-A DOCKER' \
      | grep -E -- "-j DOCKER|-[io] $bridges( |\$)" || true)

    # Docker's chains; a DOCKER-USER that holds UFW's rules stays (see above)
    ufw_user=0
    if grep -qE '^-A DOCKER-USER .*-j ufw' <<<"$rules"; then ufw_user=1; fi
    chains="$(printf '%s\n' "$rules" \
      | awk -v keep_user="$ufw_user" '$1 == "-N" && $2 ~ /^DOCKER/ && !(keep_user && $2 == "DOCKER-USER") { print $2 }')"

    # Flush all of them before deleting any: they jump to each other
    for chain in $chains; do
      "$ipt" -t "$table" -F "$chain"
    done
    for chain in $chains; do
      "$ipt" -t "$table" -X "$chain"
      echo "$ipt -t $table: deleted chain $chain"
    done
  done
done

for bridge in $(ip -o link show type bridge | awk -F': ' '{ print $2 }' | grep -E "^$bridges\$" || true); do
  ip link delete "$bridge"
  echo "deleted bridge $bridge"
done
