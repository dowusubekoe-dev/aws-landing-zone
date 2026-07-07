# Day 2 — Enable AWS Control Tower + Account Factory

**Time estimate:** 2–3 hrs
**Prerequisite:** Logged into the Management account (`428101261622`) before starting.
**Skill covered:** AWS Control Tower · Account Factory · Guardrails · Landing Zone baseline

---

## Before You Start — Verify Your OU Structure Is Clean

Before enabling Control Tower, confirm your Organizations structure from Day 1 is intact and all member accounts are `ACTIVE`.

```bash
# Confirm all accounts exist and are ACTIVE
aws organizations list-accounts \
  --profile cloud-eng-iac \
  --query 'Accounts[*].{ID:Id,Name:Name,Email:Email,Status:Status}' \
  --output table
```

Expected output:

```
+----------------------------------+---------------+-----------------+--------+
|             Email                |      ID       |      Name       | Status |
+----------------------------------+---------------+-----------------+--------+
| cloud.sec101.insights@gmail.com  | 428101261622  | cloud-sec101    | ACTIVE |
| cloud.sec101.insights+sec2@...   | XXXXXXXXXXX   | Security-Audit  | ACTIVE |
| cloud.sec101.insights+dev2@...   | XXXXXXXXXXX   | Development     | ACTIVE |
| cloud.sec101.insights+prod2@...  | XXXXXXXXXXX   | Production      | ACTIVE |
+----------------------------------+---------------+-----------------+--------+
```

```bash
# Confirm Security and Workloads OUs exist under Root
aws organizations list-organizational-units-for-parent \
  --parent-id $(aws organizations list-roots \
    --profile cloud-eng-iac \
    --query 'Roots[0].Id' \
    --output text) \
  --profile cloud-eng-iac \
  --query 'OrganizationalUnits[*].{ID:Id,Name:Name}' \
  --output table
```

Expected output:

```
+-------------------+------------+
|        ID         |    Name    |
+-------------------+------------+
|  ou-9skp-r31i8nug |  Security  |
|  ou-9skp-tbjk46xu |  Workloads |
+-------------------+------------+
```

> ⚠️ **If any accounts show `SUSPENDED`** — they are closed accounts from a
> previous attempt and will not interfere with Control Tower. Suspended accounts
> are automatically cleaned up by AWS after 90 days.

---

## What Is AWS Control Tower?

Control Tower is the **governance layer** that sits on top of AWS Organizations.
While Organizations manages the account hierarchy and enforces SCPs, Control Tower
adds:

| Component | What It Does |
|-----------|-------------|
| **Landing Zone** | Baseline configuration applied to every account automatically |
| **Log Archive Account** | Central S3 bucket receiving CloudTrail + Config logs from all accounts |
| **Audit Account** | Read-only access for security tooling + SNS alerts |
| **Guardrails** | Preventive (SCPs) and detective (Config rules) controls across all OUs |
| **Account Factory** | Automated account vending — provisions new accounts with baseline applied |

> **Interview answer for Trianz/Leidos:**
> *"Control Tower and Organizations are not the same thing. Organizations is the
> account management plane — it handles the hierarchy and SCPs. Control Tower is
> the governance layer on top of it. It auto-provisions a Log Archive account,
> an Audit account, enables org-wide CloudTrail and Config, and adds Account
> Factory for automated account vending. The Landing Zone Accelerator is the
> IaC version of what Control Tower does through the console."*

---

## Step 1 — Activate All Member Accounts

Control Tower deploys CloudFormation StackSets into every member account during
setup. Each account must have accepted the AWS Customer Agreement before
Control Tower can deploy into it, or the setup will fail with
`OptInRequired (403)`.

### Sign Into Each Member Account as Root

Do this for Security-Audit, Development, and Production:

```
1. Go to https://console.aws.amazon.com/
2. Select "Root user"
3. Enter the member account root email
4. Click "Forgot password" → check Gmail inbox for reset link
5. Set a new password
6. Sign in → Accept AWS Customer Agreement
7. Select "Basic support (Free)" plan
8. Confirm you land on the AWS Console home page
9. Sign out → repeat for next account
```

