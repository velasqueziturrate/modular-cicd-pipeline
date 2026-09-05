# Project Setup

## Repository

- Name: `modular-cicd-pipeline`

- Owner: `velasqueziturrate`

- URL: github.com/velasqueziturrate/modular-cicd-pipeline

- Visibility: Public

- `.gitignore`: Terraform template (protects `.tfstate` and `.terraform/`)

## Documentation language

- All project documentation (ADRs, comparisons, README, code comments) is written in English

- Conversational/planning discussion (with Claude) stays in Spanish — only committed artifacts are English

## Project structure

```bash

mkdir -p terraform/modules

mkdir -p docker/app

mkdir -p registry/nexus registry/ecr

mkdir -p k8s/base k8s/overlays

mkdir -p ansible

mkdir -p .github/workflows

mkdir -p jenkins

mkdir -p monitoring/prometheus monitoring/grafana

mkdir -p docs/decisions docs/comparisons

# Track empty folders in Git

find . -type d -empty -not -path "./.git*" -exec touch {}/.gitkeep \;

```

## Development environment

- Personal projects use **Cursor** (separate installation from work VS Code) to keep personal and work GitHub accounts fully isolated

- Work VS Code remains untouched, still logged in with the work GitHub account

- Git identity is scoped locally per repo (not global), so commits in this project are attributed correctly:

```bash

  git config [user.name](http://user.name) "Daniel Velasquez"

  git config [user.email](http://user.email) "[velasqueziturrate@gmail.com](mailto:velasqueziturrate@gmail.com)"

```

## Git authentication (HTTPS, personal account)

- Root cause of push failures: a **system-level** `credential.helper=osxkeychain`

  (defined in `/opt/homebrew/etc/gitconfig`, not in the user's global config)

  was intercepting authentication with the cached **work** GitHub account,

  even from a separate editor (Cursor) and a separate local git identity.

- Resolved **without modifying any config** (system, global, or Keychain):

```bash

  git -c credential.helper= push

```

  This bypasses the credential helper for a single command only, prompting

  for personal credentials (username + Personal Access Token) directly in

  the terminal.

- Personal Access Token (classic): `repo` scope only, 90-day expiration.

- No changes were made to the work environment — VS Code, Swedbank repos,

  and the work GitHub session are unaffected.

- A branch divergence (local vs. remote README, created when GitHub's

  auto-generated README conflicted with the local one) was resolved with:

```bash

  git commit -m "merge: resolve README divergence"

  git push

```

## AWS tagging convention

Per Valdas's instructions (shared corporate AWS account, Netcentric AG PoC) —

`Project` refers to the client/engagement context of the shared account:

Project = Swedbank  
Owner = daniel.velasquez  
Environment = dev  
ManagedBy = terraform

Applied automatically to all resources via Terraform provider `default_tags` —

no need to repeat tags per resource. Resources must be destroyed via

Terraform `terraform destroy`) once no longer needed.

## Terraform initialization

`terraform/provider.tf`:

```hcl

terraform {

  required_providers {

    aws = {

      source  = "hashicorp/aws"

      version = "~> 5.0"

    }

  }

}

provider "aws" {

  region = "us-east-1"

  default_tags {

    tags = {

      Project     = "Swedbank"

      Owner       = "daniel.velasquez"

      Environment = "dev"

      ManagedBy   = "terraform"

    }

  }

}

```

⏳ Pending: `terraform init` and `terraform plan` (requires AWS CLI credentials configured — see below)

## Local tools (macOS + Homebrew)

✅ **Installed**

```bash

# Docker Desktop (already installed prior to this project)

docker --version        # Docker version 29.6.2

# AWS CLI

brew install awscli

aws --version            # aws-cli/2.36.24

# kubectl

brew install kubectl

kubectl version --client # v1.36.1

# Kind

brew install kind

kind --version            # 0.32.0

# Helm

brew install helm

helm version              # v4.2.4

```

| Tool | Version | Purpose |

|---|---|---|

| Docker Desktop | 29.6.2 | Containers, image builds |

| AWS CLI | 2.36.24 | AWS authentication and resource management |

| Terraform | (installed) | IaC — AWS infrastructure provisioning |

| kubectl | v1.36.1 | Kubernetes cluster client |

| Kind | 0.32.0 | Local Kubernetes (avoids EKS cost in dev) |

