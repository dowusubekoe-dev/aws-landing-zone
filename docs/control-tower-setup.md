# Control Tower Setup Notes

## What Control Tower Provisions Automatically

When you enable AWS Control Tower in your Management account, it creates:

| Resource | Account | Purpose |
|----------|---------|---------|
| Log Archive Account | Security OU | Central S3 bucket for CloudTrail + Config logs from all accounts |
| Audit Account | Security OU | Read-only access for security tools; SNS topic for notifications |
| CloudTrail (org-wide) | All accounts | Immutable audit trail forwarded to Log Archive |
| AWS Config (org-wide) | All accounts | Resource configuration history forwarded to Log Archive |
| Baseline VPC | Each new account | Optional — Account Factory can deploy a standard VPC |

## Guardrails Enabled

### Mandatory (cannot be disabled)
- Disallow configuration changes to CloudTrail
- Detect public read access to Log Archive S3 bucket
- Disallow changes to AWS Config rules set up by Control Tower

### Enabled Optionally (this project)
- `s3-bucket-public-read-prohibited` — prevents public S3 buckets in workload accounts
- `iam-user-mfa-enabled` — requires MFA for all IAM console users

## Account Factory Config

New accounts vended via Account Factory receive:
- Control Tower baseline applied automatically
- SSO access configured
- VPC with standard CIDR (overridden by Terraform in this project)
- Config recorder enabled

## Key Takeaways for Interviews

> "Control Tower sits on top of AWS Organizations. Organizations handles the account hierarchy and SCPs. Control Tower adds the governance layer — Log Archive, Audit account, guardrails, and Account Factory for automated account vending. The Landing Zone Accelerator is the IaC version of what Control Tower does manually."
