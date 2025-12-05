<#
.SYNOPSIS
    Verifies STIG v-205845 compliance on Windows Server 2019.

.DESCRIPTION
    This script checks whether AppLocker rules are properly configured to prevent
    administrative accounts from using web browsers and email clients.
    
    Verification includes:
    1. AppLocker service status
    2. Presence of deny rules for browsers and email clients
    3. Rules targeting administrative accounts
    4. AppLocker enforcement mode

.NOTES
    Author: STIG Compliance Team
    Version: 1.0
    Date: 2025-12-05
    
    Requirements:
    - Windows Server 2019
    - PowerShell 5.1 or higher
    - Administrative privileges

.EXAMPLE
    .\Verify-STIGCompliance.ps1
    Performs compliance verification and displays results

.EXAMPLE
    .\Verify-STIGCompliance.ps1 -Detailed
    Performs compliance verification with detailed output
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportReport,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = ".\STIG-v205845-Compliance-Report.txt"
)

#Requires -RunAsAdministrator

$script:ComplianceResults = @{
    Overall = $false
    Checks = @()
    Timestamp = Get-Date
}

function Write-ComplianceLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AppLockerServiceStatus {
    Write-ComplianceLog "Checking AppLocker service status..."
    
    $checkResult = @{
        Name = "AppLocker Service Status"
        Status = $false
        Details = ""
    }
    
    try {
        $service = Get-Service -Name AppIDSvc -ErrorAction Stop
        
        if ($service.Status -eq 'Running') {
            Write-ComplianceLog "AppLocker service is running" "SUCCESS"
            $checkResult.Status = $true
            $checkResult.Details = "Service Status: Running, Startup Type: $($service.StartType)"
            
            if ($service.StartType -ne 'Automatic') {
                Write-ComplianceLog "WARNING: AppLocker service is not set to Automatic startup" "WARNING"
                $checkResult.Details += " (Startup type should be Automatic)"
            }
        }
        else {
            Write-ComplianceLog "AppLocker service is not running (Status: $($service.Status))" "ERROR"
            $checkResult.Details = "Service Status: $($service.Status)"
        }
    }
    catch {
        Write-ComplianceLog "AppLocker service not found or inaccessible" "ERROR"
        $checkResult.Details = "Service not found: $_"
    }
    
    $script:ComplianceResults.Checks += $checkResult
    return $checkResult.Status
}

function Test-AppLockerPolicyExists {
    Write-ComplianceLog "Checking for AppLocker policies..."
    
    $checkResult = @{
        Name = "AppLocker Policy Existence"
        Status = $false
        Details = ""
    }
    
    try {
        $policy = Get-AppLockerPolicy -Effective -ErrorAction Stop
        
        if ($null -eq $policy) {
            Write-ComplianceLog "No AppLocker policy found" "ERROR"
            $checkResult.Details = "No effective AppLocker policy"
        }
        else {
            $ruleCollections = $policy.RuleCollections
            if ($ruleCollections.Count -gt 0) {
                Write-ComplianceLog "AppLocker policy found with $($ruleCollections.Count) rule collection(s)" "SUCCESS"
                $checkResult.Status = $true
                $checkResult.Details = "Rule Collections: $($ruleCollections.Count)"
            }
            else {
                Write-ComplianceLog "AppLocker policy exists but has no rule collections" "WARNING"
                $checkResult.Details = "Policy exists but is empty"
            }
        }
    }
    catch {
        Write-ComplianceLog "Failed to retrieve AppLocker policy: $_" "ERROR"
        $checkResult.Details = "Error retrieving policy: $_"
    }
    
    $script:ComplianceResults.Checks += $checkResult
    return $checkResult.Status
}

