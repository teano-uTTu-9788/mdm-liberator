# MDM Liberator — Homepage Corrections (Web Developer Handoff)
**Date:** 2026-05-22
**Priority:** P0 — Fix before any high-volume marketing push
**Verified against:** `mdm_check.sh` v1.3.1 (SHA: f334a644)

---

## Why these fixes are required

The current homepage contains three claims that do not match actual script behavior.
A technically literate buyer who reads the script and then re-reads the homepage
will see the discrepancy immediately — this is a trust liability, not just a copy issue.

| Claim | Reality | Risk |
|-------|---------|------|
| "Cryptographically verify management profiles" | Script uses `profiles`, `pgrep`, `find`, `grep`, `security find-certificate` — zero cryptographic operations | Technical buyers will flag this as false advertising |
| Hero screenshot showing SHA-256 hash output | No hash is generated anywhere in v1.3.1 — the screenshot is fabricated | Highest risk: visual proof of a claim that does not exist |
| "Generate immutable evidence" | Output is a plain bash text file — not immutable in any technical sense | Overstated; "local" is accurate, "immutable" is not |

---

## Required Changes

### Hero Section

| Element | Current (REMOVE) | Replace With |
|---------|-----------------|--------------|
| Headline | `Generate immutable evidence of MDM locks.` | `Generate local evidence of MDM locks.` |
| Sub-headline | `Cryptographically verify management profiles...` | `Inspect and document management profiles and supervision status locally.` |
| Hero Badge | `Evidence-Based` / any hash-related badge | `Local Evidence Report Generation` |
| Hero screenshot/graphic | Any image showing SHA-256 or hash output | Remove or replace with actual script output (see below) |

### FounderTrustBadge Section

| Element | Current (REMOVE) | Replace With |
|---------|-----------------|--------------|
| Body text | `...Every scan produces a deterministic local evidence summary...` | `...Every scan produces a detailed local evidence summary...` |
| Feature Pill | `SHA-256 Hashed Output` | `Local Signal Analysis` |

---

## What actual script output looks like (v1.3.1)

Replace any fabricated hero screenshots with this accurate SCAN SUMMARY format:

```
============================================================
SCAN SUMMARY
============================================================
Local MDM indicators:         not detected
Management-adjacent signals:  not detected
Overall local risk:           LOW
Permissions:                  OK
Network path:                 not checked
ABM/ADE server-side status:   CANNOT DETERMINE LOCALLY
Activation Lock:              not checked
Recommended next step:        Request written ABM/ADE release confirmation from seller
============================================================
```

---

## What the script actually does

For developer accuracy in any technical copy:

- `profiles status -type enrollment` — checks MDM enrollment state
- `profiles list` — lists installed configuration profiles
- `pgrep cloudconfigurationd` — checks for active MDM daemon
- `find /Library/LaunchDaemons` — checks for MDM-related launch daemons
- `security find-certificate` — checks System Keychain for MDM certificates
- `pgrep ARDAgent` — checks for Remote Management status
- `dscacheutil -q host` — DNS resolution check for MDM server
- `grep /etc/hosts` — checks for MDM server host overrides
- `launchctl list` — checks for MDM-related launched services

**No cryptographic operations. No hash generation. No SHA-256 anywhere in the script.**

---

## Accurate replacement body copy (optional)

> MDM Liberator is a read-only bash script that analyzes local management signals on macOS.
> It checks enrollment profiles, MDM daemons, management certificates, and Remote Management
> status to classify whether a Mac shows active MDM indicators, management-adjacent signals,
> or neither. Output is a structured local evidence summary — no uploads, no account required.

---

*Verified: CD + AG_MD | 2026-05-22 | teano-uTTu-9788/mdm-liberator*