> **Why this is required:** Accounts created via Organizations are provisioned
> without the root user completing the sign-up flow. CloudFormation cannot deploy
> into accounts that haven't accepted the AWS terms of service.

### Verify CloudFormation Access

```bash
# Assume into each member account and verify CloudFormation is accessible
aws sts assume-role \
  --role-arn arn:aws:iam::DEV_ACCOUNT_ID:role/OrganizationAccountAccessRole \
  --role-session-name ct-verify \
  --profile cloud-eng-iac

export AWS_ACCESS_KEY_ID=<AccessKeyId>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey>
export AWS_SESSION_TOKEN=<SessionToken>

# Trigger CloudFormation opt-in
aws cloudformation list-stacks --region us-east-1

# Clear credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

---

## Step 2 — Enable AWS Control Tower

Control Tower initial setup **must be done through the AWS Console** — there is
no CLI command to bootstrap the landing zone for the first time.

### Console Setup Steps

```
1. Log into AWS Console → Management Account (428101261622)

2. Search "Control Tower" → click "Set up landing zone"

3. Home Region:
   → Select: US East (N. Virginia) — us-east-1

4. Additional Regions for governance:
   → Add: US West (Oregon) — us-west-2
   → (Needed for Day 5 Pilot Light DR setup)

5. Foundational OU configuration:
   → Security OU name:   Security   ← match your existing OU
   → Sandbox OU name:    Workloads  ← match your existing OU

6. Log Archive account:
   → Email: cloud.sec101.insights+logarchive2@gmail.com
   → Account name: Log-Archive

7. Audit account:
   → Email: cloud.sec101.insights+audit2@gmail.com
   → Account name: Audit

8. Review settings → Click "Set up landing zone"

9. ⏳ Setup takes 20–30 minutes — do NOT close the browser tab
```

> **While it runs:** Read the
> [AWS Control Tower documentation](https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html)
> and watch the setup progress bar. Note every resource being created —
> you will be asked about this in interviews.

---

## Step 3 — What Control Tower Provisions Automatically

When setup completes, verify these resources were created:

```bash
# Confirm Log Archive and Audit accounts were created
aws organizations list-accounts \
  --profile cloud-eng-iac \
  --query 'Accounts[*].{ID:Id,Name:Name,Status:Status}' \
  --output table
```

You should now see 6 accounts total:

| Account | Purpose | Created By |
|---------|---------|-----------|
| cloud-sec101 | Management | You (Day 1) |
| Security-Audit | Security tooling | You (Day 1) |
| Development | Workload | You (Day 1) |
| Production | Workload | You (Day 1) |
| **Log-Archive** | Central logging | **Control Tower (auto)** |
| **Audit** | Security read-only | **Control Tower (auto)** |

```bash
# Verify org-wide CloudTrail was enabled
aws cloudtrail describe-trails \
  --profile cloud-eng-iac \
  --region us-east-1 \
  --query 'trailList[*].{Name:Name,MultiRegion:IsMultiRegionTrail,OrgTrail:IsOrganizationTrail}' \
  --output table
```

```bash
# Verify AWS Config recorder is active
aws configservice describe-configuration-recorders \
  --profile cloud-eng-iac \
  --region us-east-1 \
  --query 'ConfigurationRecorders[*].{Name:name,AllSupported:recordingGroup.allSupported}' \
  --output table
```

---

## Step 4 — Enable Guardrails

Guardrails are governance rules that Control Tower enforces across your
landing zone. There are two types:

| Type | Mechanism | Example |
|------|-----------|---------|
| **Preventive** | SCP — blocks the action before it happens | "Disallow public S3 buckets" |
| **Detective** | AWS Config rule — detects and alerts after the fact | "Detect MFA not enabled" |

### Mandatory Guardrails (Already Active)

These cannot be disabled — note them for interviews:

```
✅ Disallow configuration changes to CloudTrail
✅ Detect public read access to Log Archive S3 bucket
✅ Disallow changes to AWS Config rules set up by Control Tower
✅ Detect whether MFA for the root user is enabled
```

### Enable Optional Guardrails

```
Control Tower Console → Guardrails

Enable these two:

1. "Disallow S3 public read access to S3 buckets"
   → Type: Preventive
   → Apply to: Workloads OU
   → Click "Enable guardrail"