function Test-BrowserDenyRules {
    Write-ComplianceLog "Checking for browser deny rules targeting administrators..."
    
    $checkResult = @{
        Name = "Browser Deny Rules"
        Status = $false
        Details = ""
    }
    
    try {
        $policy = Get-AppLockerPolicy -Effective -ErrorAction Stop
        $exeRules = $policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq 'Exe' }
        
        if ($null -eq $exeRules) {
            Write-ComplianceLog "No executable rules found in AppLocker policy" "ERROR"
            $checkResult.Details = "No executable rules configured"
            $script:ComplianceResults.Checks += $checkResult
            return $false
        }
        
        # Check for deny rules targeting Administrators (SID: S-1-5-32-544)
        $adminDenyRules = $exeRules | Select-Object -ExpandProperty Rules | 
            Where-Object { 
                $_.Action -eq 'Deny' -and 
                $_.UserOrGroupSid -eq 'S-1-5-32-544'
            }
        
        $browserKeywords = @('browser', 'iexplore', 'msedge', 'chrome', 'firefox', 'opera')
        $browserDenyRules = $adminDenyRules | Where-Object {
            $ruleName = $_.Name.ToLower()
            $browserKeywords | Where-Object { $ruleName -like "*$_*" }
        }
        
        if ($browserDenyRules.Count -gt 0) {
            Write-ComplianceLog "Found $($browserDenyRules.Count) browser deny rule(s) for administrators" "SUCCESS"
            $checkResult.Status = $true
            $checkResult.Details = "Browser deny rules: $($browserDenyRules.Count)"
            
            if ($Detailed) {
                foreach ($rule in $browserDenyRules) {
                    Write-ComplianceLog "  - $($rule.Name)" "INFO"
                }
            }
        }
        else {
            Write-ComplianceLog "No browser deny rules found for administrators" "ERROR"
            $checkResult.Details = "No browser deny rules targeting administrators"
        }
    }
    catch {
        Write-ComplianceLog "Error checking browser deny rules: $_" "ERROR"
        $checkResult.Details = "Error: $_"
    }
    
    $script:ComplianceResults.Checks += $checkResult
    return $checkResult.Status
}

function Test-EmailClientDenyRules {
    Write-ComplianceLog "Checking for email client deny rules targeting administrators..."
    
    $checkResult = @{
        Name = "Email Client Deny Rules"
        Status = $false
        Details = ""
    }
    
    try {
        $policy = Get-AppLockerPolicy -Effective -ErrorAction Stop
        $exeRules = $policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq 'Exe' }
        
        if ($null -eq $exeRules) {
            Write-ComplianceLog "No executable rules found in AppLocker policy" "ERROR"
            $checkResult.Details = "No executable rules configured"
            $script:ComplianceResults.Checks += $checkResult
            return $false
        }
        
        # Check for deny rules targeting Administrators (SID: S-1-5-32-544)
        $adminDenyRules = $exeRules | Select-Object -ExpandProperty Rules | 
            Where-Object { 
                $_.Action -eq 'Deny' -and 
                $_.UserOrGroupSid -eq 'S-1-5-32-544'
            }
        
        $emailKeywords = @('email', 'outlook', 'thunderbird', 'mail')
        $emailDenyRules = $adminDenyRules | Where-Object {
            $ruleName = $_.Name.ToLower()
            $emailKeywords | Where-Object { $ruleName -like "*$_*" }
        }
        
        if ($emailDenyRules.Count -gt 0) {
            Write-ComplianceLog "Found $($emailDenyRules.Count) email client deny rule(s) for administrators" "SUCCESS"
            $checkResult.Status = $true
            $checkResult.Details = "Email client deny rules: $($emailDenyRules.Count)"
            
            if ($Detailed) {
                foreach ($rule in $emailDenyRules) {
                    Write-ComplianceLog "  - $($rule.Name)" "INFO"
                }
            }
        }
        else {
            Write-ComplianceLog "No email client deny rules found for administrators" "ERROR"
            $checkResult.Details = "No email client deny rules targeting administrators"
        }
    }
    catch {
        Write-ComplianceLog "Error checking email client deny rules: $_" "ERROR"
        $checkResult.Details = "Error: $_"
    }
    
    $script:ComplianceResults.Checks += $checkResult
    return $checkResult.Status
}

function Test-EnforcementMode {
    Write-ComplianceLog "Checking AppLocker enforcement mode..."
    
    $checkResult = @{
        Name = "AppLocker Enforcement Mode"
        Status = $false
        Details = ""
    }
    
    try {
        $policy = Get-AppLockerPolicy -Effective -ErrorAction Stop
        $exeRules = $policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq 'Exe' }
        
        if ($null -ne $exeRules) {
            $enforcementMode = $exeRules.EnforcementMode
            
            if ($enforcementMode -eq 'Enabled') {
                Write-ComplianceLog "AppLocker enforcement is enabled for executable rules" "SUCCESS"
                $checkResult.Status = $true
                $checkResult.Details = "Enforcement Mode: Enabled"
            }
            elseif ($enforcementMode -eq 'AuditOnly') {
                Write-ComplianceLog "AppLocker is in AuditOnly mode (not enforcing)" "WARNING"
                $checkResult.Details = "Enforcement Mode: AuditOnly (should be Enabled)"
            }
            else {
                Write-ComplianceLog "AppLocker enforcement is not enabled" "ERROR"
                $checkResult.Details = "Enforcement Mode: $enforcementMode"
            }
        }
        else {
            Write-ComplianceLog "No executable rule collection found" "ERROR"
            $checkResult.Details = "No executable rule collection"
        }
    }
    catch {
        Write-ComplianceLog "Error checking enforcement mode: $_" "ERROR"
        $checkResult.Details = "Error: $_"
    }
    
    $script:ComplianceResults.Checks += $checkResult
    return $checkResult.Status
}

