<#
.SYNOPSIS
    Configures AppLocker rules to enforce STIG v-205845 requirements.

.DESCRIPTION
    This script creates AppLocker rules to block administrative accounts from using
    web browsers and email clients on Windows Server 2019, in compliance with STIG v-205845.
    
    The script will:
    1. Enable AppLocker service
    2. Create deny rules for browsers and email clients for administrative accounts
    3. Configure AppLocker to start automatically

.NOTES
    Author: STIG Compliance Team
    Version: 1.0
    Date: 2025-12-05
    
    Requirements:
    - Windows Server 2019
    - PowerShell 5.1 or higher
    - Administrative privileges
    - AppLocker feature must be available

.EXAMPLE
    .\Configure-AppLockerRules.ps1
    Configures AppLocker rules with default settings

.EXAMPLE
    .\Configure-AppLockerRules.ps1 -WhatIf
    Shows what would happen without making changes
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$AdministrativeGroups = @("BUILTIN\Administrators", "BUILTIN\Domain Admins"),
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Requires running as Administrator
#Requires -RunAsAdministrator

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Test-AppLockerAvailability {
    try {
        $service = Get-Service -Name AppIDSvc -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "AppLocker service not found. Ensure AppLocker is available on this system." "ERROR"
        return $false
    }
}

function Enable-AppLockerService {
    Write-Log "Configuring AppLocker service..."
    
    if ($PSCmdlet.ShouldProcess("AppIDSvc", "Start and set to Automatic")) {
        try {
            Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction Stop
            Start-Service -Name AppIDSvc -ErrorAction Stop
            Write-Log "AppLocker service enabled and started successfully." "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to enable AppLocker service: $_" "ERROR"
            return $false
        }
    }
    return $true
}

function New-BrowserDenyRules {
    Write-Log "Creating deny rules for web browsers..."
    
    $browserPaths = @(
        "%ProgramFiles%\Internet Explorer\iexplore.exe",
        "%ProgramFiles(x86)%\Internet Explorer\iexplore.exe",
        "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe",
        "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe",
        "%ProgramFiles%\Google\Chrome\Application\chrome.exe",
        "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe",
        "%ProgramFiles%\Mozilla Firefox\firefox.exe",
        "%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe",
        "%ProgramFiles%\Opera\launcher.exe",
        "%ProgramFiles(x86)%\Opera\launcher.exe"
    )
    
    $rules = @()
    foreach ($path in $browserPaths) {
        $ruleName = "STIG v-205845: Block Browser - $path"
        Write-Log "Creating rule: $ruleName"
        
        # Create a deny rule for administrative accounts
        # Note: In production, you would create these rules and apply them via GPO
        # targeting specific administrative security groups
        $rules += @{
            Name = $ruleName
            Path = $path
            Action = "Deny"
            Type = "Browser"
        }
    }
    
    return $rules
}

function New-EmailClientDenyRules {
    Write-Log "Creating deny rules for email clients..."
    
    $emailPaths = @(
        "%ProgramFiles%\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "%ProgramFiles(x86)%\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "%ProgramFiles%\Microsoft Office\Office16\OUTLOOK.EXE",
        "%ProgramFiles(x86)%\Microsoft Office\Office16\OUTLOOK.EXE",
        "%ProgramFiles%\Mozilla Thunderbird\thunderbird.exe",
        "%ProgramFiles(x86)%\Mozilla Thunderbird\thunderbird.exe",
        "%SystemRoot%\System32\wab.exe",
        "%SystemRoot%\SysWOW64\wab.exe"
    )
    
    $rules = @()
    foreach ($path in $emailPaths) {
        $ruleName = "STIG v-205845: Block Email Client - $path"
        Write-Log "Creating rule: $ruleName"
        
        $rules += @{
            Name = $ruleName
            Path = $path
            Action = "Deny"
            Type = "EmailClient"
        }
    }
    
    return $rules
}

