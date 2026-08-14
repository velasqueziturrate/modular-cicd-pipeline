# modular-cicd-pipeline

A hands-on AWS DevOps project built to demonstrate architectural decision-making, not just tool usage. Every stage of the pipeline is designed to be interchangeable, showing the trade-offs between common technology choices used in real-world enterprise environments.

## Why this project exists

Most portfolio projects replicate a tutorial. This one doesn't. The goal is to show *why* a given tool was chosen over its alternative — the same reasoning an engineer applies in a real team, where infrastructure decisions balance cost, operational maturity, and business context.

## Architecture philosophy

Each stage of the pipeline can be swapped for an alternative, and both options are documented and compared:

| Stage | Options |
|---|---|
| CI/CD | GitHub Actions vs. Jenkins |
| Container registry | Nexus Repository vs. Amazon ECR |
| IaC | Terraform |
| Configuration management | Ansible |
| Orchestration | Kubernetes (Kind/Minikube locally) |
| Observability | Prometheus + Grafana |

Decisions are documented in [`docs/decisions`](./docs/decisions) (ADRs) and summarized in [`docs/comparisons`](./docs/comparisons).

## Project status

🚧 **In progress** — currently setting up core infrastructure (Terraform state, AWS provider configuration).

- [x] Project structure
- [x] AWS provider configuration with default tags
- [ ] Terraform remote state (S3 backend)
- [ ] Docker containerization
- [ ] Kubernetes deployment (Kind)
- [ ] CI/CD pipeline
- [ ] Ansible configuration management
- [ ] Observability stack (Prometheus/Grafana)

## Repository structure

terraform/ Infrastructure as Code
docker/ Application containerization
registry/ Nexus and ECR configurations
k8s/ Kubernetes manifests (base + overlays)
ansible/ Configuration management
.github/workflows/ CI/CD pipeline definitions
jenkins/ Alternative CI/CD setup
monitoring/ Prometheus and Grafana configs
docs/ Architecture decisions and comparisons

## Cost control

This project runs against a shared AWS account. All resources are tagged (`Project`, `Owner`, `Environment`, `ManagedBy`) and provisioned exclusively through Terraform, so they can be reliably destroyed when not in use. EKS is intentionally avoided during development in favor of local Kubernetes (Kind) to prevent unnecessary control-plane costs.

## Author

Daniel Velásquez Iturrate — DevOps Engineer transitioning to Cloud Engineering.
[Portfolio](https://iturrate-cloud-solutions-architect.webflow.io) · [GitHub](https://github.com/velasqueziturrate)
