#!/bin/bash
# =============================================================
# update-targets.sh
# Discovers all running OpenStack VMs and writes them to
# prometheus/targets.json for Prometheus file_sd scraping.
# Run manually or via cron every 5 minutes.
# =============================================================

set -euo pipefail

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
CONTROLLER_USER="root"
CONTROLLER_IP="192.168.122.55"
OPENRC_DIR="/root/bin"
TARGETS_FILE="$(dirname "$0")/../prometheus/targets.json"
NODE_EXPORTER_PORT="9100"
TEMP_FILE="/tmp/targets_temp_$$.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting VM discovery..."

# -------------------------------------------------------------
# Connect to controller and discover VMs across all projects
# -------------------------------------------------------------
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "${CONTROLLER_USER}@${CONTROLLER_IP}" bash <<'REMOTE_SCRIPT'

OPENRC_DIR="/root/bin"
NODE_EXPORTER_PORT="9100"

# Collect all VMs from all openrc files
all_vms="[]"

for openrc_file in "$OPENRC_DIR"/*.sh; do
    # Skip demo openrc
    basename_file=$(basename "$openrc_file")
    if [[ "$basename_file" == "demo-openrc.sh" ]]; then
        continue
    fi

    # Source the openrc file
    source "$openrc_file" 2>/dev/null || continue

    # Get VM list as JSON
    vm_list=$(openstack server list -f json 2>/dev/null) || continue

    # Extract VM details
    echo "$vm_list" | jq -c \
        --arg openrc "$basename_file" \
        --arg port "$NODE_EXPORTER_PORT" \
        '.[] | select(.Status == "ACTIVE") | {
            vm_id:      .ID,
            vm_name:    .Name,
            openrc:     $openrc,
            floating_ip: (
                .Networks // {} |
                to_entries |
                map(.value) |
                flatten |
                map(select(test("^10\\.0\\.10\\."))) |
                first // (
                    .Networks // {} |
                    to_entries |
                    map(.value) |
                    flatten |
                    first
                )
            ),
            zone: (
                if .Name | test("edge-node-1") then "zone1"
                elif .Name | test("edge-node-2") then "zone2"
                elif .Name | test("edge-node-3") then "standby"
                else "unknown"
                end
            )
        }'
done

REMOTE_SCRIPT

# -------------------------------------------------------------
# Build targets.json locally from SSH output
# -------------------------------------------------------------
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Building targets.json..."

ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "${CONTROLLER_USER}@${CONTROLLER_IP}" bash << 'REMOTE_BUILD'

OPENRC_DIR="/root/bin"
NODE_EXPORTER_PORT="9100"
seen_ids=()
targets=()

for openrc_file in "$OPENRC_DIR"/*.sh; do
    basename_file=$(basename "$openrc_file")
    [[ "$basename_file" == "demo-openrc.sh" ]] && continue
    source "$openrc_file" 2>/dev/null || continue

    vm_list=$(openstack server list -f json 2>/dev/null) || continue

    while IFS= read -r vm; do
        vm_id=$(echo "$vm" | jq -r '.ID')
        vm_name=$(echo "$vm" | jq -r '.Name')
        vm_status=$(echo "$vm" | jq -r '.Status')

        # Only active VMs
        [[ "$vm_status" != "ACTIVE" ]] && continue

        # Deduplicate by VM ID
        if printf '%s\n' "${seen_ids[@]:-}" | grep -q "^${vm_id}$"; then
            continue
        fi
        seen_ids+=("$vm_id")

        # Get floating IP (preferred) or first available IP
        networks=$(echo "$vm" | jq -r '.Networks // empty')
        floating_ip=$(echo "$vm" | python3 -c "
import sys, json
data = json.load(sys.stdin)
networks = data.get('Networks', {})
all_ips = []
for net_ips in networks.values():
    all_ips.extend(net_ips.split(', ') if isinstance(net_ips, str) else net_ips)
# Prefer floating IPs (10.0.10.x range)
floating = [ip for ip in all_ips if ip.startswith('10.0.10.')]
print(floating[0] if floating else (all_ips[0] if all_ips else ''))
" 2>/dev/null << EOF
$(echo "$vm" | python3 -c "
import sys, json
raw = sys.stdin.read()
# parse openstack server list json row
data = json.loads(raw)
print(json.dumps(data))
" 2>/dev/null || echo '{}')
EOF
        )

        [[ -z "$floating_ip" ]] && continue

        # Determine zone from VM name
        if echo "$vm_name" | grep -q "edge-node-1"; then
            zone="zone1"
        elif echo "$vm_name" | grep -q "edge-node-2"; then
            zone="zone2"
        elif echo "$vm_name" | grep -q "edge-node-3"; then
            zone="standby"
        else
            zone="unknown"
        fi

        targets+=("{\"targets\":[\"${floating_ip}:${NODE_EXPORTER_PORT}\"],\"labels\":{\"vm_id\":\"${vm_id}\",\"vm_name\":\"${vm_name}\",\"zone\":\"${zone}\",\"openrc\":\"${basename_file}\"}}")
    done < <(echo "$vm_list" | jq -c '.[]')
done

# Write JSON array
echo "[$(IFS=,; echo "${targets[*]:-}")]"

REMOTE_BUILD

# -------------------------------------------------------------
# Save output to targets.json
# -------------------------------------------------------------
# Re-run and capture output properly
TARGETS_OUTPUT=$(ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "${CONTROLLER_USER}@${CONTROLLER_IP}" bash << 'CAPTURE'

OPENRC_DIR="/root/bin"
NODE_EXPORTER_PORT="9100"
seen_ids=()
entries=()

for openrc_file in "$OPENRC_DIR"/*.sh; do
    basename_file=$(basename "$openrc_file")
    [[ "$basename_file" == "demo-openrc.sh" ]] && continue
    source "$openrc_file" 2>/dev/null || continue
    vm_list=$(openstack server list -f json 2>/dev/null) || continue

    while IFS= read -r row; do
        vm_id=$(echo "$row" | jq -r '.ID // empty')
        vm_name=$(echo "$row" | jq -r '.Name // empty')
        vm_status=$(echo "$row" | jq -r '.Status // empty')
        [[ "$vm_status" != "ACTIVE" ]] && continue
        [[ -z "$vm_id" ]] && continue

        # Dedup
        if printf '%s\n' "${seen_ids[@]:-}" | grep -q "^${vm_id}$"; then
            continue
        fi
        seen_ids+=("$vm_id")

        # Extract floating IP
        floating_ip=$(echo "$row" | jq -r '
            .Networks // {} |
            to_entries |
            map(.value) |
            if type == "array" then . else [.] end |
            flatten |
            map(select(type == "string")) |
            (map(select(startswith("10.0.10."))) | first)
            // (map(select(. != null)) | first)
            // ""
        ' 2>/dev/null || echo "")

        [[ -z "$floating_ip" ]] && continue

        # Zone
        if echo "$vm_name" | grep -q "edge-node-1"; then zone="zone1"
        elif echo "$vm_name" | grep -q "edge-node-2"; then zone="zone2"
        elif echo "$vm_name" | grep -q "edge-node-3"; then zone="standby"
        else zone="unknown"; fi

        entries+=("{\"targets\":[\"${floating_ip}:${NODE_EXPORTER_PORT}\"],\"labels\":{\"vm_id\":\"${vm_id}\",\"vm_name\":\"${vm_name}\",\"zone\":\"${zone}\",\"openrc\":\"${basename_file}\"}}")
    done < <(echo "$vm_list" | jq -c '.[]' 2>/dev/null || true)
done

printf '[\n'
for i in "${!entries[@]}"; do
    if [[ $i -lt $((${#entries[@]} - 1)) ]]; then
        printf '  %s,\n' "${entries[$i]}"
    else
        printf '  %s\n' "${entries[$i]}"
    fi
done
printf ']\n'

CAPTURE
)

# Validate JSON output
if echo "$TARGETS_OUTPUT" | jq . > /dev/null 2>&1; then
    echo "$TARGETS_OUTPUT" > "$TARGETS_FILE"
    VM_COUNT=$(echo "$TARGETS_OUTPUT" | jq '. | length')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] targets.json updated — ${VM_COUNT} active VM(s) discovered."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Invalid JSON output. Keeping existing targets.json."
    echo "Raw output: $TARGETS_OUTPUT"
    exit 1
fi

# Reload Prometheus config via HTTP API
curl -s -X POST http://localhost:9090/-/reload > /dev/null 2>&1 && \
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Prometheus config reloaded." || \
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Could not reload Prometheus (may not be running yet)."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done."
