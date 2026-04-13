# AWS DevOps Agent Cross-Account Monitoring - Issue Resolution Report

**Date:** February 5, 2026  
**Reporter:** Murthy (lingamurthy.allam@zayo.com)  
**Status:** ✅ RESOLVED  

---

## Executive Summary

Terraform deployment for AWS DevOps Agent cross-account monitoring failed with error "Cross-account pass role is not allowed." Root cause was incorrect Terraform configuration syntax for cross-account associations. Issue resolved by changing configuration type from `aws` to `source_aws` and adding PassRole service condition.

---

## Environment Details

**Primary Account:** 414351351247 (zayo-ct)  
**Target Account:** 608649261817 (zayo-dev01)  
**Agent Space ID:** fe2370ca-ed86-43e3-b8e4-33af40b5605b  
**Region:** us-east-1  

---

## Problem Statement

### Error Message
```
Error: AWS SDK Go Service Operation Incomplete
Cross-account pass role is not allowed. (Service: DevOpsAgent, Status Code: 403)
```

### Impact
- Unable to create cross-account association for monitoring
- Terraform apply failed repeatedly
- Blocked deployment to 50 target accounts

---

## Root Cause Analysis

### Issue #1: Missing PassRole Service Condition
**Severity:** Medium (Security Best Practice)  
**File:** `iam.tf` lines 81-97

The AgentSpace role's PassRole permission lacked a service condition, allowing unrestricted PassRole operations instead of limiting to DevOps Agent service only.

### Issue #2: Incorrect Configuration Type (CRITICAL)
**Severity:** Critical  
**File:** `cross-account.tf` lines 48-53

Used wrong configuration syntax for external account associations. AWS DevOps Agent requires `source_aws` with `account_type = "source"` for monitored accounts, not `aws` with `account_type = "monitor"`.

---

## Resolution

### Fix #1: Added PassRole Service Condition

**File:** `iam.tf`

```terraform
statement {
  sid    = "AllowPassRoleForCrossAccount"
  effect = "Allow"
  actions = ["iam:PassRole"]
  resources = ["arn:aws:iam::*:role/DevOpsAgentCrossAccountRole"]
  
  condition {
    test     = "StringEquals"
    variable = "iam:PassedToService"
    values   = ["devopsagent.amazonaws.com"]
  }
}
```

### Fix #2: Corrected Configuration Type

**File:** `cross-account.tf`

**Before:**
```terraform
configuration = {
  aws = {
    account_id         = each.value.account_id
    account_type       = "monitor"
    assumable_role_arn = "arn:aws:iam::${each.value.account_id}:role/DevOpsAgentCrossAccountRole"
    resources          = []
  }
}
```

**After:**
```terraform
configuration = {
  source_aws = {
    account_id         = each.value.account_id
    account_type       = "source"
    assumable_role_arn = "arn:aws:iam::${each.value.account_id}:role/DevOpsAgentCrossAccountRole"
    resources          = []
  }
}
```

---

## Deployment Timeline

| Time | Event |
|------|-------|
| 11:11 AM | First failed attempt - "Cross-account pass role not allowed" |
| 11:47 AM | AWS Support case opened |
| 12:04 PM | Second failed attempt after adding SSO PassRole permission |
| 12:05 PM | Added PassRole condition to AgentSpace role |
| 12:05 PM | Changed configuration to `source_aws` |
| 12:06 PM | ✅ **Successful deployment** |

---

## AWS Support Involvement

**Key Recommendations:**
1. Add PassRole permission with service condition to SSO permission set
2. Reference AWS Builder article on multi-account monitoring
3. Confirmed cross-account role configuration was correct

**AWS Builder Article:** "Setting Up AWS DevOps Agent for Multi-Account Monitoring with AWS CLI"

**Critical Insight:** Error message was misleading - appeared to be IAM permissions issue but was actually Terraform configuration syntax error.

---

## Verification

### Cross-Account Role Validation
✅ Role exists in target account: `DevOpsAgentCrossAccountRole`  
✅ Trust policy correctly configured with ExternalId  
✅ Permissions policy attached: `AIOpsAssistantPolicy`  

