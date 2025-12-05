# STIG v-205845 Implementation Guide

## Overview
This guide provides step-by-step instructions for implementing STIG v-205845 on Windows Server 2019 systems. The implementation restricts administrative accounts from using Internet-accessible applications such as web browsers and email clients.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Policy Review](#policy-review)
3. [Technical Implementation](#technical-implementation)
4. [Verification](#verification)
5. [Group Policy Deployment](#group-policy-deployment)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Procedures](#rollback-procedures)

## Prerequisites

### System Requirements
- Windows Server 2019
- PowerShell 5.1 or higher
- Administrative privileges
- AppLocker feature (included in Windows Server 2019)

### Before You Begin
1. **Review the policy document**: Read `ADMINISTRATIVE_ACCOUNT_POLICY.md` thoroughly
2. **Test environment**: Always test in a non-production environment first
3. **Backup**: Create a system restore point or backup before making changes
4. **Communication**: Notify administrative staff about upcoming changes
5. **Exception process**: Establish a process for handling exceptions before implementation

### Check Current Configuration
```powershell
# Check if AppLocker service is available
Get-Service -Name AppIDSvc

# Check current AppLocker policies
Get-AppLockerPolicy -Effective

# Check current user's group membership
whoami /groups
```

## Policy Review

### Understanding the Requirement
STIG v-205845 requires organizations to:
1. Establish a policy prohibiting administrative accounts from using Internet-accessible applications
2. Enforce the policy through technical controls
3. Document exceptions with proper approvals
4. Regularly verify compliance

### Policy Documentation
The `ADMINISTRATIVE_ACCOUNT_POLICY.md` file contains:
- Policy statement and scope
- List of prohibited applications
- Enforcement mechanisms
- Exception process
- Compliance verification procedures

**Action Item**: Review and customize the policy document for your organization.

## Technical Implementation

### Option 1: Local Implementation (Single Server)

#### Step 1: Create System Restore Point
```powershell
# Create a restore point before making changes
Checkpoint-Computer -Description "Before STIG v-205845 Implementation" -RestorePointType "MODIFY_SETTINGS"
```

#### Step 2: Run Configuration Script
```powershell
# Navigate to the implementation directory
cd C:\Path\To\Day5

# Review the script before running (optional but recommended)
Get-Content .\Configure-AppLockerRules.ps1

# Run the configuration script
.\Configure-AppLockerRules.ps1 -Verbose

# Or run with WhatIf to see what would happen
.\Configure-AppLockerRules.ps1 -WhatIf
```

The script will:
1. Enable the AppLocker service
2. Create deny rules for browsers (IE, Edge, Chrome, Firefox, Opera)
3. Create deny rules for email clients (Outlook, Thunderbird, Windows Mail)
4. Export the policy to an XML file
5. Apply the policy locally

#### Step 3: Review Generated Policy
```powershell
# Check the generated XML policy
Get-Content .\AppLocker-STIG-v205845-Policy.xml

# View effective AppLocker policy
Get-AppLockerPolicy -Effective -Xml | Out-File .\Current-AppLocker-Policy.xml
```

### Option 2: Group Policy Deployment (Domain-Wide)

#### Step 1: Generate Policy XML
Run the configuration script on a test server to generate the policy XML:
```powershell
.\Configure-AppLockerRules.ps1 -WhatIf
```

This creates `AppLocker-STIG-v205845-Policy.xml` without applying it locally.

#### Step 2: Import into Group Policy
1. Open **Group Policy Management Console** (GPMC)
2. Create a new GPO or edit an existing one:
   - Right-click on the domain or OU
   - Select "Create a GPO in this domain, and Link it here"
   - Name it "STIG v-205845 - Administrative Account Restrictions"

3. Edit the GPO:
   - Navigate to: **Computer Configuration > Policies > Windows Settings > Security Settings > Application Control Policies > AppLocker**
   - Right-click on **Executable Rules**
   - Select **Import Policy**
   - Browse to `AppLocker-STIG-v205845-Policy.xml`
   - Click **Open**

4. Configure enforcement:
   - Right-click on **AppLocker**
   - Select **Properties**
   - Check **Configured** for Executable rules
   - Set enforcement mode to **Enforce rules**
   - Click **OK**

#### Step 3: Configure AppLocker Service via GPO
1. In the same GPO, navigate to:
   **Computer Configuration > Policies > Windows Settings > Security Settings > System Services**
2. Double-click **Application Identity**
3. Select **Define this policy setting**
4. Select **Automatic**
5. Click **OK**

#### Step 4: Link GPO to Appropriate OUs
- Link the GPO to OUs containing Windows Server 2019 systems
- Consider using security filtering to target specific computers
- Use WMI filtering if needed to target only Windows Server 2019

#### Step 5: Test Deployment
1. Apply the GPO to a test OU first
2. Run `gpupdate /force` on test systems
3. Verify the policy using the verification script
4. Test with an administrative account

## Verification

### Automated Verification
Run the verification script to check compliance:

```powershell
# Basic verification
.\Verify-STIGCompliance.ps1

# Detailed verification with output
.\Verify-STIGCompliance.ps1 -Detailed

# Generate compliance report
.\Verify-STIGCompliance.ps1 -ExportReport -ReportPath "C:\Reports\STIG-v205845-Compliance.txt"
```

### Manual Verification

#### Check AppLocker Service
```powershell
Get-Service -Name AppIDSvc | Select-Object Name, Status, StartType
```
Expected: Status = Running, StartType = Automatic

#### Check AppLocker Rules
```powershell
# Get effective policy
$policy = Get-AppLockerPolicy -Effective

# Check executable rules
$policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq 'Exe' }

# List deny rules for administrators
$policy.RuleCollections | 
    Select-Object -ExpandProperty Rules | 
    Where-Object { $_.Action -eq 'Deny' -and $_.UserOrGroupSid -eq 'S-1-5-32-544' }
```

#### Test with Administrative Account
1. Log in as a local administrator
2. Attempt to launch a web browser (e.g., Edge, Chrome)
3. Attempt to launch an email client (e.g., Outlook)
4. Expected result: Applications should be blocked with an error message

#### Review AppLocker Event Logs
```powershell
# Check AppLocker event logs
Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 50 | 
    Where-Object { $_.Id -eq 8004 } |
    Format-Table TimeCreated, Message -AutoSize
```

Event ID 8004 indicates a blocked application.

## Group Policy Deployment

### Phased Rollout Approach
1. **Phase 1**: Test environment (1-2 servers)
   - Deploy and verify functionality
   - Duration: 1-2 weeks

2. **Phase 2**: Pilot group (small subset of production)
   - Select representative systems
   - Monitor for issues
   - Duration: 2-4 weeks

3. **Phase 3**: Production deployment
   - Deploy to all Windows Server 2019 systems
   - Monitor closely for the first week

### Monitoring During Rollout
```powershell
# Create monitoring script to check AppLocker blocks
$computers = Get-ADComputer -Filter {OperatingSystem -like "*Server 2019*"}

foreach ($computer in $computers) {
    $events = Get-WinEvent -ComputerName $computer.Name `
        -LogName "Microsoft-Windows-AppLocker/EXE and DLL" `
        -FilterXPath "*[System[EventID=8004]]" `
        -MaxEvents 10 -ErrorAction SilentlyContinue
    
    if ($events) {
        Write-Host "$($computer.Name): $($events.Count) blocks detected"
    }
}
```

## Troubleshooting

### Common Issues

#### Issue 1: AppLocker Service Won't Start
**Symptom**: Application Identity service fails to start

**Solution**:
```powershell
# Check service dependencies
Get-Service -Name AppIDSvc | Select-Object -ExpandProperty DependentServices

# Check event logs for errors
Get-WinEvent -LogName System | Where-Object { $_.ProviderName -eq "Service Control Manager" -and $_.Message -like "*AppIDSvc*" }

# Try manual start
Start-Service -Name AppIDSvc -Verbose
```

#### Issue 2: Rules Not Applying
**Symptom**: Administrative users can still access browsers/email

**Solution**:
```powershell
# Force GPO update
gpupdate /force

# Verify policy is being applied
gpresult /h gpresult.html
# Open gpresult.html and check for AppLocker settings

# Check effective policy
Get-AppLockerPolicy -Effective
```

#### Issue 3: Legitimate Applications Blocked
**Symptom**: Required administrative tools are blocked

**Solution**:
1. Identify the blocked application from event logs
2. Create an exception rule:
```powershell
# Example: Allow specific application for administrators
New-AppLockerPolicy -RuleType Publisher `
    -FilePath "C:\Path\To\Application.exe" `
    -User "BUILTIN\Administrators" `
    -Action Allow `
    -RuleNamePrefix "STIG Exception"
```
3. Document the exception in the policy document

#### Issue 4: Enforcement Too Strict
**Symptom**: Business operations impacted

**Solution**:
1. Temporarily switch to Audit mode:
```powershell
# Switch to audit mode
Set-AppLockerPolicy -XMLPolicy .\AppLocker-STIG-v205845-Policy.xml -Merge
# Then manually edit enforcement in GPO to AuditOnly
```
2. Review audit logs to understand impact
3. Adjust rules as needed
4. Re-enable enforcement

### Event Log Analysis
```powershell
# Get blocked application attempts
Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" | 
    Where-Object { $_.Id -eq 8004 } |
    Group-Object -Property Message |
    Select-Object Count, Name |
    Sort-Object Count -Descending

# Get allowed applications
Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" | 
    Where-Object { $_.Id -eq 8003 }
```

## Rollback Procedures

### Emergency Rollback
If immediate rollback is required:

#### Local System Rollback
```powershell
# Option 1: Remove all AppLocker rules
Set-AppLockerPolicy -XMLPolicy $null -ErrorAction SilentlyContinue

# Option 2: Disable AppLocker enforcement
$policy = Get-AppLockerPolicy -Local
# Manually set enforcement to NotConfigured in GPO

# Option 3: Stop AppLocker service
Stop-Service -Name AppIDSvc -Force
Set-Service -Name AppIDSvc -StartupType Manual
```

#### Group Policy Rollback
1. Open Group Policy Management Console
2. Locate the STIG v-205845 GPO
3. Right-click and select **Delete** or **Link Enabled** (uncheck)
4. Run `gpupdate /force` on affected systems

#### System Restore
If a restore point was created:
```powershell
# List available restore points
Get-ComputerRestorePoint

# Restore to previous state
Restore-Computer -RestorePoint <RestorePointNumber>
```

### Planned Rollback
For controlled rollback:
1. Document the reason for rollback
2. Communicate to stakeholders
3. Disable GPO link or switch to Audit mode first
4. Monitor for 24-48 hours
5. Remove GPO if no issues arise
6. Update documentation

## Best Practices

### Implementation
1. Always test in a non-production environment first
2. Create system restore points or backups
3. Implement during a maintenance window
4. Have a rollback plan ready
5. Monitor closely for the first 24-48 hours

### Ongoing Management
1. Review AppLocker logs weekly
2. Update rules when new applications are approved
3. Audit exceptions quarterly
4. Document all changes
5. Review policy annually

### Exception Management
1. Use a formal request process
2. Require business justification
3. Get appropriate approvals (ISSO/ISSM)
4. Set expiration dates for exceptions
5. Review exceptions regularly

### Documentation
1. Maintain current policy documentation
2. Keep change logs
3. Document all exceptions
4. Track compliance verification
5. Update procedures as needed

## Additional Resources

### STIG References
- STIG v-205845: Windows Server 2019 Security Technical Implementation Guide
- AppLocker documentation: https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/applocker/applocker-overview

### PowerShell Commands Reference
```powershell
# Get AppLocker policy
Get-AppLockerPolicy -Effective

# Set AppLocker policy
Set-AppLockerPolicy -XMLPolicy <path> -Merge

# Get AppLocker service status
Get-Service -Name AppIDSvc

# Test AppLocker policy
Test-AppLockerPolicy -XMLPolicy <path> -Path <executable>

# Export current policy
Get-AppLockerPolicy -Effective -Xml | Out-File policy.xml
```

## Support and Questions

For questions or issues:
1. Review this implementation guide
2. Check the troubleshooting section
3. Review AppLocker event logs
4. Consult STIG documentation
5. Contact your Information Security team

---
**Document Version**: 1.0  
**Last Updated**: 2025-12-05  
**Maintained By**: STIG Compliance Team
