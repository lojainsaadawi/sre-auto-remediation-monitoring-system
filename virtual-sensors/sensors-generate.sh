#!/bin/bash
# =============================================================
# sensors-generate.sh
# Builds the sensor image and launches 36 sensor containers:
#   - 12 sensors per zone (zone1, zone2, zone3)
#   - 3 sensors per type (temperature, humidity, light, pressure)
#
# Usage:
#   ./sensors-generate.sh start              # Start all 36 sensors
#   ./sensors-generate.sh start zone1        # Start zone1 sensors only
#   ./sensors-generate.sh stop               # Stop all sensors
#   ./sensors-generate.sh stop zone1         # Stop zone1 sensors only
#   ./sensors-generate.sh status             # Show running sensors
#   ./sensors-generate.sh stress zone1       # Stress mode: interval=1s
#   ./sensors-generate.sh normal zone1       # Normal mode: interval=5s
# =============================================================

set -euo pipefail

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="virtual-sensor:latest"
BROKER_IP="172.20.0.10"
BROKER_PORT="1883"
NORMAL_INTERVAL="5"
STRESS_INTERVAL="1"

ZONES=("zone1" "zone2" "zone3")
TYPES=("temperature" "humidity" "light" "pressure")
SENSORS_PER_TYPE=3

# -------------------------------------------------------------
# Build sensor image
# -------------------------------------------------------------
build_image() {
    echo "[$(date '+%H:%M:%S')] Building sensor Docker image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" --quiet
    echo "[$(date '+%H:%M:%S')] Image built: $IMAGE_NAME"
}

# -------------------------------------------------------------
# Start sensors for a specific zone
# -------------------------------------------------------------
start_zone() {
    local zone="$1"
    local interval="${2:-$NORMAL_INTERVAL}"

    echo "[$(date '+%H:%M:%S')] Starting sensors for $zone (interval=${interval}s)..."

    for type in "${TYPES[@]}"; do
        for i in $(seq 1 $SENSORS_PER_TYPE); do
            sensor_id="${type}-${zone}-$(printf '%02d' $i)"
            container_name="sensor-${sensor_id}"

            # Remove if already exists
            docker rm -f "$container_name" > /dev/null 2>&1 || true

            docker run -d \
                --name "$container_name" \
                --restart unless-stopped \
                --network host \
                -e SENSOR_ID="$sensor_id" \
                -e ZONE="$zone" \
                -e TYPE="$type" \
                -e INTERVAL="$interval" \
                -e BROKER_IP="$BROKER_IP" \
                -e BROKER_PORT="$BROKER_PORT" \
                "$IMAGE_NAME" > /dev/null

            echo "  Started: $container_name ($type in $zone)"
        done
    done

    local count=$((${#TYPES[@]} * SENSORS_PER_TYPE))
    echo "[$(date '+%H:%M:%S')] $zone: $count sensors running."
}

# -------------------------------------------------------------
# Stop sensors for a specific zone
# -------------------------------------------------------------
stop_zone() {
    local zone="$1"
    echo "[$(date '+%H:%M:%S')] Stopping sensors for $zone..."

    for type in "${TYPES[@]}"; do
        for i in $(seq 1 $SENSORS_PER_TYPE); do
            sensor_id="${type}-${zone}-$(printf '%02d' $i)"
            container_name="sensor-${sensor_id}"
            docker rm -f "$container_name" > /dev/null 2>&1 && \
                echo "  Stopped: $container_name" || true
        done
    done

    echo "[$(date '+%H:%M:%S')] $zone sensors stopped."
}

# -------------------------------------------------------------
# Show sensor status
# -------------------------------------------------------------
show_status() {
    echo ""
    echo "============================================="
    echo " Running Sensor Containers"
    echo "============================================="
    echo ""
    printf "%-40s %-10s %-10s\n" "CONTAINER" "STATUS" "ZONE"
    echo "---------------------------------------------"

    for zone in "${ZONES[@]}"; do
        for type in "${TYPES[@]}"; do
            for i in $(seq 1 $SENSORS_PER_TYPE); do
                sensor_id="${type}-${zone}-$(printf '%02d' $i)"
                container_name="sensor-${sensor_id}"
                status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not found")
                printf "%-40s %-10s %-10s\n" "$container_name" "$status" "$zone"
            done
        done
    done

    echo ""
    total=$(docker ps --filter "name=sensor-" --format "{{.Names}}" | wc -l)
    echo "Total running: $total / 36"
    echo "============================================="
}

# -------------------------------------------------------------
# Set interval for a zone (stress or normal mode)
# -------------------------------------------------------------
set_interval() {
    local zone="$1"
    local interval="$2"
    local mode="$3"

    echo "[$(date '+%H:%M:%S')] Switching $zone to $mode mode (interval=${interval}s)..."
    stop_zone "$zone"
    sleep 2
    start_zone "$zone" "$interval"
    echo "[$(date '+%H:%M:%S')] $zone is now in $mode mode."
}

# -------------------------------------------------------------
# Main command dispatcher
# -------------------------------------------------------------
COMMAND="${1:-start}"
TARGET_ZONE="${2:-all}"

case "$COMMAND" in

    start)
        build_image
        if [[ "$TARGET_ZONE" == "all" ]]; then
            for zone in "${ZONES[@]}"; do
                start_zone "$zone" "$NORMAL_INTERVAL"
            done
            echo ""
            echo "[$(date '+%H:%M:%S')] All 36 sensors started successfully."
        else
            start_zone "$TARGET_ZONE" "$NORMAL_INTERVAL"
        fi
        ;;

    stop)
        if [[ "$TARGET_ZONE" == "all" ]]; then
            for zone in "${ZONES[@]}"; do
                stop_zone "$zone"
            done
            echo "[$(date '+%H:%M:%S')] All sensors stopped."
        else
            stop_zone "$TARGET_ZONE"
        fi
        ;;

    status)
        show_status
        ;;

    stress)
        if [[ "$TARGET_ZONE" == "all" ]]; then
            echo "ERROR: Specify a zone for stress mode. Example: ./sensors-generate.sh stress zone1"
            exit 1
        fi
        set_interval "$TARGET_ZONE" "$STRESS_INTERVAL" "STRESS"
        ;;

    normal)
        if [[ "$TARGET_ZONE" == "all" ]]; then
            for zone in "${ZONES[@]}"; do
                set_interval "$zone" "$NORMAL_INTERVAL" "NORMAL"
            done
        else
            set_interval "$TARGET_ZONE" "$NORMAL_INTERVAL" "NORMAL"
        fi
        ;;

    restart)
        echo "[$(date '+%H:%M:%S')] Restarting all sensors..."
        for zone in "${ZONES[@]}"; do
            stop_zone "$zone"
        done
        sleep 3
        for zone in "${ZONES[@]}"; do
            start_zone "$zone" "$NORMAL_INTERVAL"
        done
        echo "[$(date '+%H:%M:%S')] All sensors restarted."
        ;;

    *)
        echo "Usage: $0 {start|stop|status|stress|normal|restart} [zone1|zone2|zone3|all]"
        echo ""
        echo "Examples:"
        echo "  $0 start              # Start all 36 sensors"
        echo "  $0 start zone1        # Start zone1 sensors only"
        echo "  $0 stop zone2         # Stop zone2 sensors"
        echo "  $0 stress zone1       # Overload zone1 (interval=1s)"
        echo "  $0 normal zone1       # Return zone1 to normal (interval=5s)"
        echo "  $0 status             # Show all sensor statuses"
        exit 1
        ;;
esac
