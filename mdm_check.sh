#!/bin/bash
# =============================================================================
# MDM Liberator — Local Evidence Check
# Version: v1.2.0
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

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}[PASS]${RESET}"
WARN="${YELLOW}[WARN]${RESET}"
FAIL="${RED}[FAIL]${RESET}"
INFO="${BOLD}[INFO]${RESET}"

LOCAL_MDM_STATE="none detected"
PERMISSIONS_STATE="complete"
NETWORK_PATH_STATE="not checked"
ABM_ADE_STATE="unknown from this Mac"
ACTIVATION_LOCK_STATE="not checked or modified"
RECOMMENDED_ACTION="preserve evidence and request written release if needed"

FINDINGS=()
NOTES=()

section() {
    echo ""
    echo -e "${BOLD}── $1 ──${RESET}"
}

add_finding() {
    FINDINGS+=("$1")
}

mark_detected() {
    LOCAL_MDM_STATE="detected"
    add_finding "$1"
}

mark_inconclusive() {
    if [[ "${LOCAL_MDM_STATE}" != "detected" ]]; then
        LOCAL_MDM_STATE="inconclusive"
    fi
    add_finding "$1"
}

mark_partial_permissions() {
    PERMISSIONS_STATE="partial"
    mark_inconclusive "$1"
}

add_note() {
    NOTES+=("$1")
}

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       MDM Liberator — Local Evidence Check v1.2.0       ║${RESET}"
echo -e "${BOLD}║                  mdmliberator.com                        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "Scanning this Mac for local MDM enrollment and management indicators..."
echo "$(date '+%Y-%m-%d %H:%M:%S')"

# ---------------------------------------------------------------------------
# 1. System Info
# ---------------------------------------------------------------------------
section "1/9 System Info"

MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
MACOS_BUILD="$(sw_vers -buildVersion 2>/dev/null || echo '')"
MODEL_ID="$(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"

CHIP_TYPE="Intel"
if sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi "apple"; then
    CHIP_TYPE="Apple Silicon"
elif [[ "$(uname -m)" == "arm64" ]]; then
    CHIP_TYPE="Apple Silicon"
fi

echo "  macOS Version  : ${MACOS_VERSION} (${MACOS_BUILD})"
echo "  Model          : ${MODEL_ID}"
echo "  Chip           : ${CHIP_TYPE}"
echo -e "  ${PASS} System info collected"

# ---------------------------------------------------------------------------
# 2. DEP / Automated Device Enrollment
# ---------------------------------------------------------------------------
section "2/9 DEP / Automated Device Enrollment"

DEP_ENROLLED=false
DEP_ENROLLED_VIA_DEP=false

if PROFILES_STATUS="$(profiles status -type enrollment 2>/dev/null)"; then
    echo "  profiles status output captured"

    if echo "${PROFILES_STATUS}" | grep -qi "enrolled via DEP: Yes"; then
        DEP_ENROLLED_VIA_DEP=true
    fi
    if echo "${PROFILES_STATUS}" | grep -qi "MDM enrollment: Yes"; then
        DEP_ENROLLED=true
    fi
    if ! $DEP_ENROLLED && echo "${PROFILES_STATUS}" | grep -qi ": Yes"; then
        DEP_ENROLLED=true
    fi

    if $DEP_ENROLLED_VIA_DEP; then
        echo -e "  ${FAIL} Device reports enrollment via DEP / Automated Device Enrollment"
        echo "       This is a local device-reported signal, not proof of server-side release state."
        mark_detected "Device reports enrollment via DEP / Automated Device Enrollment."
        RECOMMENDED_ACTION="request written ABM/ASM release confirmation from the authorized organization or seller"
    elif $DEP_ENROLLED; then
        echo -e "  ${FAIL} Device reports MDM enrollment"
        mark_detected "Device reports MDM enrollment."
        RECOMMENDED_ACTION="contact the authorized IT owner, seller, or Apple/support channel with purchase paperwork"
    else
        echo -e "  ${PASS} No DEP/MDM enrollment reported by profiles status"
    fi
