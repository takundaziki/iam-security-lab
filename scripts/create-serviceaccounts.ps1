# ============================================
# Non-human identity provisioning
# Service accounts are created with ownership metadata in the
# Description field. In most environments this is the only record
# of why an account exists - empty descriptions are themselves a finding.
# ============================================

$Password = ConvertTo-SecureString "SvcPass123!" -AsPlainText -Force
$OU = "OU=ServiceAccounts,DC=iamlab,DC=local"

New-ADUser -Name "svc-backup" -SamAccountName "svc-backup" `
    -UserPrincipalName "svc-backup@iamlab.local" `
    -Description "Nightly backup job - created 2019 by IT (owner left company)" `
    -Path $OU -AccountPassword $Password `
    -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "Domain Admins" -Members "svc-backup"

New-ADUser -Name "svc-sharepoint" -SamAccountName "svc-sharepoint" `
    -UserPrincipalName "svc-sharepoint@iamlab.local" `
    -Description "SharePoint 2016 integration - project decommissioned 2023" `
    -Path $OU -AccountPassword $Password `
    -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "Admin-Access" -Members "svc-sharepoint"
Add-ADGroupMember -Identity "Finance-Staff" -Members "svc-sharepoint"

Write-Host "Service accounts created" -ForegroundColor Green
