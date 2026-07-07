# AWS Secure Multi-Account Landing Zone

> **Built as a portfolio project** demonstrating AWS Control Tower, Organizations, Transit Gateway, multi-region DR, and CI/CD for IaC — aligned to Cloud Platform Engineer roles at Trianz, Leidos, Navy Federal, and BONbLOC.

![Landing Zone Architecture Diagram](./img/aws_architecture.png)

---

## Architecture Overview

```
┌─────────────────────────────────── AWS Organizations — Root OU ───────────────────────────────────-┐
│                                                                                                    │
│  ┌─────────────────┐     ┌─────────────────────────────────────┐     ┌───────────────────────┐     │
│  │ Management Acct │     │           Workloads OU              │     │     Security OU       │     │
│  │                 │     │  ┌──────────────┐  ┌─────────────┐  │     │  ┌─────────────────┐  │     │
│  │  Control Tower  │────▶│  │  Dev Account │  │ Prod Account│  │     │  │  Log Archive    │  │     │
│  │  Organizations  │     │  │  us-east-1   │  │  us-east-1  │  │     │  │  Audit Account  │  │     │
│  │  Transit GW     │     │  │  10.1.0.0/16 │  │ 10.2.0.0/16 │  │     │  └─────────────────┘  │     │
│  └─────────────────┘     │  └──────┬───────┘  └──────┬──────┘  │     └───────────────────────┘     │
│                          │         └────────┬────────┘         │                                   │
│                          └──────────────────┼──────────────────┘                                   │
│                                             ▼                                                      │
│                                   ┌──────────────────┐                                             │
│                                   │  Transit Gateway │◀── VPN / Direct Connect (simulated)         │
│                                   │  Hub-and-Spoke   │                                             │
│                                   └──────────────────┘                                             │
│                                                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │  DR Region (us-west-2) — Pilot Light Pattern                                                 │  │
│  │  DR VPC 10.3.0.0/16  │  AMI Pre-staged  │  ASG (min=0, desired=0)  │  RTO: 60min RPO: 15min  │  │
│  └──────────────────────────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────────────────────────-┘
```

---

## 7-Day Build Progress

This project was built over 7 days as a structured hands-on skill-gap sprint.
Each day's documentation includes step-by-step commands, errors encountered,
troubleshooting steps, and key takeaways for interviews.

| Day | Topic | Status | Documentation |
|-----|-------|--------|---------------|
| Day 1 | AWS Organizations + Root OU + SCPs | ✅ Complete | [docs/day1-organizations.md](./docs/day1-organizations.md) |
| Day 2 | AWS Control Tower + Account Factory + Guardrails | ✅ Complete | [docs/day2-control-tower.md](./docs/day2-control-tower.md) |
| Day 3 | Terraform VPCs + Cross-Account IAM Roles | 🔄 In Progress | [docs/day3-terraform-baseline.md](./docs/day3-terraform-baseline.md) |
| Day 4 | Transit Gateway — Hub-and-Spoke Networking | ⏳ Pending | [docs/day4-transit-gateway.md](./docs/day4-transit-gateway.md) |
| Day 5 | Multi-Region DR — Pilot Light Pattern | ⏳ Pending | [docs/day5-dr-pilot-light.md](./docs/day5-dr-pilot-light.md) |
| Day 6 | CloudWatch + SSM Monitoring Layer | ⏳ Pending | [docs/day6-monitoring.md](./docs/day6-monitoring.md) |
| Day 7 | CI/CD Pipeline + GitHub Portfolio Polish | ⏳ Pending | [docs/day7-cicd-pipeline.md](./docs/day7-cicd-pipeline.md) |

### Daily Highlights

<details>
<summary><strong>Day 1 — AWS Organizations + Root OU + SCPs</strong> ✅</summary>

**What was built:**
- Enabled AWS Organizations with All Features (unlocks SCPs)
- Created Root OU hierarchy: Security OU + Workloads OU
- Provisioned 3 member accounts using Gmail plus-addressing
- Wrote and attached `DenyExpensiveEC2` SCP to Workloads OU
- Initialized GitHub repo with SCP committed as JSON

**Key learning:** Organizations and Control Tower are not the same thing.
Organizations is the account management plane; Control Tower is the
governance layer built on top of it.

→ [Full Day 1 documentation](./docs/day1-organizations.md)
</details>

<details>
<summary><strong>Day 2 — AWS Control Tower + Account Factory + Guardrails</strong> ✅</summary>

**What was built:**
- Activated all member accounts (accepted AWS Customer Agreement)
- Enabled Control Tower Landing Zone in us-east-1 + us-west-2
- Log Archive and Audit accounts provisioned automatically
- Org-wide CloudTrail and AWS Config enabled across all accounts
- Enabled 2 optional guardrails: S3 public read prohibited + MFA required
- Vended Sandbox account via Account Factory with baseline auto-applied

