#!/bin/bash
# =============================================================================
# MDM Liberator — Local Evidence Check
# Version: v1.3.0
#
# Local evidence only. No telemetry or scan upload.
# No bypass. No removal. No ABM/ADE guarantee.
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
# Classification state
# ---------------------------------------------------------------------------
LOCAL_MDM_INDICATORS="none"
PERMISSIONS="complete"
NETWORK_PATH="inconclusive"
ABM_ADE_SERVER_SIDE_STATUS="unknown"
ACTIVATION_LOCK="not_checked"

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
echo -e "${BOLD}║       MDM Liberator — Local Evidence Check v1.3.0       ║${RESET}"
echo -e "${BOLD}║                  mdmliberator.com                        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "Scanning local Mac for MDM enrollment and management indicators..."
echo -e "No telemetry or scan upload; DNS resolution may occur."
echo -e "$(date '+%Y-%m-%d %H:%M:%S')"

# ---------------------------------------------------------------------------
# CHECK: System Info
# ---------------------------------------------------------------------------
section "System Info"

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

# ---------------------------------------------------------------------------
# CHECK: DEP / Automated Device Enrollment
# ---------------------------------------------------------------------------
section "DEP / Automated Device Enrollment"

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
        LOCAL_MDM_INDICATORS="detected"
    elif $DEP_ENROLLED; then
        echo -e "  ${FAIL} Device is MDM enrolled (not via DEP)"
        LOCAL_MDM_INDICATORS="detected"
    else
        echo -e "  ${PASS} No DEP/MDM enrollment detected"
    fi
else
    echo -e "  ${WARN} Could not run 'profiles status' — permissions may be partial"
    PERMISSIONS="partial"
fi

# ---------------------------------------------------------------------------
# CHECK: Installed Configuration Profiles
# ---------------------------------------------------------------------------
section "Installed Configuration Profiles"

PROFILES_FOUND=false

if PROFILE_LIST="$(profiles list 2>/dev/null)"; then
    # Count non-header, non-empty lines as a rough profile count
    PROFILE_COUNT="$(echo "${PROFILE_LIST}" | grep -c 'attribute' 2>/dev/null || echo 0)"
    if [[ "${PROFILE_COUNT}" -gt 0 ]]; then
        PROFILES_FOUND=true
        echo -e "  ${FAIL} Configuration profiles detected (${PROFILE_COUNT} attribute entries)"
        echo -e "       Run 'sudo profiles list' for full detail"
        LOCAL_MDM_INDICATORS="detected"
    else
        # Check for any meaningful content beyond the header
        if echo "${PROFILE_LIST}" | grep -qiE "(MDM|management|enrollment|payload)"; then
            PROFILES_FOUND=true
            echo -e "  ${FAIL} MDM-related configuration profile content detected"
            LOCAL_MDM_INDICATORS="detected"
        else
            echo -e "  ${PASS} No configuration profiles detected"
        fi
    fi
elif PROFILE_LIST="$(sudo profiles list 2>/dev/null)"; then
    if echo "${PROFILE_LIST}" | grep -qiE "(MDM|management|enrollment|payload)"; then
        PROFILES_FOUND=true
        echo -e "  ${FAIL} MDM-related configuration profiles detected (elevated check)"
        LOCAL_MDM_INDICATORS="detected"
    else
        echo -e "  ${PASS} No configuration profiles detected (elevated check)"
    fi
else
    echo -e "  ${WARN} 'profiles list' permissions are partial (requires sudo)"
    PERMISSIONS="partial"
fi

# ---------------------------------------------------------------------------
# CHECK: MDM Vendor Launch Daemons & Agents
# ---------------------------------------------------------------------------
section "MDM Vendor Launch Daemons & Agents"

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
    LOCAL_MDM_INDICATORS="detected"
else
    echo -e "  ${PASS} No MDM vendor launch daemons or agents detected"
fi

# ---------------------------------------------------------------------------
# CHECK: Apple Enrollment Endpoint Resolution
# ---------------------------------------------------------------------------
section "Apple Enrollment Endpoint Resolution"

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
    NETWORK_PATH="blocked-or-local"
elif $DEP_UNRESOLVED_OR_LOCAL && $DEP_REACHABLE; then
    echo -e "  ${WARN} Mixed network path: ${UNRESOLVED_OR_LOCAL_COUNT} unresolved/local, ${REACHABLE_COUNT} reachable"
    NETWORK_PATH="mixed"
else
    echo -e "  ${PASS} Apple enrollment endpoints are reachable (normal path)"
    NETWORK_PATH="normal"
fi

# ---------------------------------------------------------------------------
# CHECK: /etc/hosts Local/Sinkhole Entries
# ---------------------------------------------------------------------------
section "/etc/hosts Local/Sinkhole Entries"

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
    NETWORK_PATH="blocked-or-local"
else
    echo -e "  ${PASS} No Apple enrollment local/sinkhole entries found in /etc/hosts"
