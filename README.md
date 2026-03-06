# 🛠️ DevOps Automation Toolkit

> A progressive collection of real DevOps scripts, configs, and infrastructure code —
> built from the ground up following the natural learning path of a DevOps engineer.

![GitHub last commit](https://img.shields.io/github/last-commit/YOUR_USERNAME/devops-automation-toolkit)
![GitHub commit activity](https://img.shields.io/github/commit-activity/w/YOUR_USERNAME/devops-automation-toolkit)
![License](https://img.shields.io/badge/license-MIT-blue)
![Phase](https://img.shields.io/badge/current%20phase-Linux%20Fundamentals-orange)

---

## 🗺️ Learning Path

This repo follows a deliberate, sequential learning path. Each phase builds on the last.

| Phase | Topic | Status |
|-------|-------|--------|
| 🐧 1 | Linux Fundamentals | 🔄 In Progress |
| 🐚 2 | Bash Scripting | ⏳ Upcoming |
| 🐳 3 | Docker & Containers | ⏳ Upcoming |
| ⚙️ 4 | CI/CD — GitHub Actions | ⏳ Upcoming |
| 🏗️ 5 | Infrastructure as Code (Terraform) | ⏳ Upcoming |
| ☁️ 6 | Cloud Automation (AWS & GCP) | ⏳ Upcoming |
| ☸️ 7 | Kubernetes | ⏳ Upcoming |
| 🎡 8 | Helm & GitOps (ArgoCD) | ⏳ Upcoming |
| 📊 9 | Monitoring & Alerting | ⏳ Upcoming |
| 🔐 10 | Security & Secrets Management | ⏳ Upcoming |

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
git clone https://github.com/YOUR_USERNAME/devops-automation-toolkit.git
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

This toolkit is built over ~3 months with commits every 2 days — following
the natural DevOps learning sequence. It's designed to be:

- **Practical** — every script solves a real problem
- **Progressive** — complexity increases with each phase
- **Clean** — documented, modular, and production-aware

---

## 📄 License

MIT © YOUR_NAME
