# ADR 001: AWS Region Selection

## Status
Accepted

## Context
The project needs a primary AWS region for all resources. Since this is a
learning/portfolio project (not a production workload with real users),
region selection criteria differ from a real client engagement.

## Options considered

| Region | Pros | Cons |
|---|---|---|
| `us-east-1` (N. Virginia) | Lowest cost, most services available first, most tutorials/docs assume this region | Higher latency from Europe |
| `eu-west-1` (Ireland) | Low latency for EU-based usage, most mature EU region, realistic for a European client context | Slightly higher cost on some services |
| `eu-south-2` (Spain) | Lowest latency (closest to Madrid) | Newer region, fewer services available |

## Decision
`us-east-1` was selected, prioritizing **cost minimization** over latency,
since this project's purpose is hands-on practice rather than serving real
end users. Latency is not a meaningful concern for this use case.

## Consequences
- Lower AWS costs during development
- Slightly higher latency when testing interactively from Madrid — acceptable trade-off given the project's purpose
- In a real client engagement (e.g. banking sector, EU-based users), `eu-west-1` would be the more defensible choice due to data residency and latency considerations — this trade-off is explicitly acknowledged here to demonstrate awareness of the decision, not just its outcome
