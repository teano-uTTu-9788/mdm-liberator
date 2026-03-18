# MDM Liberator — Free Mac MDM Checker

Instantly check if your Mac has Mobile Device Management (MDM) enrolled. Works on Intel and Apple Silicon, macOS Ventura through Tahoe.

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/teano-uTTu-9788/mdm-liberator/main/mdm_check.sh | bash
```

Or download and run:

```bash
git clone https://github.com/teano-uTTu-9788/mdm-liberator.git
cd mdm-liberator
chmod +x mdm_check.sh
./mdm_check.sh
```

## What It Checks

- DEP enrollment status
- Installed MDM configuration profiles
- MDM vendor detection (Jamf, Mosyle, Kandji, SimpleMDM, Hexnode, Intune, Addigy)
- Apple DEP server connectivity
- /etc/hosts blocking status
- MDM certificates in Keychain
- cloudconfigurationd daemon status
- Overall device health score (8-point check)

## Why Use This?

- **Bought a used Mac?** Check if it has hidden MDM before you're locked out
- **Left a job?** Verify your personal Mac is clean
- **Selling a Mac?** Prove it's MDM-free to buyers

## Sample Output

```
╔══════════════════════════════════════════════════╗
║     MDM Liberator — Device Health Check v1.0.0   ║
╚══════════════════════════════════════════════════╝

[PASS] System: macOS Sequoia 15.3 (Apple Silicon)
[PASS] DEP Enrollment: Not enrolled
[PASS] MDM Profiles: None detected
[PASS] MDM Daemons: None running
[PASS] DEP Servers: Blocked via /etc/hosts
[PASS] Hosts File: 7/7 blocks active
[PASS] MDM Certificates: None found
[PASS] cloudconfigurationd: Not running

Score: 8/8 — Your device is MDM-free!
```

## ⚠️ Important Limitations

**This tool checks current MDM enrollment status only.** It cannot detect:

- Whether the device is registered in Apple Business Manager (ABM) or Apple Enrollment Manager (AEM)
- Whether an organization can assign MDM to the device in the future
- The device's full lifecycle history with Apple's activation servers

**What this means for used/refurbished Mac buyers:**

A device that shows "clean" today could be enrolled in MDM at any future time if the original organization still has it registered in their ABM/AEM account. There is currently no device-side way to verify ABM/AEM registration — only Apple (or the organization) can confirm this.

**This tool reduces risk but does not eliminate it entirely.**

**Best practice:** Purchase from Apple Certified Refurbished or authorized resellers who confirm ABM/AEM removal before resale.

_This disclosure was added in response to [community feedback](https://github.com/teano-uTTu-9788/mdm-liberator/issues/1) from an experienced sysadmin who encountered this exact scenario._

---

## Need More?

The free checker tells you IF you have MDM. For the full re-enrollment blocking toolkit with persistence daemon and verification scoring, visit [MDM Liberator Pro](https://web-ten-gilt-86.vercel.app).

## License

MIT — free to use, modify, and distribute.

## Contributing

Issues and PRs welcome. Please test on your own devices only.
