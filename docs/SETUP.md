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