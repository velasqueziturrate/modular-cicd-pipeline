
denied: User: arn:aws:iam::273343380446:user/github-actions-ecr-push is not
authorized to perform: ecr:GetDownloadUrlForLayer on resource: ... with an
explicit deny in a service control policy: arn:aws:organizations::.../p-u4gij31a





This is an **explicit deny from an AWS Organizations Service Control Policy

(SCP)**, applied at the organizational level of the shared Netcentric AWS

account. SCPs orride any IAM permission granted within the account,

regardless of how narrowly scoped — there is no IAM-level workaround.

The scope of the restriction was verified directly: read actions remain

permitted (`aws ecr describe-repositories` succeeds), while write actions

(`PutImage`, `GetDownloadUrlForLayer`, layer upload) are explicitly denied.

This is consistent with a deliberate governance pattern — common in

regulated industries — that prevents saPoC accounts from publishing

container images, while still allowing visibility into existing registries.

Confirmed with the account owner that this restriction is organizational

policy and will not be exempted for this use case.

## Decision

Use **Nexus Repository** (self-hosted, running as a Docker container) as

the container registry for this project, instead of ECR.

The ECR implementation (Terraform resources, IAM user, GitHub Actions

integration) was fully built and verified to fail only at the

organizational policy layer — not due to any misconfiguration. This is

preserved in git history as evidence of the intended alternative and the

diagnostic process that led to the pivot.

## Consequences

- Nexus runs locally/self-hosted, with no dependency on AWS account

  permissions or organizational policy — avoids the blocker entirely.

- In a real (non-shared, non-restricted) AWS account, ECR would likely be

  the simpler and lower-maintenance choice, since it requires no

  self-hosted infracture.

- This decision demonstrates a realistic constraint often faced in

  enterprise environments: cloud governance policies (SCPs, guardrails)

  can override an engineer's technical design regardless of how

  well-scoped the implementation is. Diagnosing the exact scope of a

  restriction (read vs. write) before abandoning an approach, and

  adapting the architecture accordingly, is itself part of the

  engineering judgment this project aims to demonstrate.

- The now-unused ECR and IAM Terraform resources were destroyed via

  `terraform destroy -target=...` to avoid leaving orphaned infrastructure.

## Update: Nexus network reachability from CI/CD

After pivoting to Nexus, a further constraint was identified: **GitHub
Actions runners cannot reach `localhost` on the developer's machine.**
GitHub-hosted runners execute in GitHub's cloud infrastructure, isolated
from any local network — they have no route to a Nexus instance running
on a laptop.

This is a fundamentally different trade-off than the ECR SCP block:
- The **ECR block** was a deliberate governance restriction (fixable only
  by changing organizational policy).
- The **Nexus reachability issue** is a topology/networking constraint of
  this practice environment specifically. In a real deployment, Nexus
  would run on infrastructure with a stable, reachable address (an
  internal server, a VPN-accessible host, or a cloud VM) — at which point
  automated push from CI would work exactly like it would with ECR.

**Resolution for this project**: the CI/CD pipeline automates the Docker
**build and validation** step (`docker build`, cached via GitHub Actions).
The **push to Nexus** is performed manually/locally, with this limitation
explicitly documented here rather than worked around with unnecessary
complexity (e.g. tunneling tools like ngrok) that wouldn't reflect a
realistic production setup.
