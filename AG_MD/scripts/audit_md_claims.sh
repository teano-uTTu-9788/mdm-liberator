#!/usr/bin/env bash
set -euo pipefail

echo "AG_MD claim audit"
echo "==============="
echo

fail=0

check_bad() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -RIn --exclude-dir=AG_MD -- "$pattern" "$file" >/tmp/ag_md_grep.txt 2>/dev/null; then
    echo "[FAIL] $label"
    cat /tmp/ag_md_grep.txt
    echo
    fail=1
  else
    echo "[PASS] $label"
  fi
}

check_required() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if grep -RIn --exclude-dir=AG_MD -- "$pattern" "$file" >/tmp/ag_md_grep.txt 2>/dev/null; then
    echo "[PASS] $label"
  else
    echo "[FAIL] Missing: $label"
    fail=1
  fi
}

check_bad "10/10 checks clear" README.md "README should not advertise 10/10 clear"
check_bad "X/10 checks clear" . "Repo should not use X/10 clear model"
check_bad "Zero network calls" README.md "README should not claim zero network calls"
check_bad "No network calls from this script" README.md "README should not claim no network calls"
check_bad "does not modify any files, write to disk, or transmit data" SECURITY.md "SECURITY wording too absolute"
check_bad "com.mdmliberator.guard" . "Free checker should not reference optional guard daemon"
check_bad "Optional Evidence Kit Guard" . "Free checker should not include guard check"

check_required "ABM/ADE assignment cannot be confirmed locally" README.md "README must state ABM/ADE limitation"
check_required "No telemetry" README.md "README should say no telemetry"
check_required "Activation Lock" README.md "README must mention Activation Lock limits"

echo
if [ "$fail" -eq 0 ]; then
  echo "AG_MD audit: PASS"
else
  echo "AG_MD audit: FAIL — fix trust-risk claims before promotion"
  exit 1
fi
