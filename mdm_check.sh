#!/bin/bash
# =============================================================================
# MDM Liberator — Device Health Check
# Version: v1.1.0
#
# MIT License
#
# Copyright (c) 2025 MDM Liberator
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Color definitions
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}[PASS]${RESET}"
WARN="${YELLOW}[WARN]${RESET}"
FAIL="${RED}[FAIL]${RESET}"

# ---------------------------------------------------------------------------
# Score tracking
# ---------------------------------------------------------------------------
TOTAL_CHECKS=10
CHECKS_CLEAR=0

# ---------------------------------------------------------------------------
# Helper: print section header
# ---------------------------------------------------------------------------
section() {
    echo ""
    echo -e "${BOLD}── $1 ──${RESET}"
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       MDM Liberator — Device Health Check v1.1.0        ║${RESET}"
echo -e "${BOLD}║                  mdmliberator.com                        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "Scanning your Mac for local MDM enrollment and management indicators..."
echo -e "$(date '+%Y-%m-%d %H:%M:%S')"

# ---------------------------------------------------------------------------
# CHECK 1: System Info
# ---------------------------------------------------------------------------
section "1/10 System Info"

MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
MACOS_BUILD="$(sw_vers -buildVersion 2>/dev/null || echo '')"
MODEL_ID="$(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"

CHIP_TYPE="Intel"
if sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi "apple"; then
    CHIP_TYPE="Apple Silicon"
elif [[ "$(uname -m)" == "arm64" ]]; then
    CHIP_TYPE="Apple Silicon"
fi

echo -e "  macOS Version  : ${MACOS_VERSION} (${MACOS_BUILD})"
echo -e "  Model          : ${MODEL_ID}"
echo -e "  Chip           : ${CHIP_TYPE}"
echo -e "  ${PASS} System info collected"
CHECKS_CLEAR=$((CHECKS_CLEAR + 1))

# ---------------------------------------------------------------------------
# CHECK 2: DEP Enrollment Status
# ---------------------------------------------------------------------------
section "2/10 DEP / Automated Device Enrollment"

DEP_ENROLLED=false
DEP_ENROLLED_VIA_DEP=false

if PROFILES_STATUS="$(profiles status -type enrollment 2>/dev/null)"; then
    echo -e "  profiles output captured"

    if echo "${PROFILES_STATUS}" | grep -qi "enrolled via DEP: Yes"; then
        DEP_ENROLLED_VIA_DEP=true
    fi
    if echo "${PROFILES_STATUS}" | grep -qi "MDM enrollment: Yes"; then
        DEP_ENROLLED=true
    fi
    # Fallback: any "Yes" in the output
    if ! $DEP_ENROLLED && echo "${PROFILES_STATUS}" | grep -qi ": Yes"; then
        DEP_ENROLLED=true
    fi

    if $DEP_ENROLLED_VIA_DEP; then
        echo -e "  ${FAIL} Device is enrolled via DEP (Automated Device Enrollment)"
        echo -e "       This device was registered in Apple Business/School Manager."
    elif $DEP_ENROLLED; then
        echo -e "  ${FAIL} Device is MDM enrolled (not via DEP)"
    else
        echo -e "  ${PASS} No DEP/MDM enrollment detected"
        CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
    fi
else
    echo -e "  ${WARN} Could not run 'profiles status' — try running with sudo for full results"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# CHECK 3: MDM Configuration Profiles
# ---------------------------------------------------------------------------
section "3/10 Installed Configuration Profiles"

PROFILES_FOUND=false

if PROFILE_LIST="$(profiles list 2>/dev/null)"; then
    # Count non-header, non-empty lines as a rough profile count
    PROFILE_COUNT="$(echo "${PROFILE_LIST}" | grep -c 'attribute' 2>/dev/null || echo 0)"
    if [[ "${PROFILE_COUNT}" -gt 0 ]]; then
        PROFILES_FOUND=true
        echo -e "  ${FAIL} Configuration profiles detected (${PROFILE_COUNT} attribute entries)"
        echo -e "       Run 'sudo profiles list' for full detail"
    else
        # Check for any meaningful content beyond the header
        if echo "${PROFILE_LIST}" | grep -qiE "(MDM|management|enrollment|payload)"; then
            PROFILES_FOUND=true
            echo -e "  ${FAIL} MDM-related configuration profile content detected"
        else
            echo -e "  ${PASS} No configuration profiles detected"
            CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
        fi
    fi
elif PROFILE_LIST="$(sudo profiles list 2>/dev/null)"; then
    if echo "${PROFILE_LIST}" | grep -qiE "(MDM|management|enrollment|payload)"; then
        PROFILES_FOUND=true
        echo -e "  ${FAIL} MDM-related configuration profiles detected (elevated check)"
    else
        echo -e "  ${PASS} No configuration profiles detected (elevated check)"
        CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
    fi
else
    echo -e "  ${WARN} 'profiles list' requires elevated privileges — rerun with sudo for this check"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# CHECK 4: MDM Launch Daemons / Agents
# ---------------------------------------------------------------------------
section "4/10 MDM Vendor Launch Daemons & Agents"

MDM_VENDORS=(
    "com.jamf."
    "com.mosyle."
    "com.kandji."
    "com.simplemdm."
    "com.hexnode."
    "com.vmware.hub."
    "com.microsoft.intune."
    "com.apple.mdmclient."
    "com.addigy."
    "com.fleetsmith."
)

DAEMON_DIRS=(
    "/Library/LaunchDaemons"
    "/Library/LaunchAgents"
)

DAEMON_HITS=()

for dir in "${DAEMON_DIRS[@]}"; do
    if [[ -d "${dir}" ]]; then
        for vendor in "${MDM_VENDORS[@]}"; do
            while IFS= read -r -d '' plist; do
                filename="$(basename "${plist}")"
                DAEMON_HITS+=("${filename}")
            done < <(find "${dir}" -maxdepth 1 -name "${vendor}*" -print0 2>/dev/null)
        done
    fi
done

if [[ "${#DAEMON_HITS[@]}" -gt 0 ]]; then
    echo -e "  ${FAIL} MDM vendor launch daemons/agents found:"
    for hit in "${DAEMON_HITS[@]}"; do
        echo -e "       • ${hit}"
    done
else
    echo -e "  ${PASS} No MDM vendor launch daemons or agents detected"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# CHECK 5: Apple Enrollment Endpoint Resolution
# ---------------------------------------------------------------------------
section "5/10 Apple Enrollment Endpoint Resolution"

DEP_DOMAINS=(
    "deviceenrollment.apple.com"
    "mdmenrollment.apple.com"
    "iprofiles.apple.com"
    "gdmf.apple.com"
    "acmdm.apple.com"
    "albert.apple.com"
    "setup.icloud.com"
)

DEP_UNRESOLVED_OR_LOCAL=false
DEP_REACHABLE=false
UNRESOLVED_OR_LOCAL_COUNT=0
REACHABLE_COUNT=0

# mdm-perf-001: Run all DNS checks in parallel background subshells to reduce scan time.
_DEP_TMPDIR="$(mktemp -d)"

for domain in "${DEP_DOMAINS[@]}"; do
    (
        _out=""
        _result="unresolved_or_local"
        resolved_ip="$(dscacheutil -q host -a name "${domain}" 2>/dev/null | grep 'ip_address' | awk '{print $2}' | head -1 || true)"
        if [[ -n "${resolved_ip}" ]]; then
            if echo "${resolved_ip}" | grep -qE "^(127\.|0\.0\.0\.0|::1|::0)"; then
                _out="  ${WARN} ${domain} → ${resolved_ip} (local/sinkhole resolution)"
                _result="unresolved_or_local"
            else
                _result="reachable"
            fi
        else
            _result="unresolved_or_local"
        fi
        _ipv6_line=""
        if grep -qE "^[[:space:]]*::0[[:space:]]+${domain}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
            _ipv6_line="  ${WARN} ${domain} → ::0 (local/sinkhole hosts entry)"
        fi
        printf '%s\n' "${_result}" > "${_DEP_TMPDIR}/${domain}.result"
        {
            [[ -n "${_out}" ]]       && printf '%s\n' "${_out}"
            [[ -n "${_ipv6_line}" ]] && printf '%s\n' "${_ipv6_line}"
        } > "${_DEP_TMPDIR}/${domain}.output"
    ) &
done
wait

for domain in "${DEP_DOMAINS[@]}"; do
    _result_token="$(cat "${_DEP_TMPDIR}/${domain}.result" 2>/dev/null || echo 'unresolved_or_local')"
    _output_lines="$(cat "${_DEP_TMPDIR}/${domain}.output" 2>/dev/null || true)"
    [[ -n "${_output_lines}" ]] && echo -e "${_output_lines}"
    if [[ "${_result_token}" == "reachable" ]]; then
        REACHABLE_COUNT=$((REACHABLE_COUNT + 1))
        DEP_REACHABLE=true
    else
        UNRESOLVED_OR_LOCAL_COUNT=$((UNRESOLVED_OR_LOCAL_COUNT + 1))
        DEP_UNRESOLVED_OR_LOCAL=true
    fi
done
rm -rf "${_DEP_TMPDIR}"

if $DEP_UNRESOLVED_OR_LOCAL && ! $DEP_REACHABLE; then
    echo -e "  ${PASS} No reachable Apple enrollment endpoints observed in this local DNS check (${UNRESOLVED_OR_LOCAL_COUNT}/${#DEP_DOMAINS[@]})"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
elif $DEP_UNRESOLVED_OR_LOCAL && $DEP_REACHABLE; then
    echo -e "  ${WARN} Mixed: ${UNRESOLVED_OR_LOCAL_COUNT} endpoint(s) unresolved/local, ${REACHABLE_COUNT} reachable"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
else
    echo -e "  ${WARN} Apple enrollment endpoints are reachable from this network"
fi

# ---------------------------------------------------------------------------
# CHECK 6: Hosts File Local/Sinkhole Entries
# ---------------------------------------------------------------------------
section "6/10 /etc/hosts Local/Sinkhole Entries"

HOSTS_FILE="/etc/hosts"
DEP_HOST_PATTERNS=(
    "gdmf.apple.com"
    "deviceenrollment.apple.com"
    "mdmenrollment.apple.com"
    "iprofiles.apple.com"
    "albert.apple.com"
)

HOSTS_LOCAL_COUNT=0

for pattern in "${DEP_HOST_PATTERNS[@]}"; do
    if grep -qE "^(127\.|0\.0\.0\.0)[[:space:]].*${pattern}" "${HOSTS_FILE}" 2>/dev/null; then
        HOSTS_LOCAL_COUNT=$((HOSTS_LOCAL_COUNT + 1))
    fi
done

if [[ "${HOSTS_LOCAL_COUNT}" -gt 0 ]]; then
    echo -e "  ${WARN} ${HOSTS_LOCAL_COUNT} Apple enrollment domain(s) resolve locally via /etc/hosts"
    echo -e "       Preserve this as evidence; it is not proof of ABM/ADE release."
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
else
    echo -e "  ${PASS} No Apple enrollment local/sinkhole entries found in /etc/hosts"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# CHECK 7: MDM Certificates in Keychain
# ---------------------------------------------------------------------------
section "7/10 MDM Certificates (System Keychain)"

MDM_CERT_FOUND=false

if CERT_OUTPUT="$(security find-certificate -a -Z /Library/Keychains/System.keychain 2>/dev/null)"; then
    if echo "${CERT_OUTPUT}" | grep -qi "MDM\|mobile device management\|management profile\|jamf\|mosyle\|kandji\|intune\|simplemdm"; then
        MDM_CERT_FOUND=true
        echo -e "  ${FAIL} MDM-related certificate(s) found in System Keychain"
        echo "${CERT_OUTPUT}" | grep -iE "(MDM|mobile device management|management profile|jamf|mosyle|kandji|intune|simplemdm)" | \
            while IFS= read -r line; do
                echo -e "       • ${line}"
            done || true
    else
        echo -e "  ${PASS} No MDM-related certificates found in System Keychain"
        CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
    fi
else
    echo -e "  ${WARN} Could not read System Keychain — try running with sudo for this check"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# CHECK 8: cloudconfigurationd Status
# ---------------------------------------------------------------------------
section "8/10 DEP Enrollment Daemon (cloudconfigurationd)"

CCD_RUNNING=false

if pgrep -x "cloudconfigurationd" > /dev/null 2>&1; then
    CCD_RUNNING=true
    CCD_PID="$(pgrep -x cloudconfigurationd | head -1)"
    echo -e "  ${FAIL} cloudconfigurationd is running (PID: ${CCD_PID})"
    echo -e "       The DEP enrollment daemon is active — device may be pending enrollment"
else
    echo -e "  ${PASS} cloudconfigurationd is not running"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# CHECK 9: Remote Management (ARD) Status
# ---------------------------------------------------------------------------
section "9/10 Remote Management (ARD) Status"

ARD_RUNNING=false
if pgrep -x "ARDAgent" > /dev/null 2>&1; then
    ARD_RUNNING=true
    echo -e "  ${FAIL} Remote Management (ARD) is active"
    echo -e "       Screen observation and remote control may be possible"
else
    if launchctl list 2>/dev/null | grep -q "com.apple.RemoteDesktop.agent"; then
        ARD_RUNNING=true
        echo -e "  ${FAIL} Remote Management agent is loaded"
    else
        echo -e "  ${PASS} Remote Management appears disabled"
        CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
    fi
fi

# ---------------------------------------------------------------------------
# CHECK 10: Evidence Kit Local Helper Status
# ---------------------------------------------------------------------------
section "10/10 Optional Evidence Kit Guard"

if launchctl list 2>/dev/null | grep -q "com.mdmliberator.guard"; then
    echo -e "  ${PASS} Optional Evidence Kit local helper reports loaded"
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
else
    echo -e "  ${WARN} Optional Evidence Kit local helper is not loaded"
    echo -e "       Normal for the free checker."
    CHECKS_CLEAR=$((CHECKS_CLEAR + 1))
fi

# ---------------------------------------------------------------------------
# Summary Report
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                    SCAN SUMMARY                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

SCORE_COLOR="${GREEN}"
if [[ "${CHECKS_CLEAR}" -eq "${TOTAL_CHECKS}" ]]; then
    SCORE_COLOR="${GREEN}"
elif [[ "${CHECKS_CLEAR}" -ge $(( TOTAL_CHECKS - 2 )) ]]; then
    SCORE_COLOR="${YELLOW}"
else
    SCORE_COLOR="${RED}"
fi

echo -e "  Result  : ${SCORE_COLOR}${BOLD}${CHECKS_CLEAR}/${TOTAL_CHECKS} checks clear${RESET}"
echo ""

if [[ "${CHECKS_CLEAR}" -lt "${TOTAL_CHECKS}" ]]; then
    echo -e "  ${RED}${BOLD}Local MDM-oriented signals were detected.${RESET}"
    echo ""
    echo -e "  Your Mac may be enrolled in or managed by an MDM system."
    echo -e "  Address enrollment through authorized channels (IT release, documented"
    echo -e "  purchase paperwork, or Apple Support) — not unauthorized workarounds."
    echo ""
    echo -e "  ${BOLD}Visit https://mdmliberator.com for evidence-first escalation guidance.${RESET}"
else
    echo -e "  ${GREEN}${BOLD}No local MDM indicators detected.${RESET}"
    echo ""
    echo -e "  All checks passed for the signals this script inspects locally."
    echo -e "  ABM/ADE assignment cannot be confirmed from the device alone —"
    echo -e "  this result is not a guarantee of server-side enrollment state."
fi

echo ""
echo -e "  Scanned: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  MDM Liberator v1.1.0 — https://mdmliberator.com"
echo ""

echo ""
echo "Share your results: https://mdmliberator.com?ref=scan&score=${CHECKS_CLEAR}"

echo ""
echo "IMPORTANT: This tool is for devices you are authorized to evaluate."
echo "Use results as local evidence only; they do not prove ownership or server-side release."
