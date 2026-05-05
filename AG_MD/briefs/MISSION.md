# AG_MD Mission — Trust Hardening + Reddit Recovery

## Objective

Prepare MDM Liberator for trust-sensitive distribution after Reddit removal by removing overclaiming, reducing bypass/circumvention vibes, and making output scientifically defensible.

## Core diagnosis

The Reddit comment removal was a distribution single-point-of-failure, but the deeper issue is trust posture.

The repo must not look like:
- MDM bypass
- MDM removal
- Activation Lock defeat
- server-side ABM/ADE certainty
- paid daemon upsellware
- "everything is clean" guarantee

The repo must look like:
- local evidence checker
- limited claims
- ABM/ADE cannot be confirmed locally
- no telemetry or scan upload
- no system configuration changes
- documentation for escalation, return, or seller/IT conversation

## Immediate engineering goals

1. Replace score model:
   - Remove `X/10 checks clear`.
   - Stop treating warnings/inconclusive states as clean passes.
   - Output classifications instead.

2. Replace privacy wording:
   - Remove `Zero network calls`.
   - Use: `No telemetry or scan upload; DNS resolution may occur during endpoint checks.`

3. Replace disk-write wording:
   - Remove absolute `does not write to disk`.
   - Use: `Does not modify system configuration or persist scan results by default. Temporary runtime files may be created and removed during execution.`

4. Remove Optional Evidence Kit Guard from free checker:
   - Remove `com.mdmliberator.guard` check from mdm_check.sh.
   - Remove it from README check list and sample output.
   - Keep paid Evidence Kit as documentation/templates/support only.

5. Reddit-safe positioning:
   - Do not post link-first.
   - Lead with useful technical guidance.
   - Disclose authorship.
   - Ask mods before linking.
