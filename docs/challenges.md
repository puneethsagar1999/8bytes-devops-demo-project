# Challenges faced and how they were resolved

## Terraform and state

| # | Problem | Root cause | Resolution |
|---|---|---|---|
| 1 | `terraform init` failed: the S3 bucket does not exist | A backend bucket must exist before Terraform can use it | Created it first with `scripts/create-state-bucket.sh`. Made the script idempotent and used a partial backend configuration so the bucket name is a `-backend-config` flag |
| 2 | Invalid CIDR error on the Jenkins security group | A placeholder value was left in `terraform.tfvars` | Used the real address and checked for leftovers with `grep` |
| 3 | The CIDR was still rejected | `curl ifconfig.me` returned an IPv6 address, and the rule needs IPv4 | Used `curl -4 ifconfig.me` |
| 4 | PostgreSQL exporter release failed with "chart version not found" | The version field still held a placeholder | Looked up the real chart version with `helm search repo` and pinned it |
| 5 | EKS access policy association returned 404 | It was created in parallel with the access entry it depends on | Referenced the access entry's own attributes to create an explicit dependency |
| 6 | Terraform commands failed with `SignatureDoesNotMatch` | The VM clock had drifted by more than 5 minutes | Re-enabled NTP sync (`timedatectl set-ntp true`) |
| 7 | `terraform destroy` stuck on the internet gateway and subnets | Load balancers created by the controller from the Ingresses were not in Terraform state, and their network interfaces and public addresses blocked deletion | Deleted the ALBs and leftover `k8s-` security groups manually, then destroyed again. Documented the correct order: uninstall the app releases first |

## Containers and the application

| # | Problem | Root cause | Resolution |
|---|---|---|---|
| 8 | Pulling a public image failed with "authentication required" | An expired Docker Hub login was saved on the machine | `docker logout` |
| 9 | Docker build failed on line 1 of the Dockerfile | The wrong content (a Python test file) had been saved into it | Rewrote the file and checked the first lines of every file |
| 10 | The local container was unreachable | Port 8080 was already used by another Jenkins on the same VM | Published the container on port 8090 |
| 11 | `docker build` rejected the tag `:v1` | The `ECR_URL` shell variable was empty in that terminal | Exported it explicitly and verified it with `echo` |
| 12 | ECR push: "no basic auth credentials" | Docker was not logged in to ECR | `aws ecr get-login-password` piped into `docker login` |
| 13 | Pods stuck in `InvalidImageName` | Helm received an empty image repository | Passed the full repository and later moved the values into files |
| 14 | Creating the database secret failed | The secret ARN contains `!`, which bash treated as history expansion, and the host included the port | Quoted the ARN with single quotes and used the host name only |
| 15 | Permission denied when running a helper script | File ownership and permissions on the script | Fixed ownership, and ran the steps directly |

## Monitoring and logging

| # | Problem | Root cause | Resolution |
|---|---|---|---|
| 16 | A Prometheus query returned nothing | The metric name was mistyped (`http_request_total` instead of `http_requests_total`) | Used autocomplete and the correct name |
| 17 | The route label looked wrong in queries | The ServiceMonitor adds its own `endpoint` label, so the app's label is exposed as `exported_endpoint` | Used `exported_endpoint` in the dashboards |
| 18 | Loki "log volume" error in Grafana | The Loki version in the chart is older than the Grafana query | Harmless, logs still work. Noted as a limitation |
| 19 | Database panels were empty | The exporter had never been installed (see #4) | Fixed the chart version, applied, and confirmed `pg_up` equals 1 |

## Jenkins CI/CD

| # | Problem | Root cause | Resolution |
|---|---|---|---|
| 20 | Pipeline failed: permission denied on the Docker socket | `apt install jenkins` starts the service before the script adds the user to the `docker` group, and a running process keeps its old groups | Restarted Jenkins. Fixed the install script so it restarts after the group change |
| 21 | Dependency scan failed the build | `pip-audit` found known vulnerabilities in Flask 3.1.0 | Upgraded to Flask 3.1.3. The gate worked as intended |
| 22 | Deploy failed with "cluster unreachable, i/o timeout" | From inside the VPC the cluster endpoint resolves to private addresses, and the cluster security group did not allow the Jenkins server | Added a security group rule from the Jenkins group to the cluster group on port 443 |
| 23 | Failure emails were not sent | Gmail needs an App Password, SSL on port 465 (port 25 is blocked on AWS), and the Extended E-mail settings | Created an App Password, configured SMTP correctly and tested it from the server |
| 24 | Production approval seemed stuck | The console view did not refresh after clicking Deploy | Reloaded the page and used the build's input page |
| 25 | Builds did not start by themselves at first | The multibranch scan trigger was not set | Enabled "Periodically if not otherwise run" with a 1 minute interval |

## Lessons learned
- Check shell variables with `echo` before using them. Many errors came from empty values.
- Read the first error in a log. Later errors are often caused by it.
- Security scans block builds for real reasons. Fix the cause instead of loosening the gate.
- A running service does not pick up new group membership until it restarts.
- Two resources that depend on each other must reference each other, or Terraform may create them in the wrong order.
- Resources created by controllers inside the cluster (such as load balancers) must be removed before the infrastructure that holds them.
- Keep placeholders out of committed configuration, and search for them before applying.

## 6. Next steps if this were a long-lived system
Separate environments, HTTPS, external secrets, Multi-AZ database, persistent monitoring storage, build agents and a pipeline for Terraform changes.