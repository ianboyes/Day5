# STIG v-205845 Implementation Checklist

Use this checklist to ensure proper implementation of STIG v-205845 requirements.

## Pre-Implementation Checklist

### Planning Phase
- [ ] Read and understand `ADMINISTRATIVE_ACCOUNT_POLICY.md`
- [ ] Review `IMPLEMENTATION_GUIDE.md` thoroughly
- [ ] Identify all administrative accounts in scope
- [ ] Identify all Windows Server 2019 systems in scope
- [ ] Determine deployment method (local vs. GPO)
- [ ] Schedule implementation window (maintenance window recommended)
- [ ] Establish exception approval process
- [ ] Notify administrative staff of upcoming changes
- [ ] Prepare communication for affected users

### Testing Phase
- [ ] Set up test environment (non-production)
- [ ] Create system restore point on test system
- [ ] Run `Configure-AppLockerRules.ps1 -WhatIf` to preview changes
- [ ] Apply configuration on test system
- [ ] Verify with `Verify-STIGCompliance.ps1 -Detailed`
- [ ] Test with administrative account (browsers should be blocked)
- [ ] Test with non-administrative account (browsers should work)
- [ ] Review AppLocker event logs for issues
- [ ] Document any issues or unexpected behavior
- [ ] Test exception process if needed
- [ ] Keep test system running for 24-48 hours
- [ ] Review with security team

### Approval Phase
- [ ] Document test results
- [ ] Get approval from Information Security Officer
- [ ] Get approval from IT Management
- [ ] Schedule production deployment
- [ ] Prepare rollback plan

## Implementation Checklist

### Local Implementation (Single Server)
- [ ] Create system restore point
  ```powershell
  Checkpoint-Computer -Description "Before STIG v-205845" -RestorePointType "MODIFY_SETTINGS"
  ```
- [ ] Download implementation files to server
- [ ] Open PowerShell as Administrator
- [ ] Navigate to implementation directory
- [ ] Run: `.\Configure-AppLockerRules.ps1 -Verbose`
- [ ] Review script output for errors
- [ ] Verify XML file created: `AppLocker-STIG-v205845-Policy.xml`
- [ ] Run: `.\Verify-STIGCompliance.ps1 -Detailed -ExportReport`
- [ ] Review compliance report
- [ ] Test browser access as administrator (should be blocked)
- [ ] Test email client access as administrator (should be blocked)
- [ ] Document completion and any issues

### Group Policy Implementation (Domain-Wide)
- [ ] Generate policy XML on workstation
  ```powershell
  .\Configure-AppLockerRules.ps1 -WhatIf
  ```
- [ ] Open Group Policy Management Console
- [ ] Create new GPO: "STIG v-205845 - Admin Restrictions"
- [ ] Edit GPO
- [ ] Navigate to AppLocker section (Computer Config > Policies > Windows Settings > Security Settings > Application Control Policies > AppLocker)
- [ ] Import policy XML into Executable Rules
- [ ] Set enforcement mode to "Enforce rules"
- [ ] Configure AppLocker service to start automatically via GPO
- [ ] Link GPO to test OU first
- [ ] Wait for group policy to apply (or run `gpupdate /force`)
- [ ] Verify on test systems using `Verify-STIGCompliance.ps1`
- [ ] Monitor for 24-48 hours
- [ ] Review AppLocker event logs across test systems
- [ ] Address any issues found
- [ ] Link GPO to production OUs (phased approach recommended)

## Post-Implementation Checklist

### Immediate (Day 1)
- [ ] Verify AppLocker service is running on all systems
- [ ] Test administrative account restrictions on sample systems
- [ ] Review AppLocker event logs for blocked attempts
- [ ] Document completion time
- [ ] Send completion notification to stakeholders

### Short-term (Week 1)
- [ ] Monitor AppLocker event logs daily
- [ ] Track and respond to exception requests
- [ ] Document any issues or unexpected blocks
- [ ] Run compliance verification on random sample of systems
- [ ] Update documentation based on lessons learned

### Medium-term (Month 1)
- [ ] Run compliance check on all systems
- [ ] Review exception requests and approvals
- [ ] Analyze blocked application attempts
- [ ] Update policy if needed
- [ ] Train new administrators on policy

