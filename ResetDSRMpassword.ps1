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
    2022-01-11
    fix invoke-command
    2022-12-12 
    This version implements the new parameter $checkForPasswordReset and AccountNameFromEvent
    The AccountNameFormEvent is only used if CheckForPasswordReset = $true
    The you can use the 4724 event (Password reset) from a schedule task which is triggered from this event. 
    the schedule task should be create on this template (import)
        <?xml version="1.0" encoding="UTF-16"?>
        <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
            <Triggers>
                <EventTrigger>
                    <Enabled>true</Enabled>
                    <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Security"&gt;&lt;Select Path="Security"&gt;*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4724]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    	            <ValueQueries>
		                <Value name="TargetUserName">Event/EventData/Data[@Name='TargetUserName']</Value>
    	            </ValueQueries>
	            </EventTrigger>
            </Triggers>
            <Exec>
                <Command>powershell.exe</Command>
                    <Arguments>-NoLogo -ExecutionPolicy Unrestricted <SCRIPTPATH>\ResetDSRMPassword.ps1 -AccountNameFromEvent $(TargetUserName)</Arguments>
            </Exec>
            </Actions>
        </Task>
    
#>
<#
    script parameters
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string] $DsrmUserName = "DSRMsync",
    
    [Parameter(Mandatory=$false)]
    [bool] $resetSyncUserPassword=$false,
    
    [Parameter(Mandatory=$false)]
    [bool] $CheckForPasswordReset=$false,

    # Is the account name of the user who has changed
    [Parameter(Mandatory=$false)]
    [string]
    $AccountNameFromEvent = ""
       
)

#if the parameter $restSyncUserPassword is true the password will be changed 
if ($resetSyncUserPassword)
{
    Set-ADAccountPassword $user -Reset
}
#2022-12-27 if this script is triggered from a Schedule event (4724) and the acocunt Name fit the $DSRMuser name the script reset the DSRM password otherwise the script exit
# to use this feature the schedule task XML needs to be edited
if (($AccountNameFromEvent -ne $DsrmUserName) -and ($AccountNameFromEvent -ne "")){
    Write-Host "DSRMUser $DSRMUser does not match to $AccountNameFromEvent"
    exit
}
#Region User validation
#20221227 validate the DSRM sync user prerequisites are fullfilled
$oDsrmUser = Get-ADUser $DsrmUserName -Properties Enabled, SmartcardLogonRequired, AccountExpirationDate -WarningAction SilentlyContinue
if ($null -eq $oDsrmUser)
{
    Write-Host "Can not find $DsrUserName please validate the AD account exists"
    Exit
}
if ($oDsrmUser.Enabled -eq $true){
    Write-Host "$DsrmUserName is enabled. DSRM canot be synced from a enabled account"
    Exit
}
if (($null -ne $oDsrmUser.AccountExpirationDate) -and ($oDsrmUser.AccountExpirationDate -lt (Get-Date)))
{
    Write-Host "$DsrmUserName is expired on $($oDsrmUser.AccountExpirationDate)"
    Exit
}
if ($oDsrmUser.SmartcardLogonRequired -eq $true)
{
    Write-Host "$DsrmUserName requires smartcard logon"
    Exit
}
#Endregion
#Reset the password on every domain controller in the domain
Foreach ($DomainController in Get-ADDomainController -Filter *)
{
    if ($DomainController.IsReadOnly -eq $false) #2022-12-13 Ignore readonly domain controllers
    {
        try
        {
            Write-Host "DSRMpassword Reset on $($DomainController.HostName)"
            $ResetBlock = {
                param($userName)
                ntdsutil.exe "SET DSRM PASSWORD", "SYNC FROM DOMAIN ACCOUNT $userName" Q Q
            }
            Invoke-Command -ComputerName $DomainController.HostName -ScriptBlock $ResetBlock -ArgumentList $DsrmUserName
        }
        catch
        {
            Write-Host "Reset on $domainController failed"
        }
    }
}    