### Deployment Success
```
✅ terraform apply succeeded
✅ Cross-account association created
✅ Account 608649261817 now monitored
```

**Association ID:** Created successfully  
**Primary Account Association:** a9dada61-86c6-492a-ae28-d818db8a01ae

---

## Configuration Summary

### Primary Account (414351351247)
- **Agent Space:** fe2370ca-ed86-43e3-b8e4-33af40b5605b
- **AgentSpace Role:** DevOpsAgentRole-AgentSpace-466bd434
- **Operator Role:** DevOpsAgentRole-WebappAdmin-466bd434
- **Managed Policies:** AIOpsAssistantPolicy
- **Inline Policies:** PassRole with service condition

### Target Account (608649261817)
- **Cross-Account Role:** DevOpsAgentCrossAccountRole
- **Deployment Method:** CloudFormation StackSet
- **Trust Principal:** DevOpsAgentRole-AgentSpace-466bd434
- **ExternalId:** arn:aws:aidevops:us-east-1:414351351247:agentspace/fe2370ca-ed86-43e3-b8e4-33af40b5605b

---

## Lessons Learned

### 1. Error Messages Can Be Misleading
The "pass role not allowed" error suggested IAM permissions issue, but actual problem was Terraform resource configuration syntax.

### 2. Configuration Types Matter
AWS DevOps Agent uses different configuration types for different scenarios:
- **Primary account:** `aws` with `account_type = "source"`
- **Secondary accounts:** `source_aws` with `account_type = "source"`

### 3. Documentation Gaps
AWS sample Terraform code didn't reflect latest API requirements. Always cross-reference with official documentation and Builder articles.

### 4. Security Best Practices
Always add service conditions to PassRole permissions following least privilege principle.

---

## Recommendations

### Immediate Actions
- ✅ Both fixes applied and working
- ✅ Tested with account 608649261817
- ⏳ Ready to scale to remaining 49 accounts

### Before Scaling to 50 Accounts
1. Test with 2-3 additional accounts first
2. Verify monitoring data flows correctly
3. Document any account-specific configurations
4. Prepare rollback plan

### Documentation Updates
1. Update README.md with correct cross-account configuration
2. Add troubleshooting section for common errors
3. Document difference between `aws` and `source_aws` types
4. Include reference to AWS Builder article

### Code Repository
1. Commit changes with descriptive message
2. Tag release version
3. Update CHANGELOG.md
4. Create PR for team review

---

## Technical Details

### Files Modified
- `iam.tf` - Added PassRole service condition
- `cross-account.tf` - Changed configuration type to source_aws

### CloudTrail Evidence
- Multiple failed CreateResource attempts (11:11 AM, 12:04 PM)
- Successful deployment at 12:06 PM
- No additional errors found in 5-day CloudTrail history

### IAM Permissions Added
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::*:role/DevOpsAgentCrossAccountRole",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "devopsagent.amazonaws.com"
        }
      }
    }
  ]
}
```

---

## Next Steps

1. ✅ **Completed:** Fix applied and tested
2. ✅ **Completed:** Single account deployment successful
3. **Pending:** Test with 2-3 additional accounts
4. **Pending:** Deploy to all 50 accounts via StackSet
5. **Pending:** Monitor DevOps Agent console for data collection
6. **Pending:** Enable Operator App if needed

---

## References

1. AWS Builder Article: "Setting Up AWS DevOps Agent for Multi-Account Monitoring with AWS CLI"
2. AWS Support Case: Opened February 5, 2026
3. CloudFormation StackSet: DevOpsAgent-CrossAccountRoles
4. Terraform Provider: hashicorp/awscc (AWS Cloud Control)

---

## Appendix: Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::414351351247:role/DevOpsAgentRole-AgentSpace-466bd434"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "arn:aws:aidevops:us-east-1:414351351247:agentspace/fe2370ca-ed86-43e3-b8e4-33af40b5605b"
        }
      }
    }
  ]
}
```

---

**Report Generated:** February 5, 2026, 12:22 PM PST  
**Resolution Time:** ~1 hour  
**Status:** ✅ RESOLVED - Ready for production deployment
