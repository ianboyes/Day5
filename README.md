# Day5 - STIG v-205845 Implementation

## Overview
This repository contains the implementation for STIG v-205845 compliance on Windows Server 2019 systems. The implementation establishes and enforces a policy to prohibit administrative accounts from using applications that access the Internet, such as web browsers and email clients.

## STIG Requirement
**STIG ID**: v-205845  
**Severity**: Category II  
**Requirement**: Establish a policy, at minimum, to prohibit administrative accounts from using applications that access the Internet, such as web browsers, or with potential Internet sources, such as email. Ensure the policy is enforced.

## Repository Contents

### Policy Documentation
- **ADMINISTRATIVE_ACCOUNT_POLICY.md** - Formal policy document defining restrictions and requirements
- **IMPLEMENTATION_GUIDE.md** - Comprehensive step-by-step implementation guide

### PowerShell Scripts
- **Configure-AppLockerRules.ps1** - Automated script to configure AppLocker rules for enforcement
- **Verify-STIGCompliance.ps1** - Verification script to check compliance status

## Quick Start

### Prerequisites
- Windows Server 2019
- PowerShell 5.1 or higher
- Administrative privileges
- AppLocker feature (included in Windows Server 2019)

### Implementation Steps

1. **Review the Policy**
   ```powershell
   Get-Content .\ADMINISTRATIVE_ACCOUNT_POLICY.md
   ```

2. **Read the Implementation Guide**
   ```powershell
   Get-Content .\IMPLEMENTATION_GUIDE.md
   ```

3. **Configure AppLocker Rules**
   ```powershell
   # Test first (see what would happen)
   .\Configure-AppLockerRules.ps1 -WhatIf
   
   # Apply the configuration
   .\Configure-AppLockerRules.ps1 -Verbose
   ```

4. **Verify Compliance**
   ```powershell
   .\Verify-STIGCompliance.ps1 -Detailed
   ```

## What This Implementation Does

### Technical Controls
The implementation uses AppLocker to enforce the following restrictions for administrative accounts:

#### Blocked Web Browsers
- Internet Explorer
- Microsoft Edge
- Google Chrome
- Mozilla Firefox
- Opera

#### Blocked Email Clients
- Microsoft Outlook
- Mozilla Thunderbird
- Windows Mail

### How It Works
1. Creates AppLocker deny rules targeting the Administrators security group (SID: S-1-5-32-544)
2. Blocks execution of browser and email client executables
3. Configures AppLocker service to start automatically
4. Generates XML policy file for Group Policy deployment

## Deployment Options

### Option 1: Local Implementation
Apply to a single server using the PowerShell script:
```powershell
.\Configure-AppLockerRules.ps1
```

### Option 2: Group Policy Deployment
For domain-wide deployment:
1. Run the script with `-WhatIf` to generate the policy XML
2. Import the XML into a Group Policy Object
3. Link the GPO to appropriate OUs
4. See `IMPLEMENTATION_GUIDE.md` for detailed steps

## Verification

### Automated Verification
```powershell
# Basic compliance check
.\Verify-STIGCompliance.ps1

# Detailed check with report
.\Verify-STIGCompliance.ps1 -Detailed -ExportReport
```

### Manual Testing
1. Log in as an administrator
2. Attempt to open a web browser (e.g., Edge, Chrome)
3. Attempt to open Outlook or other email client
4. Applications should be blocked with an error message

### Check AppLocker Logs
```powershell
Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 20
```

## Important Notes

### Before Implementation
- ⚠️ **Test in a non-production environment first**
- ⚠️ **Create a system restore point or backup**
- ⚠️ **Review the policy and customize for your organization**
- ⚠️ **Notify administrative staff before deployment**
- ⚠️ **Establish an exception process**

### After Implementation
- Monitor AppLocker event logs for blocked applications
- Review and approve exception requests
- Document all exceptions with business justification
- Regularly verify compliance using the verification script
- Update rules when new applications are approved

## Exception Process
If administrative users need access to Internet applications for legitimate business purposes:
1. Submit a formal exception request
2. Provide business justification
3. Obtain approval from Information Security Officer
4. Document the exception in the policy
5. Implement compensating controls if needed
6. Review exceptions annually

## Troubleshooting

### AppLocker Service Won't Start
```powershell
Start-Service -Name AppIDSvc -Verbose
Set-Service -Name AppIDSvc -StartupType Automatic
```

### Rules Not Applying
```powershell
# Force group policy update
gpupdate /force

# Check effective policy
Get-AppLockerPolicy -Effective
```

### Need to Rollback
```powershell
# Disable AppLocker rules (emergency only)
Stop-Service -Name AppIDSvc
Set-Service -Name AppIDSvc -StartupType Manual
```

See `IMPLEMENTATION_GUIDE.md` for detailed troubleshooting steps.

## Compliance Verification

The verification script checks:
- ✅ AppLocker service is running and set to Automatic
- ✅ AppLocker policy exists and is configured
- ✅ Browser deny rules target administrators
- ✅ Email client deny rules target administrators
- ✅ Enforcement mode is enabled (not just audit)

## Security Considerations

### Why This Matters
Administrative accounts have elevated privileges. If compromised through Internet applications:
- Malware can be installed with administrative rights
- Entire systems or domains can be compromised
- Data exfiltration is easier
- Phishing attacks are more dangerous

### Defense in Depth
This control is part of a defense-in-depth strategy:
- Reduces attack surface for privileged accounts
- Prevents accidental malware installation
- Mitigates phishing risks for administrators
- Enforces separation of duties

## Files Generated

After running the configuration script:
- `AppLocker-STIG-v205845-Policy.xml` - AppLocker policy file (can be imported to GPO)

After running the verification script with `-ExportReport`:
- `STIG-v205845-Compliance-Report.txt` - Compliance verification report

## Support and Documentation

- **Policy Document**: `ADMINISTRATIVE_ACCOUNT_POLICY.md`
- **Implementation Guide**: `IMPLEMENTATION_GUIDE.md`
- **Configuration Script**: `Configure-AppLockerRules.ps1`
- **Verification Script**: `Verify-STIGCompliance.ps1`

## Contributing
If you find issues or have improvements:
1. Document the issue or enhancement
2. Test thoroughly in a lab environment
3. Submit changes with clear documentation
4. Ensure compliance with STIG requirements

## License
This implementation is provided as-is for STIG compliance purposes.

## References
- Windows Server 2019 Security Technical Implementation Guide (STIG)
- STIG v-205845: Administrative Account Internet Application Usage
- Microsoft AppLocker Documentation
- NIST SP 800-53 Rev 5

---
**Version**: 1.0  
**Last Updated**: 2025-12-05  
**Status**: Production Ready