# STIG v-205845 Quick Reference

## One-Page Implementation Summary

### What is STIG v-205845?
A security requirement that prohibits administrative accounts from using Internet-accessible applications (browsers, email clients) on Windows Server 2019.

### Why is this important?
- Reduces attack surface for privileged accounts
- Prevents malware installation with admin rights
- Mitigates phishing risks for administrators
- Enforces separation of duties principle

---

## Quick Implementation (Local Server)

```powershell
# 1. Create restore point
Checkpoint-Computer -Description "Before STIG v-205845" -RestorePointType "MODIFY_SETTINGS"

# 2. Apply configuration
.\Configure-AppLockerRules.ps1 -Verbose

# 3. Verify compliance
.\Verify-STIGCompliance.ps1 -Detailed
```

---

## Quick Implementation (Domain via GPO)

```powershell
# 1. Generate policy XML
.\Configure-AppLockerRules.ps1 -WhatIf

# 2. In GPMC:
#    - Create new GPO: "STIG v-205845 - Admin Restrictions"
#    - Navigate to: Computer Config > Policies > Windows Settings > 
#                   Security Settings > Application Control Policies > AppLocker
#    - Right-click Executable Rules > Import Policy
#    - Select: AppLocker-STIG-v205845-Policy.xml
#    - Set enforcement to "Enforce rules"
#    - Link GPO to appropriate OUs

# 3. Verify on test system
gpupdate /force
.\Verify-STIGCompliance.ps1 -Detailed
```

---

## What Gets Blocked?

### Browsers
- Internet Explorer
- Microsoft Edge  
- Chrome
- Firefox
- Opera

### Email Clients
- Outlook
- Thunderbird
- Windows Mail

### Who is blocked?
Only accounts in the **Administrators** group (local or domain)

---

## Verification Commands

```powershell
# Check AppLocker service
Get-Service -Name AppIDSvc

# Check effective policy
Get-AppLockerPolicy -Effective

# View blocked attempts
Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" | 
    Where-Object { $_.Id -eq 8004 } | Select-Object -First 10

# Run compliance check
.\Verify-STIGCompliance.ps1 -ExportReport
```

---

## Emergency Rollback

```powershell
# Stop AppLocker enforcement immediately
Stop-Service -Name AppIDSvc
Set-Service -Name AppIDSvc -StartupType Manual

# OR in GPO: Disable the GPO link
```

---

## Exception Process

1. Submit formal request with business justification
2. Get ISSO/ISSM approval
3. Document in policy
4. Create allow rule for specific application
5. Review annually

---

## Files in This Repository

| File | Purpose |
|------|---------|
| `README.md` | Complete overview and documentation |
| `ADMINISTRATIVE_ACCOUNT_POLICY.md` | Formal policy document |
| `IMPLEMENTATION_GUIDE.md` | Detailed step-by-step guide |
| `Configure-AppLockerRules.ps1` | Configuration script |
| `Verify-STIGCompliance.ps1` | Compliance verification script |
| `QUICK_REFERENCE.md` | This file - quick reference |

---

## Common Issues

### Issue: Rules not applying
```powershell
gpupdate /force
gpresult /h gpresult.html
```

### Issue: Service won't start
```powershell
Start-Service -Name AppIDSvc -Verbose
```

### Issue: Need to test without enforcing
Use `-WhatIf` parameter or set GPO to "Audit only" mode

---

## Support

1. Review `IMPLEMENTATION_GUIDE.md` for detailed help
2. Check AppLocker event logs
3. Review STIG documentation
4. Contact Information Security team

---

**Quick Compliance Check**: Run `.\Verify-STIGCompliance.ps1`  
**Emergency Contact**: Your Information Security Officer  
**Document Version**: 1.0 | **Last Updated**: 2025-12-05
