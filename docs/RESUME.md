# How to Resume This Project

This file is the single entry point for picking this project back up after
a long pause. Read this before touching anything else.

## 1. Current state (as of the pause)

**Everything was intentionally torn down to zero cost/risk — nothing exists
in AWS, nothing runs locally.** This includes the Terraform state bucket
itself, which was deliberately destroyed (not just emptied) before pausing.

- **AWS**: nothing. No S3 bucket, no EC2, no ECR, no IAM users beyond your
  own personal one.
- **Local (Mac)**: Docker daemon stopped, Kind cluster deleted, Nexus
  container removed. The Nexus **data volume** (`nexus-data`) was preserved
  if it still exists — check before assuming you need to redo Nexus setup
  from scratch.
- **GitHub**: everything up to date on `main`, all code and docs intact —
  only the AWS-side runtime state was torn down, not the project itself.

## 2. First thing to do when resuming: verify the above is still true

```b terraform && terraform state list && cd ..          # expect: empty
cd terraform-sandbox && terraform state list && cd ..   # expect: empty
aws s3 ls | grep dvi-modular-cicd-pipeline-tfstate       # expect: nothing
aws ec2 describe-instances --region us-east-1 \
  --query "Reservations[].Instances[?State.Name!='terminated']" --output table
docker ps -a
kind get clusters
docker volume ls | grep nexus
```

## 3. Rebuilding the local toolchain (if new machine or fresh macOS)

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

## 4. Rebuilding Terraform + the state bucket FROM ZEROThe bucket was fully destroyed, so this is a true from-scratch bootstrap —
not a resume of existing infra.

```bash
cd terraform
```

`provider.tf` and `backend-bootstrap.tf` are already in the repo (nothing
to rewrite). Start with **local state only** — do not add `backend.tf` yet:

```bash
terraform init
terraform plan     # expect: 4 resources to create (the S3 bucket + its 3 sub-resources)
terraform apply    # confirm with yes
```

Only after the bucket exists, recreate the remote backend config:
```bash
cat > backend.tf << 'BACKEND_EOF'
terraform {
  backend "s3" {
    bucket  = "dvi-modular-cicd-pipeline-tfstate"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
BACKEND_EOF

terraform init -migrate-state   # answer "yes" to copy local state into the new S3 backend
terraform plan                   # expect: "No changes"
```

**Lesson learned (do not repeat)**: this bucket has versioning enabled, so
if you ever want to destroy it again later, you must first empty Abject versions (not just current objects), or `terraform destroy` fails
with `BucketNotEmpty`:
```bash
aws s3api delete-objects --bucket dvi-modular-cicd-pipeline-tfstate \
  --delete "$(aws s3api list-object-versions --bucket dvi-modular-cicd-pipeline-tfstate \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"
```
Also unset the S3 backend (`mv backend.tf backend.tf.disabled && terraform
init -migrate-state`, answer yes) BEFORE destroying the bucket the state
itself lives in — otherwise Terraform can't destroy the backend it's
currently using.

## 5. Rebuilding the Kind cluster + app

```bash
docker build -t modular-cicd-app:v1 docker/app
kind create cluster --name modular-cicd-pipeline
kind load docker-image modular-cicd-app:v1 --name modular-cicd-pipeline
kubectl apply -f k8s/base/
kubectl get pods   # expect 2/2 Running
```

## 6. Restarting Nexus

Check first whether the data volume survived:
```bash
docker volume ls | grep nexus
```

If `nexus-data` still exists, this rtores your exact repository config
and admin password:
```bash
docker run -d -p 8081:8081 -p 8082:8082 --name nexus \
  -v nexus-data:/nexus-data sonatype/nexus3
```

If the volume is gone (e.g. new machine, or it was pruned), redo the full
Nexus setup wizard from `docs/SETUP.md`.

## 7. Restarting observability

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --set grafana.adminPassword=admin123
```

## 8. Ansible / EC2 sandbox — only if you want to redo that demo

The SSH key pair does not survive a pause (it only ever existed at
`~/.ssh/modular-cicd-ansible.pem`, never committed):
```bash
aws ec2 create-key-pair --key-name modular-cicd-ansible \
  --query 'KeyMaterial' --output text --region us-east-1 \
  > ~/.ssh/modular-cicd-ansible.pem
chmod 400 ~/.ssh/modular-cicd-ansible.pem
```
Then follow the Ansible secti in `docs/SETUP.md` exactly.

## 9. Before ending any future session again

```bash
# Destroy any sandbox EC2:
cd terraform-sandbox && terraform destroy

# Confirm nothing left in EC2:
aws ec2 describe-instances --region us-east-1 \
  --query "Reservations[].Instances[?State.Name!='terminated']" --output table

# Decide: keep the S3 state bucket running (negligible cost, convenient),
# or tear it down to zero again (see section 4's "Lesson learned" for the
# exact steps if you choose full teardown).

# Local cleanup (no AWS cost either way, just tidiness):
kind delete cluster --name modular-cicd-pipeline
docker stop nexus && docker rm nexus   # keeps nexus-data volume
```

## 10. Where everything lives (quick index)

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