| Helm | v4.2.4 | K8s package manager (Prometheus, Grafana) |

⏳ Pending: `aws configure` with Netcentric account credentials

### Deferred to later phases

- Jenkins → will run as a Docker container (CI/CD phase)

- Prometheus/Grafana → will be installed via Helm chart inside the Kind cluster (observability phase)

## AWS region

`us-east-1` selected for cost optimization (this is a learning/portfolio
project, not a latency-sensitive production workload). Full trade-off
analysis in [`docs/decisions/001-region-selection.md`](./decisions/001-region-selection.md).

## AWS CLI configuration

```bash
aws configure
# AWS Access Key ID: [personal access key, created via IAM > Users > daniel.velasquez > Security credentials]
# AWS Secret Access Key: [secret, shown once at creation]
# Default region name: us-east-1
# Default output format: json
```

Verified with:
```bash
aws sts get-caller-identity
```

```json
{
    "UserId": "AIDAT7JEI7PPEPM7Y5QYJ",
    "Account": "273343380446",
    "Arn": "arn:aws:iam::273343380446:user/daniel.velasquez"
}
```

✅ Confirmed connection to Netcentric AG PoC Account.

Verified:
```bash
terraform init   # downloaded hashicorp/aws v5.100.0
terraform plan   # "No changes. Your infrastructure matches the configuration."
```

✅ Terraform successfully connected to AWS, no resources created yet.

 Note: AWS automatically tags the access key's description onto the IAM
user (tag key = access key ID, value = description text). This is
AWS's default behavior for key descriptions, unrelated to the project's
`Project=Swedbank` tagging convention applied via Terraform.

## Terraform remote state

First real AWS resource created: S3 bucket for Terraform state storage.

`terraform/backend-bootstrap.tf` — creates the bucket with:
- Versioning enabled
- Server-side encryption (AES256)
- Public access fully blocked

```bash
terraform apply   # created: aws_s3_bucket, aws_s3_bucket_versioning,
                   # aws_s3_bucket_server_side_encryption_configuration,
                   # aws_s3_bucket_public_access_block
```

Bucket name: `dvi-modular-cicd-pipeline-tfstate`

`terraform/backend.tf` — configures Terraform to use this bucket as
remote backend:

```bash
terraform init   # migrated local state to S3 backend (confirmed with "yes")
terraform plan   # "No changes" — state successfully synced
```

✅ This is the only resource kept running permanently between sessions
(negligible cost — empty bucket, minimal storage). All other resources
(EC2, etc.) will be destroyed via `terraform destroy` at the end of each
working session.

## Docker containerization

Simple Flask app with 3 endpoints (`/`, `/health`, `/info`) — the `/health`
endpoint will be used later as a Kubernetes liveness probe.

```bash
cd docker/app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Note: macOS blocks system-wide pip installs (PEP 668), hence the virtual
environment. `venv/` is excluded via `.gitignore`.

Local dev server tested on port 8080 (5000 conflicts with macOS AirPlay
Receiver).

```bash
docker build -t modular-cicd-app:v1 .
docker run -d -p 8080:8080 --name modular-cicd-test modular-cicd-app:v1
curl http://localhost:8080/health   # {"status":"healthy"}
```

✅ Verified: containerized app responds correctly on all 3 endpoints.


## Kubernetes (Kind)

```bash
kind create cluster --name modular-cicd-pipeline
kubectl get nodes   # 1 node, Ready

