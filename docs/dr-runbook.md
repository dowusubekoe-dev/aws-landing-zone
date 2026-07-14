# DR Runbook — Pilot Light Pattern
**Last Updated:** June 2026
**Owner:** Derek Owusu Bekoe.
**Pattern:** Pilot Light
**Primary Region:** us-east-1
**DR Region:** us-west-2

---

## Recovery Targets

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | 60 minutes | Time from incident declaration to DR traffic serving |
| **RPO** (Recovery Point Objective) | 15 minutes | Maximum acceptable data loss (S3 CRR replication lag) |

---

## How Pilot Light Works

The DR region runs a minimal "pilot light" at near-zero cost:
- **AMI pre-staged** in us-west-2 (copied from prod, refreshed monthly)
- **Auto Scaling Group** at `min=0, desired=0, max=2` — costs nothing until triggered
- **S3 Cross-Region Replication** running continuously — data lag ≤15 min
- **Route 53 health checks** monitoring the prod ALB

When prod fails, CloudWatch alarms trigger the ASG scale-up automatically, or an on-call engineer manually executes this runbook.

---

## Trigger Conditions

**Automatic:** CloudWatch alarm `prod-ec2-status-check-failed` fires when:
- `StatusCheckFailed` ≥ 1 for 2 consecutive 5-minute evaluation periods

**Manual:** On-call engineer declares P1 incident when any of the following occur:
- Prod ALB health check failures > 50% for 10+ minutes
- Complete region degradation (AWS Service Health Dashboard)
- Application team declares data integrity issue in prod

---

## Failover Procedure

**Estimated time: 30–45 minutes**

### Step 1 — Confirm Degradation (5 min)
```
[ ] Check AWS Service Health Dashboard for us-east-1 status
[ ] Confirm CloudWatch alarm state: prod-ec2-status-check-failed = ALARM
[ ] Verify prod ALB target group health: < 50% healthy targets
[ ] Page secondary on-call if not already engaged
[ ] Declare incident in Slack #incidents: "P1 — Initiating DR failover to us-west-2"
```

### Step 2 — Scale DR Infrastructure (10 min)
```bash
# Option A: Automatic (CloudWatch alarm already triggered ASG policy)
# Verify DR ASG has scaled:
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dr-pilot-light-asg \
  --region us-west-2 \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,InService:Instances[?LifecycleState==`InService`]}'

# Option B: Manual scale-up
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name dr-pilot-light-asg \
  --desired-capacity 2 \
  --region us-west-2
```

```
[ ] Confirm DR instances reach InService state in ASG
[ ] Verify application health check passes on DR ALB: /health endpoint returns 200
```

### Step 3 — Update DNS Routing (5 min)
```bash
# Update Route 53 weighted routing — shift 100% traffic to us-west-2
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch file://docs/route53-dr-failover.json
```

```
[ ] Confirm DNS change propagated (TTL: 60 seconds)
[ ] Test app from external network: curl -I https://app.yourdomain.com
[ ] Notify stakeholders: "DR active — serving from us-west-2. RTO clock: XX:XX"
```

### Step 4 — Monitor DR Environment (ongoing)
```
[ ] Watch DR ASG metrics in CloudWatch Dashboard: LandingZone-OpsOverview
[ ] Monitor error rates and latency in DR region
[ ] Confirm S3 data consistency (latest objects accessible)
[ ] Begin post-incident investigation of primary region failure
```

---

## Failback Procedure

**Estimated time: 60–90 minutes | Perform during low-traffic window**

### Step 1 — Restore Primary Region
```
[ ] Resolve root cause of primary region failure
[ ] Re-deploy prod EC2 instances (or restore from backup AMI)
[ ] Verify prod ALB health check: all targets healthy
[ ] Run smoke tests against prod (not yet serving traffic)
```

### Step 2 — Sync Data from DR to Primary
```bash
# Sync any data written to DR S3 bucket back to primary
aws s3 sync s3://prod-bucket-us-west-2 s3://prod-bucket-us-east-1 \
  --source-region us-west-2 \
  --region us-east-1

# Verify RDS data (if RDS is used — may require point-in-time restore)
```

### Step 3 — Shift Traffic Back
```bash
# Restore Route 53 to primary region
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch file://docs/route53-primary-restore.json
```

### Step 4 — Scale DR Back to Zero
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name dr-pilot-light-asg \
  --desired-capacity 0 \
  --region us-west-2
```

```
[ ] Confirm prod serving 100% traffic
[ ] Confirm DR ASG at desired=0 (cost savings restored)
[ ] Update incident ticket with timeline and root cause
[ ] Schedule post-mortem within 48 hours
```

---

## Monthly DR Test Procedure

Run this the first Sunday of each month during maintenance window:

1. Scale DR ASG to `desired=1` manually
2. Verify app health check passes in us-west-2
3. Confirm S3 CRR replication lag < 15 minutes
4. Scale DR ASG back to `desired=0`
5. Update this document with test date and result

**Last tested:** _(update after each test)_

---

## Key Resource Reference

| Resource | Region | Value |
|----------|--------|-------|
| Prod ALB | us-east-1 | _(fill in after deploy)_ |
| DR ALB | us-west-2 | _(fill in after deploy)_ |
| DR ASG Name | us-west-2 | `dr-pilot-light-asg` |
| Route 53 Hosted Zone | global | _(fill in)_ |
| Prod S3 Bucket | us-east-1 | _(fill in)_ |
| DR S3 Bucket | us-west-2 | _(fill in)_ |
| CloudWatch Alarm | us-east-1 | `prod-ec2-status-check-failed` |
| On-Call Slack Channel | — | `#incidents` |