fi

# ---------------------------------------------------------------------------
# CHECK: MDM Certificates (System Keychain)
# ---------------------------------------------------------------------------
section "MDM Certificates (System Keychain)"

MDM_CERT_FOUND=false

if CERT_OUTPUT="$(security find-certificate -a -Z /Library/Keychains/System.keychain 2>/dev/null)"; then
    if echo "${CERT_OUTPUT}" | grep -qi "MDM\|mobile device management\|management profile\|jamf\|mosyle\|kandji\|intune\|simplemdm"; then
        MDM_CERT_FOUND=true
        echo -e "  ${FAIL} MDM-related certificate(s) found in System Keychain"
        echo "${CERT_OUTPUT}" | grep -iE "(MDM|mobile device management|management profile|jamf|mosyle|kandji|intune|simplemdm)" | \
            while IFS= read -r line; do
                echo -e "       • ${line}"
            done || true
        LOCAL_MDM_INDICATORS="detected"
    else
        echo -e "  ${PASS} No MDM-related certificates found in System Keychain"
    fi
else
    echo -e "  ${WARN} System Keychain permissions are partial (try running with sudo)"
    PERMISSIONS="partial"
fi

# ---------------------------------------------------------------------------
# CHECK: DEP Enrollment Daemon (cloudconfigurationd)
# ---------------------------------------------------------------------------
section "DEP Enrollment Daemon (cloudconfigurationd)"

CCD_RUNNING=false

if pgrep -x "cloudconfigurationd" > /dev/null 2>&1; then
    CCD_RUNNING=true
    CCD_PID="$(pgrep -x cloudconfigurationd | head -1)"
    echo -e "  ${FAIL} cloudconfigurationd is running (PID: ${CCD_PID})"
    echo -e "       The DEP enrollment daemon is active — device may be pending enrollment"
    LOCAL_MDM_INDICATORS="detected"
else
    echo -e "  ${PASS} cloudconfigurationd is not running"
fi

# ---------------------------------------------------------------------------
# CHECK: Remote Management (ARD) Status
# ---------------------------------------------------------------------------
section "Remote Management (ARD) Status"

ARD_RUNNING=false
if pgrep -x "ARDAgent" > /dev/null 2>&1; then
    ARD_RUNNING=true
    echo -e "  ${FAIL} Remote Management (ARD) is active"
    echo -e "       Screen observation and remote control may be possible"
    LOCAL_MDM_INDICATORS="detected"
else
    if launchctl list 2>/dev/null | grep -q "com.apple.RemoteDesktop.agent"; then
        ARD_RUNNING=true
        echo -e "  ${FAIL} Remote Management agent is loaded"
        LOCAL_MDM_INDICATORS="detected"
    else
        echo -e "  ${PASS} Remote Management appears disabled"
    fi
fi

# ---------------------------------------------------------------------------
# Summary Report
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                    SCAN SUMMARY                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

echo -e "  Local MDM indicators       : ${BOLD}${LOCAL_MDM_INDICATORS}${RESET}"
echo -e "  Permissions                : ${BOLD}${PERMISSIONS}${RESET}"
echo -e "  Network path               : ${BOLD}${NETWORK_PATH}${RESET}"
echo -e "  ABM/ADE server-side status : ${BOLD}${ABM_ADE_SERVER_SIDE_STATUS}${RESET}"
echo -e "  Activation Lock            : ${BOLD}${ACTIVATION_LOCK}${RESET}"
echo ""

if [[ "${LOCAL_MDM_INDICATORS}" == "detected" ]]; then
    echo -e "  ${RED}${BOLD}Local MDM-oriented signals were detected.${RESET}"
    echo ""
    echo -e "  Your Mac may be enrolled in or managed by an MDM system."
    echo -e "  Address enrollment through authorized channels (IT release, documented"
    echo -e "  purchase paperwork, or Apple Support) — not unauthorized workarounds."
    echo ""
    echo -e "  ${BOLD}Visit https://mdmliberator.com for evidence-first escalation guidance.${RESET}"
else
    echo -e "  ${GREEN}${BOLD}No local MDM indicators detected in this local scan.${RESET}"
    echo ""
    echo -e "  All checks passed for the signals this script inspects locally."
    echo -e "  ABM/ADE assignment cannot be confirmed from the device alone."
fi

echo ""
echo -e "  Scanned: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  MDM Liberator v1.3.0 — https://mdmliberator.com"
echo ""

echo ""
echo "Share your local scan results: https://mdmliberator.com?ref=scan"

echo ""
echo "This scan reports local device-visible evidence only."
echo "ABM/ADE assignment cannot be confirmed locally."
echo "Activation Lock is not checked, modified, bypassed, or removed by this tool."
echo "A scan with no local indicators is not proof of server-side release or future enrollment status."
echo "Use this tool only for devices you own or are authorized to evaluate."
echo ""