2. "Require MFA for IAM users"
   → Type: Preventive
   → Apply to: Workloads OU
   → Click "Enable guardrail"
```

```bash
# Verify guardrails are active via CLI
aws controltower list-enabled-controls \
  --target-identifier arn:aws:organizations::428101261622:ou/o-XXXX/ou-9skp-tbjk46xu \
  --profile cloud-eng-iac \
  --region us-east-1 \
  --query 'enabledControls[*].{Control:controlIdentifier,Status:statusSummary.status}' \
  --output table
```

---

## Step 5 — Use Account Factory to Vend a Sandbox Account

Account Factory is the automated account vending machine — it provisions
new accounts with the landing zone baseline applied automatically. This is
the core capability that Trianz specifically tests for in interviews.

```
Control Tower Console → Account Factory → Create account

Fill in:
  Account name:          Sandbox
  Account email:         cloud.sec101.insights+sandbox2@gmail.com
  Display name:          Sandbox
  IAM Identity Center:   your name
  Email:                 cloud.sec101.insights@gmail.com
  OU:                    Workloads

→ Click "Enroll account"
→ Provisioning takes 10–15 minutes
```

### What Account Factory Does Automatically

When a new account is vended via Account Factory:

- ✅ Landing Zone baseline applied
- ✅ Mandatory guardrails enforced immediately
- ✅ IAM Identity Center (SSO) access configured
- ✅ CloudTrail and Config enabled
- ✅ VPC baseline deployed (configurable)
- ✅ Account placed in the specified OU

```bash
# Verify Sandbox account appears in Organizations
aws organizations list-accounts \
  --profile cloud-eng-iac \
  --query 'Accounts[?Name==`Sandbox`].{ID:Id,Name:Name,Status:Status}' \
  --output table
```

---

## Troubleshooting — Issues Encountered

### Issue 1 — AWSControlTowerExecution Role Deployment Failure

**Error:**
```
AWS Control Tower cannot create the required role AWSControlTowerExecution
because some stack instances of the stack set AWSControlTowerExecutionRole
could not be deployed.
```

**Root Cause:** Suspended accounts in the Workloads OU caused CloudFormation
StackSet deployment to fail with `OptInRequired (403)`. Suspended accounts
reject all CloudFormation operations.

**Diagnosis:**
```bash
aws cloudformation list-stack-instances \
  --stack-set-name AWSControlTowerExecutionRole \
  --profile cloud-eng-iac \
  --region us-east-1 \
  --query 'Summaries[*].{Account:Account,Status:Status,Reason:StatusReason}' \
  --output table
```

**Fix — Delete failed StackSet instances by OU:**

> ⚠️ Note: SERVICE_MANAGED StackSets require OU-level targeting —
> individual account targeting returns `ValidationError`.

```bash
# Delete failed instances from Workloads OU
aws cloudformation delete-stack-instances \
  --stack-set-name AWSControlTowerExecutionRole \
  --deployment-targets OrganizationalUnitIds=ou-9skp-tbjk46xu \
  --regions us-east-1 \
  --no-retain-stacks \
  --profile cloud-eng-iac \
  --region us-east-1

# Verify cleared
aws cloudformation list-stack-instances \
  --stack-set-name AWSControlTowerExecutionRole \
  --profile cloud-eng-iac \
  --region us-east-1 \
  --query 'Summaries[*].{Account:Account,Status:Status}' \
  --output table
```

Then retry Control Tower setup in the console.

---

### Issue 2 — Password Recovery Disabled on Member Accounts

**Error:**
```
Password recovery failed
Password recovery is disabled for your AWS account.
```

**Root Cause:** Outstanding AWS billing balance caused the platform to
block root password recovery across all member accounts.

**Workaround — Switch Role (no password needed):**

```
AWS Console → Management Account
→ Top-right → Switch Role
→ Account ID:   MEMBER_ACCOUNT_ID
→ Role name:    OrganizationAccountAccessRole
→ Click Switch Role
```

**Permanent Fix:** Resolve the outstanding balance → password recovery
re-enables automatically within minutes of payment processing.

---

### Issue 3 — Member Account OptInRequired (403)

**Error:**
```
The AWS Access Key Id needs a subscription for the service
(Service: AmazonCloudFormation; Status Code: 403; Error Code: OptInRequired)
```

**Root Cause:** Member account created via Organizations but root user
never completed sign-up and accepted the AWS Customer Agreement.

**Fix:** Sign into each member account as root user, accept terms,
select Basic support plan. See Step 1 of this document.

---

## Step 6 — Document and Commit to GitHub

```bash
# Stage all Day 2 documentation
git add docs/day2-control-tower.md
git add docs/control-tower-setup.md

