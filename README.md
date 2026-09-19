# modular-cicd-pipeline

A hands-on AWS DevOps project built to demonstrate architectural decision-making, not just tool usage. Every stage of the pipeline is designed to be interchangeable, showing the trade-offs between common technology choices used in real-world enterprise environments.

## Why this project exists

Most portfolio projects replicate a tutorial. This one doesn't. The goal is to show *why* a given tool was chosen over its alternative — the same reasoning an engineer applies in a real team, where infrastructure decisions balance cost, operational maturity, and business context.

## Architecture philosophy

Each stage of the pipeline can be swapped for an alternative, and both options are documented and compared:

| Stage | Options |
|---|---|
| CI/CD | GitHub Actions (implemented) vs. Jenkins (documented, not implemented — see [comparison](./docs/comparisons/jenkins-vs-github-actions.md)) |
| Container registry | Nexus Repository vs. Amazon ECR |
| IaC | Terraform |
| Configuration management | Ansible |
| Orchestration | Kubernetes (Kind/Minikube locally) |
| Observability | Prometheus + Grafana |

Decisions are documented in [`docs/decisions`](./docs/decisions) (ADRs) and summarized in [`docs/comparisons`](./docs/comparisons).

## Getting Started

### Prerequisites
- Docker Desktop
- Terraform (`brew tap hashicorp/tap && brew install hashicorp/tap/terraform`)
- AWS CLI, kubectl, Kind, Helm, Ansible (`brew install awscli kubectl kind helm ansible`)
- An AWS account with credentials configured (`aws configure`)

### About the AWS account
This project was built against a **shared corporate AWS account** (Netcentric AG PoC),
not a personal AWS account. It is not directly reproducible without equivalent
access — the account ID, tagging convention (`Project=Swedbank`), and the
AWS Organizations restriction documented in [ADR 003](./docs/decisions/003-nexus-vs-ecr.md)
are specific to that environment. Anyone adapting this project should swap in
their own AWS account and adjust `terraform/provider.tf` accordingly.

### What's automated vs. manual
| Step | Automated? |
|---|---|
| Docker image build on push to `main` | ✅ Yes — GitHub Actions (`.github/workflows/docker-build.yml`) |
| Push to Nexus registry | ❌ Manual (`docker push`) — Nexus runs on `localhost`, unreachable from GitHub-hosted runners |
| `terraform apply` / `terraform destroy` | ❌ Always manual and deliberate — no auto-apply on push, by design (cost control) |
| Kubernetes deployment (`kubectl apply`) | ❌ Manual |
| Ansible playbook runs | ❌ Manual, only against ephemeral EC2 instances created for that purpose |

Nothing in this repo touches real AWS infrastructure without a human running
a command on purpose. This is intentional — see [ADR 002](./docs/decisions/002-separate-permanent-vs-ephemeral-resources.md).

### Quick start (local components only — no AWS cost)
```bash
# 1. Build and run the app locally
cd docker/app && docker build -t modular-cicd-app:v1 .

# 2. Spin up local Kubernetes and deploy
kind create cluster --name modular-cicd-pipeline
kind load docker-image modular-cicd-app:v1 --name modular-cicd-pipeline
kubectl apply -f k8s/base/

# 3. (Optional) observability
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```
Full step-by-step history, including incidents and fixes, is in [`docs/SETUP.md`](./docs/SETUP.md).

## Project status

✅ **All phases of the original roadmap are complete.** The project now moves into refinement: additional ADRs, comparison write-ups, and portfolio polish.

- [x] Project structure
- [x] AWS provider configuration with default tags
- [x] Terraform remote state (S3 backend)
- [x] Docker containerization
- [x] Kubernetes deployment (Kind)
- [x] CI/CD pipeline (build automation)
- [x] Container registry (Nexus, self-hosted — see ADR 003 for the ECR pivot)
- [x] Observability stack (Prometheus/Grafana)
- [x] Ansible configuration management

## Repository structure

\`\`\`
terraform/       Infrastructure as Code (permanent resources)
terraform-sandbox/  Ephemeral resources (EC2 test instances) — always destroyed after use
docker/          Application containerization
registry/        Placeholder for registry-specific config (Nexus runs standalone via `docker run`, not from here — see docs/SETUP.md)
k8s/             Kubernetes manifests (base + overlays)
ansible/         Configuration management playbooks
.github/workflows/  CI/CD pipeline definitions
jenkins/         Reserved for a documented Jenkins alternative (not yet implemented)
monitoring/      Reserved for Prometheus/Grafana config (currently installed via Helm, not custom manifests here)
docs/            Architecture decisions and comparisons
\`\`\`

## Cost control

This project runs against a shared AWS account. All resources are tagged (`Project`, `Owner`, `Environment`, `ManagedBy`) and provisioned exclusively through Terraform, so they can be reliably destroyed when not in use. EKS is intentionally avoided during development in favor of local Kubernetes (Kind) to prevent unnecessary control-plane costs.

## Author

Daniel Velásquez Iturrate — DevOps Engineer transitioning to Cloud Engineering.
[Portfolio](https://iturrate-cloud-solutions-architect.webflow.io) · [GitHub](https://github.com/velasqueziturrate)