### Long-term (Ongoing)
- [ ] Monthly: Review AppLocker event logs
- [ ] Monthly: Verify compliance on sample systems
- [ ] Quarterly: Audit all exceptions
- [ ] Quarterly: Update blocked application list if needed
- [ ] Annually: Review and update policy document
- [ ] Annually: Recertify all exceptions

## Verification Checklist

Run these checks to verify proper implementation:

### AppLocker Service
- [ ] Service is running: `Get-Service -Name AppIDSvc | Select-Object Status`
- [ ] Service is set to Automatic: `Get-Service -Name AppIDSvc | Select-Object StartType`

### AppLocker Policy
- [ ] Policy exists: `Get-AppLockerPolicy -Effective`
- [ ] Executable rules collection exists
- [ ] Enforcement mode is "Enabled" (not "AuditOnly")
- [ ] Browser deny rules present for administrators
- [ ] Email client deny rules present for administrators

### Functional Testing
- [ ] Administrative account cannot launch Edge
- [ ] Administrative account cannot launch Chrome
- [ ] Administrative account cannot launch Firefox
- [ ] Administrative account cannot launch Outlook
- [ ] Non-administrative account can launch browsers normally
- [ ] Event log shows blocked attempts (Event ID 8004)

### Documentation
- [ ] Policy document is current
- [ ] Exception list is documented
- [ ] Implementation notes are recorded
- [ ] Compliance reports are saved

## Exception Management Checklist

For each exception request:
- [ ] Request submitted with business justification
- [ ] Technical review completed
- [ ] Security risk assessment performed
- [ ] Compensating controls identified (if needed)
- [ ] ISSO/ISSM approval obtained
- [ ] Exception documented in policy
- [ ] AppLocker exception rule created (if approved)
- [ ] Exception expiration date set
- [ ] Exception added to review calendar

## Troubleshooting Checklist

If issues arise:
- [ ] Check AppLocker service status
- [ ] Review AppLocker event logs
- [ ] Verify GPO is linked and enabled
- [ ] Run `gpresult /h gpresult.html` to check applied policies
- [ ] Check for conflicting AppLocker policies
- [ ] Verify administrative group membership
- [ ] Test with different administrative account
- [ ] Review `IMPLEMENTATION_GUIDE.md` troubleshooting section
- [ ] Escalate to security team if unresolved

## Rollback Checklist

If rollback is required:
- [ ] Document reason for rollback
- [ ] Get approval for rollback
- [ ] Notify stakeholders
- [ ] For local: Stop AppLocker service
  ```powershell
  Stop-Service -Name AppIDSvc
  Set-Service -Name AppIDSvc -StartupType Manual
  ```
- [ ] For GPO: Disable or unlink GPO
- [ ] Force policy update: `gpupdate /force`
- [ ] Verify browsers/email clients are accessible
- [ ] Document rollback completion
- [ ] Plan remediation before re-implementation

## Compliance Audit Checklist

For STIG compliance audits:
- [ ] Policy document is current and approved
- [ ] AppLocker rules are configured and enforced
- [ ] Verification script shows compliance
- [ ] AppLocker event logs show blocking is active
- [ ] Exceptions are documented with approvals
- [ ] Regular compliance checks are documented
- [ ] No unauthorized administrative Internet usage

## Documentation Checklist

Ensure all documentation is complete:
- [ ] `ADMINISTRATIVE_ACCOUNT_POLICY.md` reviewed and approved
- [ ] Implementation date recorded
- [ ] Systems in scope documented
- [ ] Exceptions documented with approvals
- [ ] Implementation notes saved
- [ ] Compliance reports archived
- [ ] Rollback procedures tested and documented
- [ ] Contact information current

---

## Sign-off

### Implementation Completed By
- Name: _______________________________
- Date: _______________________________
- Signature: _______________________________

### Verified By
- Name: _______________________________
- Date: _______________________________
- Signature: _______________________________

### Approved By (ISSO/ISSM)
- Name: _______________________________
- Date: _______________________________
- Signature: _______________________________

---

**Checklist Version**: 1.0  
**Last Updated**: 2025-12-05  
**Related STIG**: v-205845