**Errors encountered and resolved:**
- `AWSControlTowerExecution` role deployment failure — fixed by deleting
  failed StackSet instances from suspended accounts in Workloads OU
- `OptInRequired (403)` on member accounts — fixed by activating each
  account root user and accepting AWS Customer Agreement
- `Password recovery disabled` — caused by outstanding billing balance;
  resolved by using `OrganizationAccountAccessRole` Switch Role

→ [Full Day 2 documentation](./docs/day2-control-tower.md)
</details>

<details>
<summary><strong>Day 3 — Terraform VPCs + Cross-Account IAM Roles</strong> 🔄</summary>

**Planned:**
- Deploy Dev VPC (10.1.0.0/16) and Prod VPC (10.2.0.0/16) via Terraform
- Deploy DR VPC (10.3.0.0/16) in us-west-2
- Create `LandingZoneAdmin` cross-account IAM roles in each workload account
- Configure GitHub OIDC role (no static AWS keys in CI)

→ [Full Day 3 documentation](./docs/day3-terraform-baseline.md)
</details>

<details>
<summary><strong>Day 4 — Transit Gateway Hub-and-Spoke</strong> ⏳</summary>

**Planned:**
- Create Transit Gateway in Management account
- Share TGW to workload accounts via AWS RAM
- Attach Dev and Prod VPCs — confirm cross-account EC2 ping
- Configure Customer Gateway + Virtual Private Gateway (Direct Connect demo)

→ [Full Day 4 documentation](./docs/day4-transit-gateway.md)
</details>

<details>
<summary><strong>Day 5 — Multi-Region DR Pilot Light</strong> ⏳</summary>

**Planned:**
- Deploy DR VPC in us-west-2 with pre-staged AMI
- Configure ASG at min=0/desired=0 — scales on CloudWatch alarm
- Enable S3 Cross-Region Replication (RPO ≤15 min)
- Write DR runbook with RTO=60min, RPO=15min, failover + failback steps

→ [Full Day 5 documentation](./docs/day5-dr-pilot-light.md)
</details>

<details>
<summary><strong>Day 6 — CloudWatch + SSM Monitoring Layer</strong> ⏳</summary>

**Planned:**
- Cross-account CloudWatch log shipping to Log Archive account
- SSM Patch Manager baseline — Sunday 02:00 UTC maintenance window
- SSM Parameter Store for app config (SecureString)
- AWS Config managed rules — 4 compliance checks

→ [Full Day 6 documentation](./docs/day6-monitoring.md)
</details>

<details>
<summary><strong>Day 7 — CI/CD Pipeline + Portfolio Polish</strong> ⏳</summary>

**Planned:**
- GitHub Actions: `terraform fmt` + `validate` + `plan` on every push
- Plan output posted as PR comment via `github-script`
- GitHub OIDC role — no static AWS access keys in CI
- Final README polish + repo tagged v1.0

→ [Full Day 7 documentation](./docs/day7-cicd-pipeline.md)
</details>

---

## What's Inside

| Module | Path | Description |
|--------|------|-------------|
| Account Baseline | `/terraform/account-baseline/` | VPCs, subnets, IGW, cross-account IAM roles |
| Transit Gateway | `/terraform/transit-gateway/` | TGW, VPC attachments, route tables, VGW/CGW |
| Monitoring | `/terraform/monitoring/` | CloudWatch alarms, AWS Config rules, SSM Parameter Store |
| SCPs | `/scps/` | Service Control Policies — deny expensive EC2, restrict regions |
| Docs | `/docs/` | Day-by-day build logs, DR runbook, Control Tower setup notes |
| CI/CD | `/.github/workflows/` | Terraform validate + plan on every PR |

---

## Skills Demonstrated

- **AWS Control Tower** — Landing Zone setup, Account Factory, mandatory + optional guardrails
- **AWS Organizations** — Multi-account hierarchy, SCPs, OU structure
- **Transit Gateway** — Hub-and-spoke VPC routing, RAM sharing, VPN Gateway config
- **Multi-Region DR** — Pilot Light pattern, RTO/RPO definition, CloudWatch alarm → ASG trigger
- **Terraform IaC** — Modular, reusable, environment-parameterised infrastructure
- **GitHub Actions CI** — `fmt`, `validate`, `plan` on every push; plan output posted to PRs
- **CloudWatch + SSM** — Centralized log shipping, Patch Manager, Parameter Store, Config rules
- **IAM Governance** — Least-privilege cross-account roles, RBAC, compliance-aligned controls
- **Cost Governance** — SCPs blocking expensive services, Cost Anomaly Detection, billing runbook

---

## Repository Structure