else
    echo -e "  ${WARN} Could not run 'profiles status -type enrollment'"
    echo "       Rerun with appropriate privileges if you need a fuller local evidence record."
    mark_partial_permissions "Enrollment status check was inconclusive because 'profiles status -type enrollment' could not run."
fi

# ---------------------------------------------------------------------------
# 3. Installed Configuration Profiles
# ---------------------------------------------------------------------------
section "3/9 Installed Configuration Profiles"

if PROFILE_LIST="$(profiles list 2>/dev/null)"; then
    PROFILE_COUNT="$(echo "${PROFILE_LIST}" | grep -c 'attribute' 2>/dev/null || true)"
    PROFILE_COUNT="${PROFILE_COUNT:-0}"

    if [[ "${PROFILE_COUNT}" -gt 0 ]]; then
        echo -e "  ${FAIL} Configuration profile attributes detected (${PROFILE_COUNT})"
        mark_detected "Configuration profile attributes were detected."
        RECOMMENDED_ACTION="preserve screenshots/output and request clarification or release through authorized channels"
    elif echo "${PROFILE_LIST}" | grep -qiE "(MDM|management|enrollment|payload)"; then
        echo -e "  ${FAIL} MDM-related configuration profile content detected"
        mark_detected "MDM-related configuration profile content was detected."
        RECOMMENDED_ACTION="preserve screenshots/output and request clarification or release through authorized channels"
    else
        echo -e "  ${PASS} No configuration profiles detected by profiles list"
    fi
else
    echo -e "  ${WARN} 'profiles list' could not run with current permissions"
    echo "       This result is partial; rerun with appropriate privileges for a fuller local evidence record."
    mark_partial_permissions "Configuration profile check was inconclusive because 'profiles list' could not run."
fi

# ---------------------------------------------------------------------------
# 4. MDM Vendor Launch Daemons / Agents
# ---------------------------------------------------------------------------
section "4/9 MDM Vendor Launch Daemons & Agents"

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
                DAEMON_HITS+=("$(basename "${plist}")")
            done < <(find "${dir}" -maxdepth 1 -name "${vendor}*" -print0 2>/dev/null)
        done
    fi
done

if [[ "${#DAEMON_HITS[@]}" -gt 0 ]]; then
    echo -e "  ${FAIL} MDM vendor launch daemons/agents found:"
    for hit in "${DAEMON_HITS[@]}"; do
        echo "       • ${hit}"
    done
    mark_detected "MDM vendor launch daemon/agent files were found."
    RECOMMENDED_ACTION="preserve evidence and request authorized clarification or removal"
else
    echo -e "  ${PASS} No MDM vendor launch daemons or agents detected"
fi

# ---------------------------------------------------------------------------
# 5. Apple Enrollment Endpoint Resolution
# ---------------------------------------------------------------------------
section "5/9 Apple Enrollment Endpoint Resolution"

DEP_DOMAINS=(
    "deviceenrollment.apple.com"
    "mdmenrollment.apple.com"
    "iprofiles.apple.com"
    "gdmf.apple.com"
    "acmdm.apple.com"
    "albert.apple.com"
    "setup.icloud.com"
)

UNRESOLVED_OR_LOCAL_COUNT=0
REACHABLE_COUNT=0

_DEP_TMPDIR="$(mktemp -d)"
trap 'rm -rf "${_DEP_TMPDIR}"' EXIT

for domain in "${DEP_DOMAINS[@]}"; do
    (
        _result="unresolved_or_local"
        _output=""
        resolved_ip="$(dscacheutil -q host -a name "${domain}" 2>/dev/null | grep 'ip_address' | awk '{print $2}' | head -1 || true)"

        if [[ -n "${resolved_ip}" ]]; then
            if echo "${resolved_ip}" | grep -qE "^(127\.|0\.0\.0\.0|::1|::0)"; then
                _output="  ${WARN} ${domain} → ${resolved_ip} (local/sinkhole resolution)"
                _result="unresolved_or_local"
            else
                _result="reachable"
            fi
        fi

        if grep -qE "^[[:space:]]*::0[[:space:]]+${domain}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
            _output="${_output}"$'\n'"  ${WARN} ${domain} → ::0 (local/sinkhole hosts entry)"
        fi

        printf '%s\n' "${_result}" > "${_DEP_TMPDIR}/${domain}.result"
        printf '%s\n' "${_output}" > "${_DEP_TMPDIR}/${domain}.output"
    ) &