git commit -m "day2: Control Tower landing zone + guardrails + Account Factory

- Enabled Control Tower in us-east-1 with us-west-2 governance region
- Log Archive and Audit accounts provisioned automatically
- Org-wide CloudTrail and AWS Config enabled
- Two optional guardrails enabled: S3 public read + MFA required
- Sandbox account vended via Account Factory
- Documented AWSControlTowerExecution role failure + fix
- Documented OptInRequired member account activation requirement"

git push origin main
```

---

## Day 2 Deliverables Checklist

```
[ ] All member accounts activated (AWS terms accepted)
[ ] Control Tower landing zone setup complete (20–30 min)
[ ] Log Archive account provisioned automatically
[ ] Audit account provisioned automatically
[ ] Org-wide CloudTrail confirmed active
[ ] AWS Config recorder confirmed active
[ ] Two optional guardrails enabled (S3 public read + MFA)
[ ] Sandbox account vended via Account Factory
[ ] docs/day2-control-tower.md committed to GitHub
[ ] docs/control-tower-setup.md committed to GitHub
[ ] Screenshot of Control Tower dashboard in docs/screenshots/
```

---

## Key Takeaways for Interviews

**Q: What is the difference between AWS Organizations and Control Tower?**

> Organizations is the account management plane — it handles the account
> hierarchy, OUs, and Service Control Policies. Control Tower is the
> governance layer built on top of Organizations. It adds a Landing Zone
> baseline, Log Archive and Audit accounts, org-wide CloudTrail and Config,
> guardrails, and Account Factory for automated account vending.

**Q: What does Account Factory do that manually creating accounts doesn't?**

> Account Factory applies the full Landing Zone baseline automatically on
> every new account — mandatory guardrails, CloudTrail, Config, SSO access,
> and correct OU placement. Manual account creation through Organizations
> gives you a raw account with none of that. Account Factory is how
> enterprises enforce consistency at scale.

**Q: What are Control Tower guardrails and how do they differ?**

> There are two types. Preventive guardrails use SCPs to block actions before
> they happen — for example, blocking S3 public access at the OU level
> regardless of what any IAM policy in a member account says. Detective
> guardrails use AWS Config rules to identify and alert on non-compliant
> resources after the fact. Mandatory guardrails cannot be disabled;
> optional ones can be enabled per OU.

---

## Resources

- [AWS Control Tower Documentation](https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html)
- [Landing Zone Accelerator on AWS](https://aws.amazon.com/solutions/implementations/landing-zone-accelerator-on-aws/)
- [AWS re:Invent: Control Tower Deep Dive](https://www.youtube.com/results?search_query=AWS+Control+Tower+reInvent+deep+dive)
- [Account Factory for Terraform](https://developer.hashicorp.com/terraform/tutorials/aws/aws-control-tower-aft)

---

## What's Next — Day 3

**Day 3 — Provision VPCs + IAM Roles via Terraform**

Building the IaC account baseline: custom VPC with public/private subnets,
cross-account IAM roles, and non-overlapping CIDR blocks (10.1/10.2/10.3)
required for the Day 4 Transit Gateway setup.

```
Day 1 ✅ AWS Organizations + SCPs
Day 2 ✅ Control Tower + Account Factory + Guardrails   ← YOU ARE HERE
Day 3 → Terraform VPCs + Cross-Account IAM Roles
Day 4 → Transit Gateway Hub-and-Spoke Networking
Day 5 → Multi-Region DR — Pilot Light Pattern
Day 6 → CloudWatch + SSM Monitoring Layer
Day 7 → CI/CD Pipeline + GitHub Portfolio Polish
```

---

*Part of the [AWS Secure Multi-Account Landing Zone](../README.md) project*
*7-day hands-on build — Cloud Engineer portfolio project*