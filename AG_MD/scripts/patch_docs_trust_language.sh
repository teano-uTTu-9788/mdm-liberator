#!/usr/bin/env bash
set -euo pipefail

echo "Patching README.md and SECURITY.md trust language..."

python3 - <<'PY'
from pathlib import Path
import re

readme = Path("README.md")
security = Path("SECURITY.md")

text = readme.read_text()

text = text.replace(
    "· MIT License · No network calls from this script · Shell only",
    "· MIT License · No telemetry or scan upload · Shell only"
)

text = text.replace(
    "- **Zero network calls from this script** — checks use local system queries only\n- No telemetry, no logging, no data leaves your machine from `mdm_check.sh`",
    "- **No telemetry or scan upload** from `mdm_check.sh`\n- DNS resolution may occur during endpoint checks\n- No persistent scan results are written by default"
)

text = text.replace(
    "10. Optional Evidence Kit guard component — whether a **licensed add-on** helper reports loaded (not required for the free scan)",
    "10. Remote Management / evidence summary — local status and next-step guidance"
)

# Remove sample output block for Optional Evidence Kit Guard if present.
text = re.sub(
    r"\n── 10/10 Optional Evidence Kit Guard ──\n  \[WARN\] Optional Evidence Kit guard is not loaded\n         \(Normal for free checker only\.\)\n",
    "\n── Summary Classification ──\n  Local MDM indicators       : none detected in this local scan\n  Permissions                : complete\n  Network path               : normal / blocked-or-local / mixed / inconclusive\n  ABM/ADE server-side status : unknown from this Mac\n  Activation Lock            : not checked or modified\n",
    text
)

text = text.replace(
    "Result: 10/10 checks clear\nNo local MDM indicators detected.",
    "Result: Local MDM indicators classified from device-visible evidence only.\nABM/ADE assignment cannot be confirmed locally."
)

readme.write_text(text)

security.write_text("""# Security Policy

This tool is designed to run local evidence-oriented checks.

It does not modify system configuration or persist scan results by default. Temporary runtime files may be created and removed during execution.

No telemetry or scan upload is performed by `mdm_check.sh`. DNS resolution may occur during endpoint checks.

If you find a security vulnerability, please email security\@mdmliberator.com.
""")
PY

echo "Docs patched. Run AG_MD/scripts/audit_md_claims.sh next."