kind load docker-image modular-cicd-app:v1 --name modular-cicd-pipeline
kubectl apply -f k8s/base/deployment.yaml
kubectl apply -f k8s/base/service.yaml
```

- Deployment: 2 replicas, `imagePullPolicy: Never` (uses locally loaded image, no registry needed yet)
- Liveness/readiness probes wired to the `/health` endpoint
- Service type: NodePort

Verified via:
```bash
kubectl get pods   # 2/2 Running
kubectl port-forward service/modular-cicd-app-service 8081:80
curl http://localhost:8081/health   # {"status":"healthy"}
```

Note: `port-forward` pins to a single pod for the life of the connection,
so it doesn't demonstrate Service load-balancing directly — that's expected
behavior, not a bug.

## CI/CD (GitHub Actions)

`.github/workflows/docker-build.yml` — builds the Docker image on every
push/PR that touches `docker/app/**`, using GitHub's build cache for
speed. Currently validates the build only (`push: false`) — pushing to
a registry (Nexus vs. ECR) is a future step.

✅ Verified: workflow runs automatically on push, build passes (green check).

Note: initial workflow file was accidentally created in the repo root
instead of `.github/workflows/` due to a failed `cd` into a non-existent
directory — GitHub Actions only detects workflows in that exact path.
Fixed by moving the file with `git mv`.



## Container registry: ECR attempt and pivot to Nexus

Initially attempted **ECR** as the container registry, integrated with the

existing CI/CD pipeline:

```bash

# terraform/ecr.tf — created the ECR repository

terraform apply   # created aws_ecr_repository, aws_ecr_lifecycle_policy

# terraform/iam-github-actions.tf — dedicated IAM user for GitHub Actions,

# least-privilege policy scoped to a single repository (push/pull only,

# no admin actions)

terraform apply   # created aws_iam_user, aws_iam_access_key, aws_iam_user_policy

# Credentials added as GitHub Secrets:

# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

```

GitHub Actions workflow was updated to authenticate against AWS and push

to ECR on every push to `main`.

**Result: push denied.**

denied: User: arn:aws:iam::273343380446:user/github-actions-ecr-push is not
authorized to perform: ecr:GetDownloadUrlForLayer ... with an explicit deny
in a service control policy: arn:aws:organizations::.../p-u4gij31a



This is an **AWS Organizations Service Control Policy (SCP)** — a

restriction above the account/IAM level, applied by Netcentric's

organizational governance. No IAM policy, regardless of scope, can

override an SCP explicit deny.

Diagnosed the exact scope before abandoning ECR:

```bash

aws ecr describe-repositories --region us-east-1   # ✅ succeeds (read allowed)

# push (PutImage, GetDownloadUrlForLayer, etc.)      # ❌ denied (write blocked)

```

Confirmed with the account owner this is deliberate organizational policy,

not an oversight, and won't be exempted for this use case.

**Decision**: pivot to **Nexus** (self-hosted, no AWS account dependency).

Full reasoning in [`docs/decisions/003-nexus-vs-ecr.md`](./decisions/003-nexus-vs-ecr.md).

Cleanup performed:

```bash

terraform destroy -target=aws_ecr_repository.modular_cicd_app \

  -target=aws_ecr_lifecycle_policy.modular_cicd_app \

  -target=aws_iam_user.github_actions \

  -target=aws_iam_access_key.github_actions \

  -target=aws_iam_user_policy.ecr_push

rm terraform/ecr.tf terraform/iam-github-actions.tf

# GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) removed manually

# Workflow reverted to build-only (push: false)

```

✅ Verified clean: `terraform plan` shows `No changes` — no orphaned resources.


## Nexus: lesson learned on persistent volumes

Initial Nexus container was created without a Docker volume and without
the Docker-protocol port (8082) exposed:
```bash
docker run -d -p 8081:8081 --name nexus sonatype/nexus3
```

Docker port mappings can only be set at container creation — they cannot
be added to a running container. Since port 8082 (required for the Docker
registry protocol) was missing, the container had to be destroyed and
recreated with the correct port mapping.

Because no volume was attached, all Nexus configuration (admin password,
repository setup) was stored only inside the container's writable layer
and was lost on removal — requiring the initial setup wizard to be
repeated from scratch.

**Fix**: recreate with both required ports and a named volume for
persistent data:
```bash
docker run -d -p 8081:8081 -p 8082:8082 --name nexus \
  -v nexus-data:/nexus-data sonatype/nexus3
```

This mirrors the same principle applied in ADR 002 (Terraform): separate
ephemeral infrastructure (the container itself, disposable) from
persistent state (configuration data, which must survive container
recreation).


## Observability (Prometheus + Grafana via Helm)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123
```

Deployed via the `kube-prometheus-stack` Helm chart, which bundles
Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics
into a single install — the standard approach for Kubernetes monitoring.

```bash
kubectl get pods -n monitoring   # all components Running
```

Access Grafana:
```bash
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
# http://localhost:3000, admin / admin123
```

✅ Verified: Grafana loads with pre-built dashboards (Kubernetes Compute
Resources, API server, CoreDNS, etcd, Alertmanager Overview) — no manual
dashboard creation needed for baseline cluster observability.

Note: `admin123` is a throwaway password for this local, non-exposed
environment only.