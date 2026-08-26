# Limitations and production considerations

This lab demonstrates the mechanics of identity lifecycle management and access review. It does not reproduce the organisational context that makes those processes work in practice. The gaps below are deliberate observations, not oversights.

---

## The directory cannot tell you whether access is justified

The access review script answers *what access exists*. It cannot answer *whether that access is appropriate* as that judgement depends on information the directory does not hold.

Every severity rating in this project is my own assessment. I knew a Sales user holding `Domain Admins` was wrong because I designed the scenario. In a real environment that context comes from elsewhere:

**HR system as source of truth.** Job title, department, manager, employment status, and contract dates live in the HR platform, not in AD. Joining directory accounts to HR records surfaces three classes of problem immediately: accounts with no corresponding HR record (leavers never deprovisioned, or accounts with no owner), HR records with no account, and users whose directory attributes contradict their HR record.

**Manager attestation.** The analyst does not decide whether a user's access is justified. The accountable business owner does. The review produces candidates; a named manager approves or revokes each one, and that approval record is the audit evidence. This is what Entra ID Access Reviews and platforms such as SailPoint and Saviynt exist to operate at scale.

**A role model.** Mature organisations define the expected entitlements for a given role and flag deviation from that baseline. Without one, every review is a manual judgement call.

**Service account ownership records.** A register of owner, purpose, dependencies, and review date. The `svc-backup` finding in this lab — a Domain Admin whose owner has left — is precisely the failure this control prevents.

---

## Known defects in the tooling

**Dormancy detection over-reports.** The stale account check treats a null `LastLogonDate` as evidence of abandonment. It cannot distinguish an account that has never authenticated from one abandoned two years ago, and the initial run consequently flagged the entire user population. A production implementation would cross-reference `LastLogonTimeStamp` against account creation date, and would need to account for `LastLogonTimeStamp` replicating between domain controllers with a delay of up to 14 days by default.

**Group removal is not complete deprovisioning.** `Domain Users` cannot be removed through standard group membership commands, as it is every account's primary group. Full deprovisioning in Active Directory is never as clean as "remove all group memberships."

**Dry-run output is ambiguous.** The offboarding script's `-WhatIf` mode prints the same status messages as a live run. Output should be prefixed to make the distinction unmistakable.

---

## Environment limitations

**Single domain controller.** No redundancy and no replication. A production environment requires at least two per site, and replication latency has direct consequences for the accuracy of any attribute-based review.

**No hybrid synchronisation.** The on-premises and cloud directories in this lab are structurally parallel but not connected. Entra Connect would make this a genuine hybrid identity environment and introduce a category of problems this lab does not cover — sync conflicts, attribute mapping, and source-of-authority decisions.

**Cloud scope constrained by licensing.** Conditional Access, dynamic group membership, Privileged Identity Management, Identity Protection, and Access Reviews all require Entra ID P1 or P2. The cloud portion of this lab was therefore limited to free-tier capabilities: user and group management, and Security Defaults.

This is itself a useful constraint to have encountered. Knowing which capabilities sit behind which licence tier is a recurring part of identity work, and Security Defaults versus Conditional Access is a real architectural trade-off: an all-or-nothing baseline at no cost, against a policy engine that requires per-user licensing.
