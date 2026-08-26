# ============================================
# IAM Offboarding - iamlab.local
# Usage: .\offboard-user.ps1 -Username jweber
#        .\offboard-user.ps1 -Username jweber -WhatIf
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,
    [switch]$WhatIf
)

$LogPath = "C:\iamlab\offboarding-log.csv"
$Log = @()

# Verify the account exists before doing anything
try {
    $User = Get-ADUser $Username -Properties MemberOf, Department, Title
} catch {
    Write-Host "ERROR: Account '$Username' not found." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "OFFBOARDING: $($User.Name) ($Username)" -ForegroundColor Cyan
Write-Host "Department: $($User.Department) | Title: $($User.Title)"
if ($WhatIf) { Write-Host "*** DRY RUN - no changes will be made ***" -ForegroundColor Yellow }
Write-Host ""

# --- 1. CAPTURE STATE BEFORE CHANGES ---
# Membership must be recorded before removal - once stripped, it is unrecoverable.
$GroupsBefore = (Get-ADPrincipalGroupMembership $Username).Name
Write-Host "Current group memberships:" -ForegroundColor White
$GroupsBefore | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

# --- 2. DISABLE ACCOUNT ---
# Authentication is stopped first, closing the window in which a
# partially-deprovisioned account could still be used.
if (-not $WhatIf) {
    Disable-ADAccount -Identity $Username
}
Write-Host "[1] Account disabled" -ForegroundColor Green

# --- 3. REMOVE GROUP MEMBERSHIPS ---
$Groups = Get-ADPrincipalGroupMembership $Username | Where-Object { $_.Name -ne "Domain Users" }

foreach ($Group in $Groups) {
    if (-not $WhatIf) {
        Remove-ADGroupMember -Identity $Group.Name -Members $Username -Confirm:$false
    }
    Write-Host "[2] Removed from: $($Group.Name)" -ForegroundColor Yellow

    $Log += [PSCustomObject]@{
        Timestamp   = Get-Date
        Account     = $Username
        Name        = $User.Name
        Action      = "Group removed"
        Detail      = $Group.Name
        DryRun      = $WhatIf
    }
}

# --- 4. RECORD WHY, ON THE ACCOUNT ITSELF ---
$Removed = ($GroupsBefore | Where-Object { $_ -ne "Domain Users" }) -join '; '
$Stamp = "Offboarded $(Get-Date -Format 'yyyy-MM-dd') | Groups removed: $Removed"
if (-not $WhatIf) {
    Set-ADUser -Identity $Username -Description $Stamp
}
Write-Host "[3] Description stamped with offboarding record" -ForegroundColor Green

# --- 5. MOVE TO DISABLED OU ---
# The account is moved, not deleted. Deletion destroys the SID, orphaning
# every permission that references it and breaking the audit trail.
$DisabledOU = "OU=DisabledUsers,DC=iamlab,DC=local"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'DisabledUsers'")) {
    if (-not $WhatIf) {
        New-ADOrganizationalUnit -Name "DisabledUsers" -Path "DC=iamlab,DC=local"
    }
    Write-Host "[4] Created DisabledUsers OU" -ForegroundColor Green
}
if (-not $WhatIf) {
    Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledOU
}
Write-Host "[4] Moved to DisabledUsers OU" -ForegroundColor Green

# --- 6. AUDIT LOG ---
$Log += [PSCustomObject]@{
    Timestamp = Get-Date
    Account   = $Username
    Name      = $User.Name
    Action    = "Offboarding completed"
    Detail    = "Disabled, groups stripped, moved to DisabledUsers"
    DryRun    = $WhatIf
}

if (-not $WhatIf) {
    $Log | Export-Csv -Path $LogPath -NoTypeInformation -Append
}

Write-Host ""
Write-Host "OFFBOARDING COMPLETE for $Username" -ForegroundColor Cyan
Write-Host ""
