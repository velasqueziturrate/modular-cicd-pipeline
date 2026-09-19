# Comparison: Jenkins vs. GitHub Actions

## Summary

| Criterion | GitHub Actions | Jenkins |
|---|---|---|
| Hosting | Managed by GitHub, zero infrastructure to maintain | Self-hosted — requires a server/container to run the controller |
| Cost | Free for public repos (used in this project) | Free software, but requires paying for/maintaining the host it runs on |
| Setup time | Minutes — YAML file in `.github/workflows/`, no separate install | Hours — install, configure plugins, secure the instance, manage upgrades |
| Native integration | Built into GitHub (PRs, checks, secrets) | Requires webhooks/plugins to integrate with GitHub |
| Plugin ecosystem | Marketplace of reusable Actions, generally simpler | Very large, mature plugin ecosystem — often necessary for complex enterprise pipelines (Nexus, SonarQube, ServiceNow integrations, etc.) |
| Enterprise fit | Strong for cloud-native teams already on GitHub | Still widely used ined/on-prem enterprises (banking, insurance) that require full control over the CI server, audit logs, and network isolation |
| Scaling / self-hosted runners | Possible (self-hosted runners) but less common | Common — Jenkins agents are a mature, well-understood scaling pattern |

## Decision for this project

**GitHub Actions** was used for the implemented CI/CD pipeline
(`.github/workflows/docker-build.yml`), because:
- The project is hosted on GitHub already — no separate CI infrastructure needed
- Free for public repositories, keeping the cost-control principle of this project intact
- Faster to iterate on for a solo portfolio project

**Jenkins was not implemented**, but is documented here rather than silently
dropped, because it remains highly relevant in the type of enterprise
environment this project's tagging convention alludes to (`Project=Swedbank`).
Regulated organizations — banking especially — frequently still run Jenkins
on-premises or in a controlled private network, for reasons incl Full control over where build agents run (data residency, network isolation)
- Long-standing investment in Jenkins pipelines, plugins, and institutional knowledge
- Audit and compliance requirements that are easier to satisfy with a
  self-hosted, fully-controlled CI server

## What would change with Jenkins

If this project used Jenkins instead, the practical differences would be:
- A `Jenkinsfile` (Groovy-based pipeline-as-code) would replace `docker-build.yml`
- A Jenkins controller would need to run somewhere — likely as a Docker
  container locally (mirroring the approach already used for Nexus in this
  project), or on a dedicated EC2 instance if persistence beyond a single
  session were required
- Docker-in-Docker or a mounted Docker socket would be needed for the
  Jenkins agent to build images, adding operational complexity absent in
  GitHub Actions' hosted runners

## Conclusion

This is the same class of trade-off as Nexus vs. ECR (ADR 003): the
"better" choice depends on organizational contt, not on which tool is
objectively superior. GitHub Actions fits this project's constraints
(cost, solo maintenance, already-hosted-on-GitHub); Jenkins would fit
better in a regulated enterprise with existing on-prem CI investment.
