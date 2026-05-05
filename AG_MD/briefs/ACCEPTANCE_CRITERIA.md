# AG_MD Acceptance Criteria

## mdm_check.sh

- [x] Does not print `X/10 checks clear`.
- [x] Does not print `Result: 10/10 checks clear`.
- [x] Permission failures become `Permissions: partial` or `inconclusive`.
- [x] DNS checks are labeled network-path evidence only.
- [x] `/etc/hosts` local/sinkhole entries are anomaly/evidence, not positive pass.
- [x] Optional Evidence Kit Guard check removed.
- [x] Summary always includes: `ABM/ADE assignment cannot be confirmed locally.`
- [x] Summary always includes: `Activation Lock is not checked or modified.`

## README.md

- [x] Removes `No network calls from this script`.
- [x] Uses `No telemetry or scan upload; DNS resolution may occur during endpoint checks.`
- [x] Removes Optional Evidence Kit Guard from list of checks.
- [x] Sample output uses classification model.
- [x] No bypass, unlock, defeat, guarantee, or clean-certainty language.

## SECURITY.md

- [x] Replaces absolute no-write/no-transmit wording.
- [x] States no persistent scan writes/system modifications by default.
- [x] Acknowledges temporary runtime files may be created and removed.
- [x] States no telemetry or scan upload.

## Reddit recovery

- [x] Removed comment text archived.
- [x] Removal state checked logged-out.
- [x] Modmail drafted, not argumentative.
- [x] No-link educational comment drafted.
- [x] Link only used if asked or mod-approved.
