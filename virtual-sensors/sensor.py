#!/usr/bin/env python3
# =============================================================
# sensor.py
# Virtual IoT Sensor — publishes simulated data via MQTT
# Environment variables:
#   SENSOR_ID   : unique sensor identifier (e.g. temp-zone1-01)
#   ZONE        : zone1 | zone2 | zone3
#   TYPE        : temperature | humidity | light | pressure
#   INTERVAL    : publish interval in seconds (default: 5)
#   BROKER_IP   : MQTT broker IP (default: 192.168.122.1)
#   BROKER_PORT : MQTT broker port (default: 1883)
# =============================================================

import os
import json
import time
import random
import signal
import sys
import logging
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

# -------------------------------------------------------------
# Logging
# -------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
log = logging.getLogger(__name__)

# -------------------------------------------------------------
# Configuration from environment variables
# -------------------------------------------------------------
SENSOR_ID   = os.environ.get('SENSOR_ID',   'sensor-unknown-01')
ZONE        = os.environ.get('ZONE',        'zone1')
TYPE        = os.environ.get('TYPE',        'temperature')
INTERVAL    = float(os.environ.get('INTERVAL', '5'))
BROKER_IP   = os.environ.get('BROKER_IP',   '192.168.122.1')
BROKER_PORT = int(os.environ.get('BROKER_PORT', '1883'))

# MQTT topic: sensors/<ZONE>/<TYPE>/<SENSOR_ID>
TOPIC = f"sensors/{ZONE}/{TYPE}/{SENSOR_ID}"

# -------------------------------------------------------------
# Sensor value ranges per type
# -------------------------------------------------------------
SENSOR_RANGES = {
    'temperature': {'min': 18.0,  'max': 45.0,  'unit': 'celsius',   'decimals': 2},
    'humidity':    {'min': 30.0,  'max': 95.0,  'unit': 'percent',   'decimals': 2},
    'light':       {'min': 100.0, 'max': 1000.0,'unit': 'lux',       'decimals': 1},
    'pressure':    {'min': 950.0, 'max': 1050.0,'unit': 'hPa',       'decimals': 2},
}

# -------------------------------------------------------------
# Global state
# -------------------------------------------------------------
running = True
client  = None

# -------------------------------------------------------------
# Signal handler for graceful shutdown
# -------------------------------------------------------------
def handle_shutdown(signum, frame):
    global running
    log.info(f"Shutdown signal received. Stopping sensor {SENSOR_ID}...")
    running = False

signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT,  handle_shutdown)

# -------------------------------------------------------------
# Generate a realistic sensor reading with slight drift
# -------------------------------------------------------------
def generate_value(sensor_type: str, previous: float = None) -> float:
    config = SENSOR_RANGES.get(sensor_type, SENSOR_RANGES['temperature'])
    min_val    = config['min']
    max_val    = config['max']
    decimals   = config['decimals']

    if previous is None:
        # First reading — start at a random point in the middle range
        value = random.uniform(
            min_val + (max_val - min_val) * 0.2,
            max_val - (max_val - min_val) * 0.2
        )
    else:
        # Subsequent readings — small random drift from previous value
        drift = random.uniform(-0.5, 0.5) * (max_val - min_val) * 0.02
        value = previous + drift
        value = max(min_val, min(max_val, value))

    return round(value, decimals)

# -------------------------------------------------------------
# MQTT callbacks
# -------------------------------------------------------------
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        log.info(f"Connected to MQTT broker at {BROKER_IP}:{BROKER_PORT}")
    else:
        log.error(f"Failed to connect to broker. Return code: {rc}")

def on_disconnect(client, userdata, rc):
    if rc != 0:
        log.warning(f"Unexpected disconnection from broker (rc={rc}). Will retry...")

def on_publish(client, userdata, mid):
    pass  # Silent on successful publish

# -------------------------------------------------------------
# Main sensor loop
# -------------------------------------------------------------
def main():
    global client

    config = SENSOR_RANGES.get(TYPE, SENSOR_RANGES['temperature'])
    log.info(f"Starting sensor: ID={SENSOR_ID} ZONE={ZONE} TYPE={TYPE}")
    log.info(f"Topic: {TOPIC}")
    log.info(f"Broker: {BROKER_IP}:{BROKER_PORT}")
    log.info(f"Publish interval: {INTERVAL}s")

    # Setup MQTT client
    client = mqtt.Client(client_id=SENSOR_ID, clean_session=True)
    client.on_connect    = on_connect
    client.on_disconnect = on_disconnect
    client.on_publish    = on_publish

    # Connect with retry
    connected = False
    retry_count = 0
    while not connected and running:
        try:
            client.connect(BROKER_IP, BROKER_PORT, keepalive=60)
            client.loop_start()
            connected = True
        except Exception as e:
            retry_count += 1
            log.warning(f"Cannot connect to broker (attempt {retry_count}): {e}")
            time.sleep(5)

    if not running:
        return

    previous_value = None

    # Publish loop
    while running:
        try:
            value = generate_value(TYPE, previous_value)
            previous_value = value

            payload = {
                "sensor_id": SENSOR_ID,
                "zone":      ZONE,
                "type":      TYPE,
                "value":     value,
                "unit":      config['unit'],
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

            result = client.publish(
                TOPIC,
                json.dumps(payload),
                qos=1,
                retain=False
            )

            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                log.debug(f"Published: {TOPIC} = {value} {config['unit']}")
            else:
                log.warning(f"Publish failed: rc={result.rc}")

        except Exception as e:
            log.error(f"Error during publish: {e}")

        time.sleep(INTERVAL)

    # Graceful shutdown
    log.info(f"Sensor {SENSOR_ID} shutting down...")
    client.loop_stop()
    client.disconnect()
    log.info(f"Sensor {SENSOR_ID} stopped.")

if __name__ == '__main__':
    main()

