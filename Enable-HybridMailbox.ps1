####################################
# Enable-HybridMailbox
# Enables a mailbox created in Exchange Online to work with On-prem Exchange in hybrid mode
# 
# Usage: Enable-HybridMailbox -Username <username>
#
# Be sure to change $Domain, $365Domain, $ExchangeServer, and $AADConnectServer to match your environment
#
# Created on: 2022/03/10
# Written by: Bert Mills
# Thanks to Tim Carmichael for assistance with necessary commands
####################################


param (
    [Parameter(Mandatory=$true)]
    [String]$Username,
    [Parameter(Mandatory=$false)]
    [string]$Domain = "DOMAIN.TLD", #Replace DOMAIN.TLD with your email domain. Example: contoso.com
    [Parameter(Mandatory=$false)]
    [string]$365Domain = "DOMAIN.mail.onmicrosoft.com", #Replace with your Microsoft 365 Exchange Online domain, which probably ends with .mail.onmicrosoft.com.  Example: contoso.mail.onmicrosoft.com
    [Parameter(Mandatory=$false)]
    [string]$ExchangeServer="EXCHANGESERVERNAME", #Replace with the name of an on-prem Exchange server
    [Parameter(Mandatory=$false)]
    [string]$AADConnectServer="AADCONNECTSERVERNAME", #Replace withe the name of your on-prem Azure AD Connect server
    [Parameter(Mandatory=$false)]
    [string]$AADSyncPolicyType="Delta" #Determines if you need to do a Delta or Full Azure AD Sync.  Not sure why you would need to use anything but Delta, but it's here just in case.
)

#Check and Import Modules
$ModuleCheck = Get-Module -Name ActiveDirectory -ListAvailable
if ($ModuleCheck) {
    Import-Module ActiveDirectory
} else {
    Write-Error "Active Directory PowerShell module is required on local workstation."
    exit
}

#Create PSSession to Exchange Server so Exchange tools are not required on local workstation
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/PowerShell/ -Authentication Kerberos
Write-Host "Importing Exchange PowerShell session from $ExchangeServer"
Import-PSSession $Session -DisableNameChecking

#Enable Exchange Online mailbox in on-prem Exchange
Write-Host "Enabling $Username@$Domain as a hybrid mailbox"
Enable-MailUser -Identity $Username@$Domain -ExternalEmailAddress $Username@$365Domain | ft Name,RecipientType
Enable-RemoteMailbox $Username@$Domain | ft Name,RecipientTypeDetails,RemoteRecipientType

#Close PSSession to Exchange Server
Write-Host "Exiting Exchange PowerShell session"
Remove-PSSession $Session

#Replicate Active Directory - Note: depending on your AD Replication Topology, this may not replicate every object to every DC.  Sometimes duplicating this section to run twice would do the trick.
Write-Host "Replicating local AD domain"
(Get-ADDomainController -Filter *).Name | ForEach-Object {repadmin /syncall $_ (Get-ADDomain).DistinguishedName /e /A | Out-Null}
#Wait
Start-Sleep 10
#Check status for curren domain and report
Get-ADReplicationPartnerMetadata -Target "$env:USERDNSDOMAIN" -Scope Domain | Select-Object Server, LastReplicationSuccess

#Replicate Azure AD Connect
Write-Host ""
Write-Host "Intializing Azure AD Connect Sync"
Invoke-Command -ComputerName $AADConnectServer -ScriptBlock {Start-ADSyncSyncCycle -PolicyType $AADSyncPolicyType}
