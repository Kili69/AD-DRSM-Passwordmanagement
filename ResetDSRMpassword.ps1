<#
Script Info

Author: Andreas Lucas [MSFT]
Download: https://github.com/Kili69/AD-DRSM-Passwordmanagement

Disclaimer:
This sample script is not supported under any Microsoft standard support program or service. 
The sample script is provided AS IS without warranty of any kind. Microsoft further disclaims 
all implied warranties including, without limitation, any implied warranties of merchantability 
or of fitness for a particular purpose. The entire risk arising out of the use or performance of 
the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, 
or anyone else involved in the creation, production, or delivery of the scripts be liable for any 
damages whatsoever (including, without limitation, damages for loss of business profits, business 
interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
inability to use the sample scripts or documentation, even if Microsoft has been advised of the 
possibility of such damages
#>
<#
.Synopsis
    This script sync the DSRM Password for Active Directory from a user

.DESCRIPTION
    Active Directory provides a functionality to sync the password from a disabled user as the DSRM password on every 
    domain controller in the active directory
    This script automate the procedure if you run the script as a schedule task on domain controllers. The default
    user name is DSRMsync from the current directory

.EXAMPLE
    .\ResetDSRMpassword.ps1
        reset the password from the synced account

    .\ResetDSRMpassword.ps1 -DsrmUserName "MyUser"
        sync the password from the user acocunt MyUser as DSRM password on every DC
    
    .\ResetDSRMpassword.ps1 -DsrmUserName "MyUser" -resetSyncUserPassword $true
        Interactive script execution: Reset the password for the Myuser account and sync the
        password afterwards to every domain controller

.INPUTS
    -UserName
        The user SamAccount name, to sync the password from
    

.OUTPUTS
   none
.NOTES
    Version Tracking
    2021-10-29
    Initial Version available on GitHub
    2021-12-20
    fix command line
#>
<#
    script parameters
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string] $DsrmUserName = "DSRMsync",
    
    [Parameter(Mandatory=$false)]
    [bool] $resetSyncUserPassword=$false

    
)

#if the parameter $restSyncUserPassword is true the password will be changed 
if ($resetSyncUserPassword)
{
    Set-ADAccountPassword $user -Reset
}
#Reset the password on every domain controller in the domain
Foreach ($DomainController in (Get-ADDomainController).Hostname)
{
    try
    {
        Write-Host "DSRMpassword Reset on " $DomainController
        Invoke-Command -ScriptBlock {& NTDSUTIL.EXE -ArgumentList "SET DSRM PASSWORD", "SYNC FROM DOMAIN ACCOUNT $DSRMUserName", "Q", "Q"}
    }
    catch
    {
        Write-Host "Reset on $domainController failed"
    }
}    
