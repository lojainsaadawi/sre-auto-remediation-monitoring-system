#!/bin/bash
# Kill existing tunnels
kill $(pgrep -f "ssh.*9101") 2>/dev/null
kill $(pgrep -f "ssh.*1884") 2>/dev/null
sleep 2

# Start all tunnels
ssh -f -N \
  -L 0.0.0.0:9101:10.0.10.153:9100 \
  -L 0.0.0.0:9102:10.0.10.187:9100 \
  -L 0.0.0.0:1884:10.0.10.11:1883 \
  root@192.168.122.55

echo "Tunnels started"
ss -tlnp | grep -E "9101|9102|1884"
