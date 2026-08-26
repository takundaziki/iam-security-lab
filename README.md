# IAM Security Lab — Active Directory & Entra ID

A hands-on identity and access management lab simulating a small enterprise. Built to practise the full identity lifecycle: provisioning, access review, remediation, and deprovisioning and to document the reasoning behind each control, not just the configuration.

**Built by:** Takunda Z· **Completed:** August 2026

---

## Environment

**On-premises:** Windows Server 2022 domain controller (`IAMLAB-DC01`), forest `iamlab.local`, running on VirtualBox.

| Component | Detail |
|---|---|
| Organisational Units | IT, Finance, HR, Sales, Contractors, ServiceAccounts |
| Security groups | 4 department groups, plus `VPN-Access` and `Admin-Access` as cross-cutting entitlements |
| Identities | 12 user accounts, 2 service accounts |

**Cloud:** Microsoft Entra ID tenant with users and groups mirroring the on-premises structure. Cloud scope was limited to free-tier capabilities — see [Limitations](docs/05-limitations.md).

---

## What I built

| Script | Purpose |
|---|---|
| `create-users.ps1` | Bulk provisioning from CSV, simulating an HR-driven joiner process |
| `create-serviceaccounts.ps1` | Non-human identity creation with ownership metadata |
| `access-review.ps1` | Detects privileged access, dormant accounts, overprivileged service accounts, and cross-department privilege creep |
| `offboard-user.ps1` | Leaver process with dry-run mode, state capture, and audit logging |

---

## Access review findings

The environment was seeded with realistic misconfigurations, then assessed.

| # | Severity | Finding | Outcome |
|---|---|---|---|
| 1 | Critical | Sales user held `Domain Admins` | Removed |
| 2 | Critical | `svc-backup` holds `Domain Admins`; owner has left the organisation | **Risk accepted** pending owner identification and dependency mapping |
| 3 | High | `svc-sharepoint` orphaned — project decommissioned 2023, account still enabled with Finance and admin access | Access stripped, account disabled |
| 4 | High | Contractor held `Admin-Access` | Offboarded |
| 5 | Medium | User retained access to two departments after an internal move | Redundant group removed |
| 6 | Medium | Contractor held `VPN-Access` | Offboarded |

**Total findings: 24 → 17 after remediation.**

Finding 2 was deliberately not remediated. Revoking rights from a service account without knowing its dependencies risks breaking production processes the correct action is to identify an owner and map dependencies first, not to remove access immediately.

### Password policy assessment

| Setting | Value | Assessment |
|---|---|---|
| Lockout threshold | 0 (disabled) | **Critical** — unlimited authentication attempts, no protection against password spraying |
| Minimum length | 7 | Weak — below current guidance |
| Maximum age | 42 days | Forced expiry is no longer recommended by NCSC; it drives predictable password patterns |
| Complexity | Enabled | Acceptable |
| History | 24 | Acceptable |

---

## What went wrong

**The access review over-reported by 58%.** The initial run returned 24 findings, of which 14 were false positives. The dormancy check treated a null `LastLogonDate` as evidence of an abandoned account but accounts that have never authenticated are indistinguishable from dormant ones using that attribute alone. In a production environment this would flood a report with noise and destroy its credibility with the business.

**The offboarding script logged an action it never performed.** The audit record claimed `Domain Users` had been removed when the script explicitly excludes it. The stamp reused the pre-change membership list rather than the list of groups actually removed. An audit trail that misrepresents what happened is worse than no audit trail. Fixed and re-tested.

Both were caught by reading the output rather than trusting it.

---

## Limitations

The directory can show what access exists. It cannot show whether that access is justified that judgement requires context the directory does not hold. Severity ratings in this report are my own assessment, not script output.

Full detail: [Limitations and production considerations](docs/05-limitations.md).

