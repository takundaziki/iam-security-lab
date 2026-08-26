# ============================================
# IAM Access Review - iamlab.local
# Identifies privileged, stale, and anomalous access
# ============================================

$Findings = @()
$Today = Get-Date

# --- 1. PRIVILEGED ACCESS ---
$PrivGroups = @("Domain Admins","Enterprise Admins","Admin-Access")

foreach ($Group in $PrivGroups) {
    $Members = Get-ADGroupMember -Identity $Group -Recursive -ErrorAction SilentlyContinue
    foreach ($Member in $Members) {
        $User = Get-ADUser $Member.SamAccountName -Properties LastLogonDate, Department, Title, Description, whenCreated
        $Findings += [PSCustomObject]@{
            Severity    = "High"
            Category    = "Privileged Access"
            Account     = $User.SamAccountName
            Name        = $User.Name
            Department  = $User.Department
            Title       = $User.Title
            Detail      = "Member of $Group"
            LastLogon   = $User.LastLogonDate
            Created     = $User.whenCreated
        }
    }
}

# --- 2. STALE ACCOUNTS ---
# NOTE: known limitation - null LastLogonDate cannot distinguish
# never-authenticated accounts from genuinely dormant ones.
$Cutoff = $Today.AddDays(-90)
$Stale = Get-ADUser -Filter {Enabled -eq $true} -Properties LastLogonDate, Department, whenCreated |
    Where-Object { ($_.LastLogonDate -lt $Cutoff) -or ($_.LastLogonDate -eq $null) }

foreach ($User in $Stale) {
    $Findings += [PSCustomObject]@{
        Severity    = "Medium"
        Category    = "Stale Account"
        Account     = $User.SamAccountName
        Name        = $User.Name
        Department  = $User.Department
        Detail      = "No logon in 90+ days or never used"
        LastLogon   = $User.LastLogonDate
        Created     = $User.whenCreated
    }
}

# --- 3. NON-HUMAN IDENTITIES ---
$SvcAccounts = Get-ADUser -Filter * -SearchBase "OU=ServiceAccounts,DC=iamlab,DC=local" -Properties Description, LastLogonDate, PasswordLastSet, whenCreated

foreach ($Svc in $SvcAccounts) {
    $Groups = (Get-ADPrincipalGroupMembership $Svc.SamAccountName | Where-Object {$_.Name -ne "Domain Users"}).Name -join "; "
    $PwdAge = if ($Svc.PasswordLastSet) { ($Today - $Svc.PasswordLastSet).Days } else { "Unknown" }

    $Findings += [PSCustomObject]@{
        Severity    = "High"
        Category    = "Non-Human Identity"
        Account     = $Svc.SamAccountName
        Name        = $Svc.Name
        Detail      = "Groups: $Groups | Password age: $PwdAge days | $($Svc.Description)"
        LastLogon   = $Svc.LastLogonDate
        Created     = $Svc.whenCreated
    }
}

# --- 4. CROSS-DEPARTMENT ACCUMULATION ---
$AllUsers = Get-ADUser -Filter {Enabled -eq $true} -Properties Department

foreach ($User in $AllUsers) {
    $DeptGroups = (Get-ADPrincipalGroupMembership $User.SamAccountName |
        Where-Object {$_.Name -like "*-Staff"}).Name

    if ($DeptGroups.Count -gt 1) {
        $Findings += [PSCustomObject]@{
            Severity    = "Medium"
            Category    = "Privilege Creep"
            Account     = $User.SamAccountName
            Name        = $User.Name
            Department  = $User.Department
            Detail      = "Member of multiple department groups: $($DeptGroups -join '; ')"
        }
    }
}

# --- OUTPUT ---
$Findings | Export-Csv -Path "C:\iamlab\access-review-findings.csv" -NoTypeInformation

Write-Host ""
Write-Host "=== ACCESS REVIEW COMPLETE ===" -ForegroundColor Cyan
Write-Host "Total findings: $($Findings.Count)" -ForegroundColor Cyan
Write-Host ""
$Findings | Group-Object Severity | Select Name, Count | Format-Table
$Findings | Group-Object Category | Select Name, Count | Format-Table
Write-Host "Report saved to C:\iamlab\access-review-findings.csv" -ForegroundColor Green
