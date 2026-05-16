# Observability Stack — SRE and Auto-remediation Monitoring System

---

## Overview
An intelligent SRE monitoring platform for simulated IoT on top of an OpenStack Antelope private cloud. The system monitors 36 virtual IoT sensors across 3 zones using a graduated alert response that escalates from local optimization all the way to autonomous VM scale-out.

---

## Architecture

```
VMware Ubuntu Host (lojain@lojain-virtual-machine)
├── Docker Stack
│   ├── Mosquitto      — MQTT broker (IoT sensor messages)
│   ├── Prometheus     — Metrics collection + alerting engine
│   ├── Alertmanager   — Alert routing to n8n
│   ├── Grafana        — Real-time dashboards
│   └── n8n            — Intelligent automation (runs Ansible playbooks)
│
├── Virtual IoT Sensors (36 Docker containers)
│   ├── zone1: 12 sensors (temperature, humidity, light, pressure)
│   ├── zone2: 12 sensors (temperature, humidity, light, pressure)
│   └── zone3: 12 sensors — publishing but no listener until VM3 activates
│
└── OpenStack VMs (VNX/LXC)
    ├── edge-node-1 → Zone 1 processor (always running, compute1)
    ├── edge-node-2 → Zone 2 processor (always running, compute2)
    └── edge-node-3 → Standby (POWERED OFF — activates on emergency)
```

---

## Graduated Alert Response

| Threshold | Severity  | Action                                    |
|-----------|-----------|-------------------------------------------|
| 60%       | Warning   | Notification only                         |
| 75%       | Moderate  | `edge-tune.yml` — local optimizations     |
| 85%       | Critical  | `load-redistribute.yml` — reduce load     |
| 95%       | Emergency | `out-scale.yml`  — VM3 Activate share load with the overloaded zone |

Scale-out: n8n powers on VM3, deploys edge node, redistributes sensors.
Scale-in:  VM3 powers off automatically after recovery.

---

## Quick Start

### Prerequisites
- OpenStack Antelope deployed (Phase 1 of graduation project)
- Docker + Docker Compose installed on Ubuntu host
- SSH access to OpenStack controller at 192.168.122.55

### 1. Create OpenStack resources
```bash
ssh root@192.168.122.55
source /root/bin/admin-openrc.sh

openstack project create edge-monitoring
openstack user create --password edgepass edge-tf
openstack role add --project edge-monitoring --user edge-tf admin

ssh-keygen -t rsa -b 2048 -f ~/.ssh/edge-key -N ""
openstack keypair create --public-key ~/.ssh/edge-key.pub edge-key
# Copy private key to host: ~/.ssh/edge-key.pem
```

### 2. Configure environment
```bash
cp .env.example .env
# Edit .env — add your Telegram bot token and chat ID
```

### 3. Provision infrastructure (Terraform)
```bash
cd terraform/
terraform init
terraform plan
terraform apply
cd ..
```

### 4. Generate Ansible inventory
```bash
./scripts/generate-inventory.sh
```

### 5. Start Docker stack
```bash
mkdir -p logs events/backups
echo "timestamp,vm_id,zone,severity,action,result" > events/events.csv
docker compose up -d
docker compose ps
```

### 6. Deploy Node Exporter + Edge Nodes
```bash
cd ansible/
ansible-playbook playbooks/deploy-node-exporter.yml
ansible-playbook playbooks/deploy-edge.yml
cd ..
```

### 7. Start virtual sensors
```bash
cd virtual-sensors/
./sensors-generate.sh start
./sensors-generate.sh status
cd ..
```

### 8. Set up cron jobs
```bash
crontab -e
# Add:
*/5 * * * * /home/lojain/observability-stack/scripts/update-targets.sh >> /home/lojain/observability-stack/logs/update-targets.log 2>&1
0 0 * * * /home/lojain/observability-stack/scripts/backup-events.sh >> /home/lojain/observability-stack/logs/backup.log 2>&1
```

### 9. Open dashboards
| Service       | URL                        | Credentials     |
|---------------|----------------------------|-----------------|
| Grafana       | http://localhost:3000       | admin / admin123|
| Prometheus    | http://localhost:9090       | —               |
| Alertmanager  | http://localhost:9093       | —               |
| n8n           | http://localhost:5678       | —               |

---

## Demo — Triggering the Alert Chain

```bash
# Step 1: Inject latency to trigger graduated alerts
ansible-playbook ansible/playbooks/latency-simulate.yml \
  -e "target_host=edge-node-1 latency_ms=200"

# → Watch Grafana: warning → moderate → critical → emergency fires
# → Telegram message arrives with 60s countdown
# → Reply YES → VM3 powers on → edge node deploys → load drops

# Step 2: Remove latency and watch recovery
ansible-playbook ansible/playbooks/latency-remove.yml \
  -e "target_host=edge-node-1"

# → Watch Grafana: latency drops → scale-in triggers → VM3 powers off
```

---

## Project Structure

```
observability-stack/
├── .env.example              # Secrets template
├── docker-compose.yml        # 5-service Docker stack
├── vars/config.yml           # Central configuration
├── terraform/                # OpenStack VM provisioning
├── prometheus/               # Scrape config + alert rules
├── alertmanager/             # Alert routing
├── grafana/                  # Dashboards + provisioning
├── mosquitto/                # MQTT broker config
├── scripts/                  # Target discovery + inventory + backup
├── virtual-sensors/          # 36 simulated IoT sensors
├── ansible/
│   ├── inventory.ini         # Auto-generated by Terraform/scripts
│   ├── roles/edge-node/      # Edge node deployment role
│   └── playbooks/            # 8 remediation playbooks
├── events/                   # Event log CSV + backups
└── logs/                     # Script execution logs
```

---

## SRE Metrics

| Metric                  | Target  |
|-------------------------|---------|
| SLA                     | 99.9%   |
| Monthly error budget    | 43.8 min|
| Burn rate alert         | > 2x/hr |
| Heartbeat absence alert | > 30s   |
| Alert cooldown          | 3 min   |
