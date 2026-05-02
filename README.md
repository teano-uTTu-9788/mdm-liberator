# MDM Liberator — Free Mac MDM Checker

Instantly check if your Mac has Mobile Device Management (MDM) enrolled. Works on Intel and Apple Silicon, macOS Ventura through Sequoia.

**[mdmliberator.com](https://mdmliberator.com) · MIT License · No network calls · Shell only**

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

## What It Checks (10 signals)

1. System info — macOS version, chip, model
2. DEP / Automated Device Enrollment status
3. Installed MDM configuration profiles
4. MDM vendor launch daemons (Jamf, Mosyle, Kandji, Intune, SimpleMDM, Hexnode, Addigy, Fleet)
5. Apple DEP server connectivity (parallel DNS checks)
6. /etc/hosts blocking entries for DEP domains
7. MDM certificates in System Keychain
8. cloudconfigurationd daemon status
9. Remote Management (ARD) status
10. MDM Liberator Guardian daemon status

## Why Use This?

- **Bought a used Mac?** Check if it has hidden MDM before you're locked out
- **Left a job?** Verify your personal Mac is clean
- **Selling a Mac?** Prove it's MDM-free to buyers
- **IT audit?** Quick local enrollment check, no agent required

## Sample Output

```
╔══════════════════════════════════════════════════════════╗
║       MDM Liberator — Device Health Check v1.1.0        ║
║                  mdmliberator.com                        ║
╚══════════════════════════════════════════════════════════╝

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

── 10/10 MDM Liberator Guardian Status ──
  [WARN] Guardian daemon is not running
         Run 'sudo ./install_guard.sh' to enable persistence protection

Result: 10/10 checks clear
Your device is MDM-free. No action needed.
```

## Privacy

- **Zero network calls** — all checks are local system queries only
- No telemetry, no logging, no data leaves your machine
- Reads: `profiles`, `launchctl`, `pgrep`, `security`, `dscacheutil`, `/etc/hosts`

## ⚠️ Important Limitations

**This tool checks current MDM enrollment status only.** It cannot detect:

- Whether the device is registered in Apple Business Manager (ABM) or Apple School Manager (ASM)
- Whether an organization can assign MDM at a future date
- The device's full lifecycle history with Apple's activation servers

**What this means for used/refurbished Mac buyers:**

A device that shows "clean" today could be enrolled in MDM at any future time if the original organization still has it registered in ABM. There is no device-side way to verify ABM registration — only Apple or the organization can confirm this.

**This tool reduces risk but does not eliminate it entirely.**

Best practice: purchase from Apple Certified Refurbished or authorized resellers who confirm ABM removal.

_This disclosure was added in response to [community feedback](https://github.com/teano-uTTu-9788/mdm-liberator/issues/1) from an experienced sysadmin._

---

## Need More?

The free checker tells you **if** you have MDM. The Pro tier ($29) adds:

- Re-enrollment blocking engine with persistence daemon
- Post-reboot verification
- Signed verification report
- NNP audit log
- 48h email support
- 30-day money-back guarantee

[Get MDM Liberator Pro](https://mdmliberator.com) · [mdmliberator.com](https://mdmliberator.com)

## License

MIT — free to use, modify, and distribute.

## Contributing

Issues and PRs welcome. Please test on your own devices only.