done
wait

for domain in "${DEP_DOMAINS[@]}"; do
    _result_token="$(cat "${_DEP_TMPDIR}/${domain}.result" 2>/dev/null || echo 'unresolved_or_local')"
    _output_lines="$(cat "${_DEP_TMPDIR}/${domain}.output" 2>/dev/null || true)"
    [[ -n "${_output_lines}" ]] && echo -e "${_output_lines}"

    if [[ "${_result_token}" == "reachable" ]]; then
        REACHABLE_COUNT=$((REACHABLE_COUNT + 1))
    else
        UNRESOLVED_OR_LOCAL_COUNT=$((UNRESOLVED_OR_LOCAL_COUNT + 1))
    fi
done

if [[ "${REACHABLE_COUNT}" -eq 0 ]]; then
    NETWORK_PATH_STATE="blocked-or-local"
    echo -e "  ${WARN} No reachable Apple enrollment endpoints observed in this local DNS check (${UNRESOLVED_OR_LOCAL_COUNT}/${#DEP_DOMAINS[@]})"
    echo "       This is network-path evidence only; it is not proof of ABM/ADE release."
    add_finding "Apple enrollment endpoints were unresolved or locally routed in this DNS check."
elif [[ "${UNRESOLVED_OR_LOCAL_COUNT}" -gt 0 ]]; then
    NETWORK_PATH_STATE="mixed"
    echo -e "  ${WARN} Mixed endpoint resolution: ${UNRESOLVED_OR_LOCAL_COUNT} unresolved/local, ${REACHABLE_COUNT} reachable"
    echo "       This is network-path evidence only; it is not proof of ABM/ADE state."
    add_finding "Apple enrollment endpoint resolution was mixed."
else
    NETWORK_PATH_STATE="normal"
    echo -e "  ${INFO} Apple enrollment endpoints resolved to non-local addresses from this network"
    add_note "Apple enrollment endpoint DNS resolution appeared normal in this local check."
fi

rm -rf "${_DEP_TMPDIR}"
trap - EXIT

# ---------------------------------------------------------------------------
# 6. /etc/hosts Local/Sinkhole Entries
# ---------------------------------------------------------------------------
section "6/9 /etc/hosts Local/Sinkhole Entries"

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
    echo "       Treat this as a network/path anomaly, not evidence of server-side release."
    add_finding "Apple enrollment domain local/sinkhole entries were found in /etc/hosts."
    if [[ "${NETWORK_PATH_STATE}" == "normal" || "${NETWORK_PATH_STATE}" == "not checked" ]]; then
        NETWORK_PATH_STATE="blocked-or-local"
    fi
else
    echo -e "  ${PASS} No Apple enrollment local/sinkhole entries found in /etc/hosts"
fi

# ---------------------------------------------------------------------------
# 7. MDM Certificates in Keychain
# ---------------------------------------------------------------------------
section "7/9 MDM Certificates (System Keychain)"

if CERT_OUTPUT="$(security find-certificate -a -Z /Library/Keychains/System.keychain 2>/dev/null)"; then
    if echo "${CERT_OUTPUT}" | grep -qiE "(MDM|mobile device management|management profile|jamf|mosyle|kandji|intune|simplemdm)"; then
        echo -e "  ${FAIL} MDM-related certificate(s) found in System Keychain"
        echo "${CERT_OUTPUT}" | grep -iE "(MDM|mobile device management|management profile|jamf|mosyle|kandji|intune|simplemdm)" | \
            while IFS= read -r line; do
                echo "       • ${line}"
            done || true
        mark_detected "MDM-related certificate material was found in System Keychain."
        RECOMMENDED_ACTION="preserve evidence and request authorized clarification or release"
    else
        echo -e "  ${PASS} No MDM-related certificates found in System Keychain"
    fi
