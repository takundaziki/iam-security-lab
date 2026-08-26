# ============================================
# Bulk user provisioning from CSV
# Simulates HR-driven joiner process
# ============================================

$Password = ConvertTo-SecureString "LabPass123!" -AsPlainText -Force
$Users = Import-Csv C:\iamlab\users.csv

foreach ($User in $Users) {
    $OU  = "OU=$($User.Department),DC=iamlab,DC=local"
    $UPN = "$($User.Username)@iamlab.local"

    New-ADUser -Name "$($User.FirstName) $($User.LastName)" `
        -GivenName $User.FirstName -Surname $User.LastName `
        -SamAccountName $User.Username -UserPrincipalName $UPN `
        -Title $User.Title -Department $User.Department `
        -Path $OU -AccountPassword $Password `
        -Enabled $true -PasswordNeverExpires $true

    if ($User.Department -ne "Contractors") {
        Add-ADGroupMember -Identity "$($User.Department)-Staff" -Members $User.Username
    }

    Write-Host "Created $($User.Username) in $($User.Department)" -ForegroundColor Green
}
