# ADR 002: Separate Permanent and Ephemeral Resources into Different Terraform States
## Status
Accepted
## Context
Initially, the Terraform remote state bucket (backend-bootstrap.tf) and a
temporary EC2 test instance (ec2-test.tf) were defined in the same
directory, sharing a single Terraform state.
Running terraform destroy to tear down the EC2 test instance also
targeted the S3 bucket used for remote state storage, since both were
managed under the same state. The bucket itself survived only because AWS
blocked the deletion (BucketNotEmpty, due to versioning), but its
sub-resources (versioning, encryption, public access block) were destroyed
and had to be recreated.
## Decision
Permanent infrastructure (e.g. the Terraform state bucket) and ephemeral/
test infrastructure (e.g. throwaway EC2 instances) are now kept in
**separate directories with independent Terraform states**:
- terraform/ — permanent infrastructure oy (state bucket, and future
  long-lived resources). terraform destroy here should be treated as
  a rare, deliberate action.
- terraform-sandbox/ — ephemeral/test resources, safe to apply and
  destroy freely without risk to permanent infrastructure.
## Consequences
- Eliminates the risk of an unintended destroy affecting critical,
  long-lived infrastructure.
- Requires running Terraform commands from the correct directory,
  depending on intent (permanent vs. throwaway).
- Reinforces a core project principle: infrastructure changes must be
  reviewable (terraform plan) and scoped narrowly enough that a mistake
  in one area cannot cascade into another.
