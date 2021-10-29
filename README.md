# AD-DRSM-Passwordmanagement 
AD-DSRM-Passwordmanagement is used to sync the DSRM password on every domain controller in the domain from a singele account.
The script can run interactive with reset of the user password or non-interactive where password is automatically synced from the account. 
The sync user DSRM account name is by default DSRMSync, wich can be overwritten by the DsrmUserName Parameter

#Thank you
The script is based on the idea of Ned Pyle blog https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/ds-restore-mode-password-maintenance/ba-p/396102 
and https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/reset-directory-services-restore-mode-admin-pwd


#Warning
the DSRM sync user is a Tier 0 critical user. Take care only domain administrators are able to reset the password. 
