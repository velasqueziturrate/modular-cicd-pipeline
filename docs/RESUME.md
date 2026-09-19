# How to Resume This Project

This file is the single entry point for picking this project back up after
a long pause. Read this before touching anything else.

## 1. Current state (as of the pause)

- **AWS**: only one resource exists — the Terraform state bucket
  `dvi-modular-cicd-pipeline-tfstate` (region `us-east-1`). No EC2, no ECR,
  no IAM users beyond your own personal one. Verified clean before pausing.
- **Local (Mac)**: Kind cluster deleted. Nexus container stopped and
  removed, but its data volume (`nexus-data`) is preserved.
- **GitHub**: everything up to date on `main`, nothing uncommitted.

## 2. First thing to do when resuming: re-verify nothing drifted

Never assume the state above is still accurate — verify it fresh:

```bash
cd terraform && terraform state list && cd ..
cd terraform-sandbox && terraform state list && cd ..
aws ec2 describe-instances --region us-east-1 \
  --query "Reservations[].InstancState.Name!='terminated'].[InstanceId,State.Name]" \
  --output table
docker ps -a
kind get clusters
docker volume ls | grep nexus
```

Expected: `terraform/` state shows only the 4 S3 bucket resources;
`terraform-sandbox/` is empty; no running EC2 instances; no Docker
containers running; no Kind clusters; `nexus-data` volume still present.

## 3. Rebuilding the local environment from scratch

Tools (if this is a new machine or a fresh macOS install):
```bash
brew install --cask docker
brew install awscli
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
brew install kubectl kind helm ansible
```

AWS credentials:
```bash
aws configure
# region: us-east-1, output: json
# Access key: your personal IAM key (daniel.velasquez) — regenerate via
# IAM > Users > daniel.velasquez > Security credentials if the old one expired
```

Verify: `aws sts get-caller-identity` should show account `273343380446`
(Netcentric AG PoC).

## 4. Rebuilding the Kind cluster + app

```bash
docker build -t modular-cicd-p:v1 docker/app
kind create cluster --name modular-cicd-pipeline
kind load docker-image modular-cicd-app:v1 --name modular-cicd-pipeline
kubectl apply -f k8s/base/
kubectl get pods   # expect 2/2 Running
```

## 5. Restarting Nexus (with the SAME data as before)

The volume `nexus-data` should still exist locally — this brings back your
exact repository config and admin password without redoing setup:

```bash
docker run -d -p 8081:8081 -p 8082:8082 --name nexus \
  -v nexus-data:/nexus-data sonatype/nexus3
```

If `docker volume ls | grep nexus` shows nothing (e.g. new machine), you'll
need to redo the Nexus setup wizard from `docs/SETUP.md`.

## 6. Restarting observability

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --set grafana.adminPassword=admin123
```

## 7. Ansible / EC2 sandbox — only if you want to  that demo

Requires recreating the SSH key pair (it was never stored anywhere except
`~/.ssh/modular-cicd-ansible.pem`, which does not survive a pause if that
file was deleted):
```bash
aws ec2 create-key-pair --key-name modular-cicd-ansible \
  --query 'KeyMaterial' --output text --region us-east-1 \
  > ~/.ssh/modular-cicd-ansible.pem
chmod 400 ~/.ssh/modular-cicd-ansible.pem
```
Then follow the Ansible section in `docs/SETUP.md` exactly — full sequence
is documented there (Terraform apply → Ansible playbook → verify → destroy).

## 8. Before ending any future session again

```bash
# If you created any EC2 via terraform-sandbox:
cd terraform-sandbox && terraform destroy

# Always confirm nothing is left:
aws ec2 describe-instances --region us-east-1 \
  --query "Reservations[].Instances[?State.Name!='terminated']" --output table
# Should be empty.

# Local cleanup (optional, no AWS cost either way):
kind delete cluster --name modular-cicd-pipeline
docker stop nexus && docker rm nexus   # keeps na volume
```

## 9. Where everything lives (quick index)

| What | Where |
|---|---|
| Full setup history, all commands run | `docs/SETUP.md` |
| Architecture decisions (ADRs) | `docs/decisions/` |
| Theoretical comparisons (e.g. Jenkins) | `docs/comparisons/` |
| Terraform (permanent) | `terraform/` |
| Terraform (throwaway/test) | `terraform-sandbox/` |
| App source + Dockerfile | `docker/app/` |
| Kubernetes manifests | `k8s/base/` |
| Ansible playbook | `ansible/install-docker.yml` |
| CI/CD workflow | `.github/workflows/docker-build.yml` |
