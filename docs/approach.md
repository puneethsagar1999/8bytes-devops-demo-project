# Approach

## 1. Objective
Provision a cloud environment for a small web application, automate its build and deployment, make it observable, and document it so another engineer can reproduce it.

## 2. How I built it, in order
1. **State first.** A script creates a versioned, encrypted S3 bucket. Terraform uses it as its backend with native locking.
2. **Network.** VPC with public subnets (load balancers, NAT, Jenkins) and private subnets (nodes, database).
3. **Cluster.** EKS with a managed node group, plus access entries for the cluster creator.
4. **Data and registry.** RDS PostgreSQL in private subnets with an RDS-managed secret, and an ECR repository.
5. **Load balancing.** The AWS Load Balancer Controller, installed by Terraform with an IRSA role.
6. **Application.** A small Flask app with `/health`, `/ready`, `/metrics` and a PostgreSQL-backed API, plus unit and integration tests and a Dockerfile.
7. **Manual deployment first.** A Helm chart deployed by hand to prove the image, secret, database connection and ALB worked.
8. **Observability.** Prometheus, Grafana, Loki, Promtail and a PostgreSQL exporter, then two dashboards.
9. **CI/CD.** Jenkins on EC2 with a Multibranch Pipeline that automates what I had proven by hand.
10. **Documentation and clean-up.**

I built the deployment manually before automating it, so that a failure in the pipeline could be separated from a failure in the application.

## 3. Key decisions and alternatives

| Area | Chosen | Alternative | Why |
|---|---|---|---|
| Hosting | EKS | ECS Fargate, EC2 | Standard Kubernetes tooling, Helm, and ecosystem for monitoring |
| IaC structure | Modules and an environment folder | One flat configuration | Reuse, and a second environment becomes a new folder |
| CI/CD | Jenkins | GitHub Actions | Self-managed server shows the full pipeline and IAM design |
| PR and branch builds | Multibranch Pipeline | Separate jobs | One `Jenkinsfile`, automatic PR discovery |
| Deployment | Helm from the pipeline | GitOps (Argo CD) | Smaller moving parts for this scope |
| Environments | Namespaces in one cluster | Two clusters | Cost |
| Secrets | RDS-managed password, copied into Kubernetes | External secrets operator | Simplicity, documented as a trade-off |
| Server access | Session Manager | SSH keys | No open port and no key to manage |
| AWS credentials | Instance role and IRSA | Access keys | No long-lived keys |
| Webhook | Polling every minute | GitHub webhook | No inbound path needed |
| Logging | Loki and Promtail | CloudWatch Logs | Same Grafana for metrics and logs |

## 4. How each part was validated

| Part | Validation |
|---|---|
| Terraform | `terraform validate`, `plan` reviewed, then `apply` in phases |
| Network and database | Pods became Ready only when `/ready` (a database query) succeeded |
| Load balancer | ALB address answered on `/`, `/health`, `/ready`, `/api/notes` |
| Pipeline | PR run executes tests and scans only. `main` run goes through to approval and production |
| Security gates | A real finding in Flask 3.1.0 failed the dependency scan and was fixed by upgrading |
| Metrics | Prometheus targets page shows all targets UP, `pg_up` equals 1 |
| Logs | `{namespace="staging"}` returns application logs in Grafana |
| Dashboards | Both dashboards show live data after generating traffic |

## 5. Assumptions and limitations
- One AWS account and region (`us-east-1`).
- The environment is short-lived and destroyed after review, so some production safeguards are intentionally off (see section 12 of the README).
- Staging and production share a database and a cluster to control cost.