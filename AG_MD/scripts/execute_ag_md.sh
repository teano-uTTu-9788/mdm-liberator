#!/usr/bin/env bash
set -euo pipefail

echo "AG_MD EXECUTION"
echo "=============="
echo
echo "Branch: $(git branch --show-current)"
echo

echo "Step 1: Patch README.md and SECURITY.md trust language"
bash AG_MD/scripts/patch_docs_trust_language.sh

echo
echo "Step 2: Audit claims"
if bash AG_MD/scripts/audit_md_claims.sh; then
  echo "Docs audit passed."
else
  echo "Docs audit failed. Continue to patch mdm_check.sh manually per AG_MD/briefs/ACCEPTANCE_CRITERIA.md."
fi

echo
echo "Step 3: Remaining manual engineering target"
cat <<'MSG'
Patch mdm_check.sh next:
- Remove TOTAL_CHECKS/CHECKS_CLEAR score model.
- Remove Optional Evidence Kit Guard check.
- Track classification variables:
  LOCAL_MDM_INDICATORS=none/detected/inconclusive
  PERMISSIONS=complete/partial
  NETWORK_PATH=normal/blocked-or-local/mixed/inconclusive
- Treat permission failures as partial/inconclusive.
- Treat /etc/hosts sinkholes as anomaly/evidence, not PASS.
- End summary with:
  ABM/ADE assignment cannot be confirmed locally.
  Activation Lock is not checked or modified.
MSG

echo
echo "Step 4: Current git diff"
git --no-pager diff -- README.md SECURITY.md AG_MD || true

echo
echo "AG_MD packet created. Commit after mdm_check.sh classification patch passes audit."