```
aws-landing-zone/
│
├── .github/workflows/
│   ├── terraform-validate.yml   ← fmt + validate + plan on push/PR
│   └── terraform-apply.yml      ← manual apply with environment approval
│
├── terraform/
│   ├── account-baseline/
│   │   ├── main.tf              ← dual providers (dev + prod cross-account)
│   │   ├── vpc.tf               ← Dev VPC (10.1), Prod VPC (10.2), DR VPC (10.3)
│   │   ├── iam.tf               ← LandingZoneAdmin roles + GitHub OIDC role
│   │   ├── variables.tf         ← all inputs with validation rules
│   │   ├── outputs.tf           ← VPC IDs, subnet IDs passed to other modules
│   │   └── terraform.tfvars.example
│   │
│   ├── transit-gateway/
│   │   ├── main.tf              ← TGW, RAM share, VPC attachments, routes, VGW/CGW
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── monitoring/
│       ├── main.tf              ← providers + log shipping IAM role
│       ├── cloudwatch.tf        ← alarms, dashboard, DR ASG Pilot Light, SNS
│       ├── config-rules.tf      ← AWS Config recorder + 4 managed compliance rules
│       ├── ssm.tf               ← Patch Manager + maintenance window + Parameter Store
│       └── variables.tf
│
├── scps/
│   ├── deny-expensive-ec2.json         ← blocks anything above t3 family
│   ├── deny-non-approved-regions.json  ← restricts to us-east-1 + us-west-2 only
│   └── deny-expensive-services.json    ← blocks EKS, RDS, NAT Gateway
│
├── docs/
│   ├── day1-organizations.md       ← Day 1: Organizations + SCPs build log
│   ├── day2-control-tower.md       ← Day 2: Control Tower + Account Factory build log
│   ├── day3-terraform-baseline.md  ← Day 3: VPC + IAM Terraform modules
│   ├── day4-transit-gateway.md     ← Day 4: Transit Gateway networking
│   ├── day5-dr-pilot-light.md      ← Day 5: Multi-region DR build log
│   ├── day6-monitoring.md          ← Day 6: CloudWatch + SSM monitoring
│   ├── day7-cicd-pipeline.md       ← Day 7: GitHub Actions CI/CD
│   ├── dr-runbook.md               ← Full DR failover + failback procedure
│   ├── control-tower-setup.md      ← Control Tower reference notes
│   └── cost-optimization.md        ← AWS cost governance + billing runbook
│
├── img/
│   └── aws_architecture.png        ← Full architecture diagram
│
├── .gitignore
└── README.md
```

---

## Prerequisites

- AWS Free Tier account (Management account)
- 3 additional AWS member accounts (created free via Organizations)
- Terraform >= 1.6.0
- AWS CLI v2 configured with named profile

---

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/aws-landing-zone.git
cd aws-landing-zone

# Deploy account baseline (Dev VPC)
cd terraform/account-baseline
cp terraform.tfvars.example terraform.tfvars   # fill in your account IDs
terraform init
terraform plan
terraform apply

# Deploy Transit Gateway
cd ../transit-gateway
terraform init && terraform apply

# Deploy monitoring layer
cd ../monitoring
terraform init && terraform apply
```

---

## What I Learned

This 7-day project was built as part of a structured skill-gap sprint targeting
Cloud Platform Engineer roles. Key takeaways:

1. **Control Tower + Organizations are not the same thing** — Organizations is
   the account management plane; Control Tower is the governance layer on top
   of it that adds guardrails, Account Factory, and centralized logging by default.

2. **Non-overlapping CIDRs matter** — Transit Gateway routing breaks silently if
   VPC CIDRs overlap. Planning the IP space upfront (10.1, 10.2, 10.3 per
   environment) is a production requirement.

3. **DR is a runbook, not just infrastructure** — The Pilot Light ASG is useless
   without a tested failover procedure. RTO/RPO targets must be defined before
   the architecture, not after.

4. **SSM Parameter Store replaces hardcoded config** — Referencing SSM params in
   Terraform via `data "aws_ssm_parameter"` is the clean pattern for
   secrets/config separation.

5. **Multi-region resource awareness is critical** — Resources can exist in any
   AWS region. A billing incident during this project revealed team project
   resources in us-east-2 that were missed in initial cleanup sweeps. Always
   scan all regions.

6. **SCPs are the last line of defense** — IAM policies can be misconfigured by
   individual teams. SCPs at the OU level enforce guardrails that no account
   admin can override — essential for cost control and compliance in
   multi-account environments.

---

## Cost

**~$0.64/month** on AWS Free Tier. All EC2 instances used for testing are
t3.micro and terminated after validation. The only ongoing charge is a stopped
CTF Lab EC2 instance used for separate Linux training (8GB EBS volume).

See [docs/cost-optimization.md](./docs/cost-optimization.md) for the full
cost governance runbook including billing incident post-mortem, cleanup
commands, and preventive SCPs.

---

## License

MIT — feel free to fork and adapt for your own landing zone builds.
