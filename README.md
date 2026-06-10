# AWS Secure Multi-Account Landing Zone

> **Built as a portfolio project** demonstrating AWS Control Tower, Organizations, Transit Gateway, multi-region DR, and CI/CD for IaC — aligned to Cloud Platform Engineer roles at Trianz, Leidos, Navy Federal, and BONbLOC.

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

## What's Inside

| Module | Path | Description |
|--------|------|-------------|
| Account Baseline | `/terraform/account-baseline/` | VPCs, subnets, IGW, cross-account IAM roles |
| Transit Gateway | `/terraform/transit-gateway/` | TGW, VPC attachments, route tables, VGW/CGW |
| Monitoring | `/terraform/monitoring/` | CloudWatch alarms, AWS Config rules, SSM Parameter Store |
| SCPs | `/scps/` | Service Control Policies — deny expensive EC2, restrict regions |
| Docs | `/docs/` | DR runbook, Control Tower setup notes, monitoring guide |
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

---

## Prerequisites

- AWS Free Tier account (Management account)
- 3 additional AWS member accounts (created free via Organizations)
- Terraform >= 1.6.0
- AWS CLI v2 configured

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

## Repository Structure

```
aws-landing-zone/
│
├── .github/workflows/
│   ├── terraform-validate.yml   ← fmt + validate + plan on push/PR; posts plan to PR comments
│   └── terraform-apply.yml      ← manual workflow_dispatch apply (requires env approval)
│
├── terraform/
│   ├── account-baseline/
│   │   ├── main.tf              ← dual providers (dev + prod cross-account)
│   │   ├── vpc.tf               ← Dev VPC (10.1), Prod VPC (10.2), DR VPC (10.3)
│   │   ├── iam.tf               ← LandingZoneAdmin cross-account roles + GitHub OIDC role
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
│       ├── ssm.tf               ← Patch Manager baseline + maintenance window + Parameter Store
│       └── variables.tf
│
├── scps/
│   ├── deny-expensive-ec2.json         ← blocks anything above t3 family
│   └── deny-non-approved-regions.json  ← restricts to us-east-1 + us-west-2 only
│
├── docs/
│   ├── dr-runbook.md            ← full failover + failback procedure with bash commands
│   └── control-tower-setup.md  ← what CT provisions, guardrails list, interview notes
│
├── .gitignore                   ← excludes terraform.tfvars, .terraform/, *.pem
└── README.md                    ← architecture diagram, module table, skills list, what I learned
```

---

## What I Learned

This 7-day project was built as part of a structured skill-gap sprint targeting Cloud Platform Engineer roles. Key takeaways:

1. **Control Tower + Organizations are not the same thing** — Organizations is the account management plane; Control Tower is the governance layer on top of it that adds guardrails, Account Factory, and centralized logging by default.
2. **Non-overlapping CIDRs matter** — Transit Gateway routing breaks silently if VPC CIDRs overlap. Planning the IP space upfront (10.1, 10.2, 10.3 per environment) is a production requirement.
3. **DR is a runbook, not just infrastructure** — The Pilot Light ASG is useless without a tested failover procedure. RTO/RPO targets must be defined before the architecture, not after.
4. **SSM Parameter Store replaces hardcoded config** — Referencing SSM params in Terraform via `data "aws_ssm_parameter"` is the clean pattern for secrets/config separation.

---

## Cost

**~$0/month** on AWS Free Tier. All EC2 instances used for testing are t2.micro and terminated after validation. VPCs, OUs, Control Tower baseline, and IAM resources are free.

---

## License

MIT — feel free to fork and adapt for your own landing zone builds.
