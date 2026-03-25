# 🛠️ DevOps Automation Toolkit

> A progressive collection of real DevOps scripts, configs, and infrastructure code —
> built from the ground up following the natural learning path of a DevOps engineer.


![License](https://img.shields.io/badge/license-MIT-blue)
![Phase](https://img.shields.io/badge/current%20phase-Linux%20Fundamentals-orange)

---

## 🗺️ Learning Path

This repo follows a deliberate, sequential learning path. Each phase builds on the last.

| Phase | Topic | Status |
|-------|-------|--------|
| 🐧 1 | Linux Fundamentals | 🔄 In Progress |
| 🐚 2 | Bash Scripting | |
| 🐳 3 | Docker & Containers |   |
| ⚙️ 4 | CI/CD — GitHub Actions |  |
| 🏗️ 5 | Infrastructure as Code (Terraform) |  |
| ☁️ 6 | Cloud Automation (AWS & GCP) |  |
| ☸️ 7 | Kubernetes | |
| 🎡 8 | Helm & GitOps (ArgoCD) |  |
| 📊 9 | Monitoring & Alerting | |
| 🔐 10 | Security & Secrets Management | |

---

## 📁 Repository Structure

```
devops-automation-toolkit/
├── linux/          # System scripts, cron jobs, user management
├── bash/           # Automation scripts, health checks, backups
├── docker/         # Dockerfiles, Compose stacks, container management
├── ci-cd/          # GitHub Actions workflows
├── terraform/      # AWS & GCP infra provisioning
├── cloud/          # Python scripts for AWS & GCP automation
├── kubernetes/     # K8s manifests, RBAC, Ingress configs
├── helm/           # Custom Helm charts
├── gitops/         # ArgoCD manifests
├── monitoring/     # Prometheus, Grafana, alerting
└── security/       # Vault, secrets rotation, image scanning
```

---

## 🐧 Phase 1: Linux Fundamentals

Scripts for essential Linux system administration tasks.

| Script | Description |
|--------|-------------|
| `linux/system-info.sh` | One-shot report: CPU, RAM, disk usage, uptime |
| `linux/user-management.sh` | Create/delete users, assign groups, set permissions |
| `linux/log-analyzer.sh` | Parse system logs, extract errors, generate summary |
| `linux/disk-cleanup.sh` | Find and remove large files, rotate old logs |
| `linux/process-monitor.sh` | Monitor top processes, kill by name or PID |
| `linux/cron/` | Example cron jobs: backups, health pings, log rotation |

---

## 🚀 Quick Start

Each folder contains a dedicated `README.md` with usage examples.

```bash
# Clone the repo
git clone https://github.com/aniruddhajadhav7/devops-automation-toolkit.git
cd devops-automation-toolkit

# Example: run the system info script
chmod +x linux/system-info.sh
./linux/system-info.sh
```

---

## 🧰 Tech Stack

`Bash` `Python` `Docker` `Terraform` `Kubernetes` `Helm` `ArgoCD`
`GitHub Actions` `AWS` `GCP` `Prometheus` `Grafana` `HashiCorp Vault`

---

## 📌 About This Project

This toolkit is built over my learning journey but repo cretaed in march 2026 till then it was local.
the natural DevOps learning sequence. It's designed to be:

- **Practical** — every script solves a real problem
- **Progressive** — complexity increases with each phase
- **Clean** — documented, modular, and production-aware

---

## 📄 License

MIT © Aniruddha Jadhav
