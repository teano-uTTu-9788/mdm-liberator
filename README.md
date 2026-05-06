# MDM Liberator — Free Mac MDM Checker

Instantly check your Mac for **common local signals** of Mobile Device Management (MDM) enrollment and related management artifacts. Works on Intel and Apple Silicon, macOS Ventura through Sequoia.

**[mdmliberator.com](https://mdmliberator.com) · MIT License · No telemetry or scan upload · Shell only**

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/teano-uTTu-9788/mdm-liberator/main/mdm_check.sh | bash
```

Or download and run locally:

```bash
git clone https://github.com/teano-uTTu-9788/mdm-liberator.git
cd mdm-liberator
chmod +x mdm_check.sh
./mdm_check.sh
```

## What this is / What this is not

**What this is**

- A **local, read-only** scan that surfaces common MDM / DEP **device-side** signals.
- A starting point for an **Evidence & Escalation Kit** workflow: plain-language notes, repeat checks after authorized changes, and documentation you can align with Apple, a seller, or IT.

**What this is not**

- **Not** proof that a device is permanently “clean,” free of future enrollment risk, or free of undisclosed ABM assignment.
- **Not** for defeating Activation Lock, skirting organizational controls without authorization, or claiming ABM / ADE server-side outcomes from this script alone.
- **Not** confirmation of ABM / Apple School Manager (ASM) registration — that cannot be validated from the device alone.

**Safety & limits (read this)**

- **This tool reduces risk; it does not eliminate it.**
- **ABM/ADE assignment cannot be confirmed locally.**
- **Activation Lock** state is untouched by this read-only checker (**no changes** to Activation Lock).

See also [`docs/EVIDENCE_KIT_FRAMING.md`](docs/EVIDENCE_KIT_FRAMING.md).

## What It Checks (10 signals)

1. System info — macOS version, chip, model
2. DEP / Automated Device Enrollment status (device-reported)
3. Installed MDM configuration profiles
4. MDM vendor launch daemons (Jamf, Mosyle, Kandji, Intune, SimpleMDM, Hexnode, Addigy, Fleet)
5. Apple DEP server connectivity (parallel DNS checks)
6. /etc/hosts blocking entries for DEP domains
7. MDM certificates in System Keychain
8. cloudconfigurationd daemon status
9. Remote Management (ARD) status
10. Remote Management / evidence summary — local status and next-step guidance

## Why Use This?

- **Bought a used Mac?** Check for obvious local MDM signals before you rely on the device.
- **Left a job?** Understand what local management artifacts may still be visible on hardware you are authorized to evaluate.
- **Selling a Mac?** **Provide a local evidence report** buyers can compare with purchase paperwork (not a guarantee of future state).
- **IT audit?** Quick local enrollment-oriented check, no cloud agent.

## Sample Output

```
╔════════════════════════════════════════════════════════╗
║       MDM Liberator — Device Health Check v1.1.0        ║
║                  mdmliberator.com                        ║
╚════════════════════════════════════════════════════════╝

── 1/10 System Info ──
  macOS Version  : 15.4.1 (24E263)
  Model          : MacBookPro18,1
  Chip           : Apple Silicon
  [PASS] System info collected

── 2/10 DEP / Automated Device Enrollment ──
  [PASS] No DEP/MDM enrollment detected

── 3/10 Installed Configuration Profiles ──
  [PASS] No configuration profiles detected

── 4/10 MDM Vendor Launch Daemons & Agents ──
  [PASS] No MDM vendor launch daemons or agents detected

── 5/10 DEP Server Connectivity ──
  [PASS] All DEP domains appear blocked or unreachable (7/7)

── 6/10 /etc/hosts Blocking Entries ──
  [PASS] 5 DEP domain(s) blocked in /etc/hosts

── 7/10 MDM Certificates (System Keychain) ──
  [PASS] No MDM-related certificates found in System Keychain

── 8/10 DEP Enrollment Daemon (cloudconfigurationd) ──
  [PASS] cloudconfigurationd is not running

── 9/10 Remote Management (ARD) Status ──
  [PASS] Remote Management appears disabled

── Summary Classification ──
  Local MDM indicators       : none detected in this local scan
  Permissions                : complete
  Network path               : normal / blocked-or-local / mixed / inconclusive
  ABM/ADE server-side status : unknown from this Mac
  Activation Lock            : not checked or modified

Result: Local MDM indicators classified from device-visible evidence only.
ABM/ADE assignment cannot be confirmed locally.
```

## Privacy

- **No telemetry or scan upload** from `mdm_check.sh`
- DNS resolution may occur during endpoint checks
- No persistent scan results are written by default
- Reads: `profiles`, `launchctl`, `pgrep`, `security`, `dscacheutil`, `/etc/hosts`

## ⚠️ Important Limitations

**This tool checks current local MDM-oriented signals only.** It cannot detect:

- Whether the device is registered in Apple Business Manager (ABM) or Apple School Manager (ASM)
- Whether an organization can assign MDM at a future date
- The device's full lifecycle history with Apple's activation servers

**What this means for used/refurbished Mac buyers:**

A device that looks clear in this scan could still be enrolled in MDM later if the original organization still has it registered in ABM/ASM. **There is no device-side way to verify ABM registration — only Apple or the organization can confirm this.**

**This tool reduces risk; it does not eliminate it.**

Best practice: purchase from Apple Certified Refurbished or authorized resellers who provide **written confirmation of server-side ABM/ASM release** where applicable.

_This disclosure was added in response to [community feedback](https://github.com/teano-uTTu-9788/mdm-liberator/issues/1) from an experienced sysadmin._

---

## Need More?

The free checker tells you what **local signals** were observed. The **Evidence & Escalation Kit** (paid) adds documentation-oriented workflows: templates, repeat verification after authorized changes, a **local evidence report** you can attach to tickets or resale paperwork, email support, and a **30-day money-back guarantee**. Details and pricing live on **[mdmliberator.com](https://mdmliberator.com)** — evidence and documentation positioning only; **no circumvention or “everything fixed” guarantees**.

## License

MIT — free to use, modify, and distribute.

## Contributing

Issues and PRs welcome. Please test on your own devices only.