function Export-AppLockerPolicyXML {
    param(
        [Parameter(Mandatory=$true)]
        [array]$BrowserRules,
        
        [Parameter(Mandatory=$true)]
        [array]$EmailRules,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath = ".\AppLocker-STIG-v205845-Policy.xml"
    )
    
    Write-Log "Generating AppLocker policy XML..."
    
    # Create XML policy structure
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<AppLockerPolicy Version="1">
    <RuleCollection Type="Exe" EnforcementMode="Enabled">
        <!-- Default allow rule for Everyone to run executables from Program Files -->
        <FilePathRule Id="$(New-Guid)" Name="Allow Everyone - Program Files" Description="Allows Everyone to run applications from Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
            <Conditions>
                <FilePathCondition Path="%ProgramFiles%\*" />
            </Conditions>
        </FilePathRule>
        <FilePathRule Id="$(New-Guid)" Name="Allow Everyone - Windows" Description="Allows Everyone to run applications from Windows folder" UserOrGroupSid="S-1-1-0" Action="Allow">
            <Conditions>
                <FilePathCondition Path="%WINDIR%\*" />
            </Conditions>
        </FilePathRule>
"@
    
    # Add browser deny rules for Administrators
    foreach ($rule in $BrowserRules) {
        $guid = New-Guid
        $xml += @"

        <FilePathRule Id="$guid" Name="$($rule.Name)" Description="STIG v-205845: Deny administrative accounts from using browsers" UserOrGroupSid="S-1-5-32-544" Action="Deny">
            <Conditions>
                <FilePathCondition Path="$($rule.Path)" />
            </Conditions>
        </FilePathRule>
"@
    }
    
    # Add email client deny rules for Administrators
    foreach ($rule in $EmailRules) {
        $guid = New-Guid
        $xml += @"

        <FilePathRule Id="$guid" Name="$($rule.Name)" Description="STIG v-205845: Deny administrative accounts from using email clients" UserOrGroupSid="S-1-5-32-544" Action="Deny">
            <Conditions>
                <FilePathCondition Path="$($rule.Path)" />
            </Conditions>
        </FilePathRule>
"@
    }
    
    # Close XML structure
    $xml += @"

    </RuleCollection>
</AppLockerPolicy>
"@
    
    if ($PSCmdlet.ShouldProcess($OutputPath, "Export AppLocker policy XML")) {
        try {
            $xml | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
            Write-Log "AppLocker policy XML exported to: $OutputPath" "SUCCESS"
            return $OutputPath
        }
        catch {
            Write-Log "Failed to export policy XML: $_" "ERROR"
            return $null
        }
    }
    
    return $OutputPath
}

function Set-AppLockerPolicyFromXML {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PolicyXMLPath
    )
    
    if (-not (Test-Path $PolicyXMLPath)) {
        Write-Log "Policy XML file not found: $PolicyXMLPath" "ERROR"
        return $false
    }
    
    if ($PSCmdlet.ShouldProcess("Local AppLocker Policy", "Import and apply policy from $PolicyXMLPath")) {
        try {
            Set-AppLockerPolicy -XMLPolicy $PolicyXMLPath -Merge -ErrorAction Stop
            Write-Log "AppLocker policy applied successfully." "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to apply AppLocker policy: $_" "ERROR"
            return $false
        }
    }
    
    return $true
}

# Main execution
try {
    Write-Log "Starting AppLocker configuration for STIG v-205845 compliance..."
    Write-Log "=========================================================="
    
    # Check if AppLocker is available
    if (-not (Test-AppLockerAvailability)) {
        Write-Log "AppLocker is not available on this system. Exiting." "ERROR"
        exit 1
    }
    
    # Enable AppLocker service
    if (-not (Enable-AppLockerService)) {
        Write-Log "Failed to enable AppLocker service. Exiting." "ERROR"
        exit 1
    }
    
    # Create deny rules
    $browserRules = New-BrowserDenyRules
    $emailRules = New-EmailClientDenyRules
    
    Write-Log "Created $($browserRules.Count) browser deny rules"
    Write-Log "Created $($emailRules.Count) email client deny rules"
    
    # Export policy to XML
    $policyPath = Export-AppLockerPolicyXML -BrowserRules $browserRules -EmailRules $emailRules
    
    if ($null -eq $policyPath) {
        Write-Log "Failed to export AppLocker policy. Exiting." "ERROR"
        exit 1
    }
    
    # Apply the policy
    if ($Force -or $PSCmdlet.ShouldContinue("Apply the AppLocker policy to this system?", "Confirm Policy Application")) {
        if (Set-AppLockerPolicyFromXML -PolicyXMLPath $policyPath) {
            Write-Log "=========================================================="
            Write-Log "AppLocker configuration completed successfully!" "SUCCESS"
            Write-Log "Policy file saved to: $policyPath"
            Write-Log ""
            Write-Log "IMPORTANT NOTES:"
            Write-Log "1. The policy has been applied locally"
            Write-Log "2. For domain-wide enforcement, import this policy into a GPO"
            Write-Log "3. Test thoroughly before deploying to production"
            Write-Log "4. Review AppLocker event logs for any issues"
            Write-Log "=========================================================="
        }
    }
    else {
        Write-Log "Policy application cancelled by user." "WARNING"
        Write-Log "Policy XML file created at: $policyPath"
        Write-Log "You can apply it later using: Set-AppLockerPolicy -XMLPolicy $policyPath -Merge"
    }
}
catch {
    Write-Log "An error occurred during execution: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
}