function Export-ComplianceReport {
    param([string]$Path)
    
    $report = @"
STIG v-205845 Compliance Verification Report
=============================================
Generated: $($script:ComplianceResults.Timestamp)

Overall Compliance Status: $(if ($script:ComplianceResults.Overall) { "COMPLIANT" } else { "NON-COMPLIANT" })

Detailed Check Results:
-----------------------
"@
    
    foreach ($check in $script:ComplianceResults.Checks) {
        $report += @"

Check: $($check.Name)
Status: $(if ($check.Status) { "PASS" } else { "FAIL" })
Details: $($check.Details)
"@
    }
    
    $report += @"


Summary:
--------
Total Checks: $($script:ComplianceResults.Checks.Count)
Passed: $($script:ComplianceResults.Checks | Where-Object { $_.Status } | Measure-Object | Select-Object -ExpandProperty Count)
Failed: $($script:ComplianceResults.Checks | Where-Object { -not $_.Status } | Measure-Object | Select-Object -ExpandProperty Count)

Recommendations:
----------------
"@
    
    if (-not $script:ComplianceResults.Overall) {
        $report += @"
1. Run Configure-AppLockerRules.ps1 to create and apply the required AppLocker rules
2. Ensure AppLocker service is running and set to Automatic
3. Verify rules are targeting the correct administrative security groups
4. Test the configuration in a non-production environment first
5. Review AppLocker event logs for any issues
"@
    }
    else {
        $report += @"
System appears to be compliant with STIG v-205845 requirements.
Continue to monitor AppLocker event logs and review configuration regularly.
"@
    }
    
    try {
        $report | Out-File -FilePath $Path -Encoding UTF8 -Force
        Write-ComplianceLog "Compliance report exported to: $Path" "SUCCESS"
    }
    catch {
        Write-ComplianceLog "Failed to export report: $_" "ERROR"
    }
}

# Main execution
Write-ComplianceLog "=========================================================="
Write-ComplianceLog "STIG v-205845 Compliance Verification"
Write-ComplianceLog "Windows Server 2019 - Administrative Account Internet Application Usage"
Write-ComplianceLog "=========================================================="
Write-ComplianceLog ""

# Run all compliance checks
$results = @()
$results += Test-AppLockerServiceStatus
$results += Test-AppLockerPolicyExists
$results += Test-BrowserDenyRules
$results += Test-EmailClientDenyRules
$results += Test-EnforcementMode

# Determine overall compliance
$script:ComplianceResults.Overall = ($results | Where-Object { -not $_ }).Count -eq 0

Write-ComplianceLog ""
Write-ComplianceLog "=========================================================="
if ($script:ComplianceResults.Overall) {
    Write-ComplianceLog "COMPLIANCE STATUS: COMPLIANT" "SUCCESS"
    Write-ComplianceLog "All checks passed. System is compliant with STIG v-205845." "SUCCESS"
}
else {
    Write-ComplianceLog "COMPLIANCE STATUS: NON-COMPLIANT" "ERROR"
    $failedChecks = $script:ComplianceResults.Checks | Where-Object { -not $_.Status }
    Write-ComplianceLog "Failed checks: $($failedChecks.Count) out of $($script:ComplianceResults.Checks.Count)" "ERROR"
    Write-ComplianceLog ""
    Write-ComplianceLog "To remediate, run: .\Configure-AppLockerRules.ps1" "INFO"
}
Write-ComplianceLog "=========================================================="

# Export report if requested
if ($ExportReport) {
    Export-ComplianceReport -Path $ReportPath
}

# Exit with appropriate code
exit $(if ($script:ComplianceResults.Overall) { 0 } else { 1 })
