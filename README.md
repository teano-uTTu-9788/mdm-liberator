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

## Need More?

The free checker tells you IF you have MDM. For the full re-enrollment blocking toolkit with persistence daemon and verification scoring, visit [MDM Liberator Pro](https://web-ten-gilt-86.vercel.app).

## License

MIT — free to use, modify, and distribute.

## Contributing

Issues and PRs welcome. Please test on your own devices only.