else
    echo -e "  ${WARN} Could not read System Keychain with current permissions"
    mark_partial_permissions "System Keychain certificate check was inconclusive with current permissions."
fi

# ---------------------------------------------------------------------------
# 8. cloudconfigurationd Status
# ---------------------------------------------------------------------------
section "8/9 DEP Enrollment Daemon (cloudconfigurationd)"

if pgrep -x "cloudconfigurationd" > /dev/null 2>&1; then
    CCD_PID="$(pgrep -x cloudconfigurationd | head -1)"
    echo -e "  ${FAIL} cloudconfigurationd is running (PID: ${CCD_PID})"
    echo "       This may be a local signal of pending enrollment activity."
    mark_detected "cloudconfigurationd was running during the scan."
    RECOMMENDED_ACTION="preserve evidence and request authorized clarification or release"
else
    echo -e "  ${PASS} cloudconfigurationd is not running"
fi

# ---------------------------------------------------------------------------
# 9. Remote Management (ARD) Status
# ---------------------------------------------------------------------------
section "9/9 Remote Management (ARD) Status"

if pgrep -x "ARDAgent" > /dev/null 2>&1; then
    echo -e "  ${FAIL} Remote Management (ARD) is active"
    echo "       Screen observation and remote control may be possible if configured."
    mark_detected "Remote Management / ARD agent was active."
    RECOMMENDED_ACTION="preserve evidence and review authorized system settings or IT ownership"
elif launchctl list 2>/dev/null | grep -q "com.apple.RemoteDesktop.agent"; then
    echo -e "  ${FAIL} Remote Management agent is loaded"
    mark_detected "Remote Management / ARD launch agent was loaded."
    RECOMMENDED_ACTION="preserve evidence and review authorized system settings or IT ownership"
else
    echo -e "  ${PASS} Remote Management appears disabled"
fi

# ---------------------------------------------------------------------------
# Summary Report
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                    SCAN SUMMARY                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

echo -e "  Local MDM indicators       : ${BOLD}${LOCAL_MDM_STATE}${RESET}"
echo -e "  Permissions                : ${BOLD}${PERMISSIONS_STATE}${RESET}"
echo -e "  Network path               : ${BOLD}${NETWORK_PATH_STATE}${RESET}"
echo -e "  ABM/ADE server-side status : ${BOLD}${ABM_ADE_STATE}${RESET}"
echo -e "  Activation Lock            : ${BOLD}${ACTIVATION_LOCK_STATE}${RESET}"
echo -e "  Recommended next step      : ${BOLD}${RECOMMENDED_ACTION}${RESET}"
echo ""

if [[ "${#FINDINGS[@]}" -gt 0 ]]; then
    echo -e "${BOLD}Findings / caveats:${RESET}"
    for finding in "${FINDINGS[@]}"; do
        echo "  • ${finding}"
    done
    echo ""
fi

if [[ "${#NOTES[@]}" -gt 0 ]]; then
    echo -e "${BOLD}Notes:${RESET}"
    for note in "${NOTES[@]}"; do
        echo "  • ${note}"
    done
    echo ""
fi

echo "This scan reports local device-visible evidence only."
echo "ABM/ADE assignment cannot be confirmed locally."
echo "Activation Lock is not checked, modified, bypassed, or removed by this tool."
echo "A scan with no local indicators is not a guarantee of server-side release or future enrollment status."
echo ""
echo "Scanned: $(date '+%Y-%m-%d %H:%M:%S')"
echo "MDM Liberator v1.2.0 — https://mdmliberator.com"
echo ""
echo "IMPORTANT: This tool is for devices you are authorized to evaluate."
echo "Use results as local evidence only; they do not prove ownership or server-side release."
