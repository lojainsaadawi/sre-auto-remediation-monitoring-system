# =============================================================
# Dockerfile — Virtual IoT Sensor
# Lightweight Python container that publishes MQTT messages
# =============================================================

FROM python:3.11-slim

LABEL maintainer="edge-monitoring"
LABEL description="Virtual IoT sensor for edge monitoring simulation"

# Install dependencies
RUN pip install --no-cache-dir paho-mqtt==1.6.1

# Create app directory
WORKDIR /app

# Copy sensor script
COPY sensor.py /app/sensor.py

# Default environment variables (overridden by sensors-generate.sh)
ENV SENSOR_ID=sensor-01
ENV ZONE=zone1
ENV TYPE=temperature
ENV INTERVAL=5
ENV BROKER_IP=192.168.122.1
ENV BROKER_PORT=1883

# Run sensor
CMD ["python3", "-u", "/app/sensor.py"]
