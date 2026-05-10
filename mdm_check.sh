#!/bin/bash
# =============================================================================
# MDM Liberator — Local Evidence Check
# Version: v1.3.1
#
# Local evidence only. No bypass. No removal. No ABM/ADE guarantee.
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

REPORT_PATH=""
JSON_PATH=""
INCLUDE_SERIAL=false

usage() {
  cat <<USAGE
MDM Liberator — Local Evidence Check v1.3.1

Usage:
  ./mdm_check.sh
  ./mdm_check.sh --report mdm-liberator-report.txt
  ./mdm_check.sh --json mdm-liberator-report.json
  ./mdm_check.sh --report report.txt --json report.json
  ./mdm_check.sh --json report.json --include-serial

Notes:
  - Default run writes no persistent report.
  - No scan output is uploaded.
  - Serial number is excluded unless --include-serial is explicitly passed.
USAGE
}

SELF_TEST_LOCAL_MDM_INDICATORS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test=pass-fixture) SELF_TEST_LOCAL_MDM_INDICATORS="none_detected"; shift ;;
    --self-test=warn-fixture) SELF_TEST_LOCAL_MDM_INDICATORS="detected"; shift ;;
    --report)
      [[ $# -ge 2 ]] || { echo "ERROR: --report requires a path" >&2; exit 2; }
      REPORT_PATH="$2"
      shift 2
      ;;
    --json)
      [[ $# -ge 2 ]] || { echo "ERROR: --json requires a path" >&2; exit 2; }
      JSON_PATH="$2"
      shift 2
      ;;
    --include-serial)
      INCLUDE_SERIAL=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "${JSON_PATH}" ]] && $INCLUDE_SERIAL; then
  echo "WARNING: --include-serial will include this Mac's serial number in the local JSON report." >&2
  echo "         Do not share that report publicly." >&2
fi

LOCAL_MDM_INDICATORS="none_detected"
if [[ -n "${SELF_TEST_LOCAL_MDM_INDICATORS:-}" ]]; then
  LOCAL_MDM_INDICATORS="${SELF_TEST_LOCAL_MDM_INDICATORS}"
fi
MANAGEMENT_ADJACENT_INDICATORS="none_detected"
PERMISSIONS="complete"
NETWORK_PATH="not_checked"
ABM_ADE_SERVER_SIDE_STATUS="unknown_from_device"
ACTIVATION_LOCK="not_checked_not_modified"
RECOMMENDED_NEXT_STEP="preserve_evidence"

FINDING_IDS=()
FINDING_SEVERITIES=()
FINDING_CATEGORIES=()
FINDING_SUMMARIES=()
FINDING_STRENGTHS=()

NOTES=()

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/    /\\t/g'
}

add_finding() {
  FINDING_IDS+=("$1")
  FINDING_SEVERITIES+=("$2")
  FINDING_CATEGORIES+=("$3")
  FINDING_SUMMARIES+=("$4")
  FINDING_STRENGTHS+=("$5")
}

add_note() {
  NOTES+=("$1")
}

mark_detected() {
  LOCAL_MDM_INDICATORS="detected"
  RECOMMENDED_NEXT_STEP="${2:-request_release}"
  add_finding "$1" "${3:-medium}" "${4:-enrollment}" "$5" "${6:-medium}"
}

mark_management_adjacent_detected() {
  MANAGEMENT_ADJACENT_INDICATORS="detected"
  RECOMMENDED_NEXT_STEP="${2:-contact_it}"
  add_finding "$1" "${3:-medium}" "${4:-remote_management}" "$5" "${6:-medium}"
}

mark_inconclusive() {
  if [[ "${LOCAL_MDM_INDICATORS}" != "detected" ]]; then
    LOCAL_MDM_INDICATORS="inconclusive"
  fi
  add_finding "$1" "${2:-info}" "${3:-permission}" "$4" "${5:-low}"
}

mark_partial_permissions() {
  PERMISSIONS="partial"
  mark_inconclusive "$1" "info" "permission" "$2" "low"
}

section() {
  echo ""
  echo -e "${BOLD}── $1 ──${RESET}"
}

TIMESTAMP_LOCAL="$(date '+%Y-%m-%dT%H:%M:%S%z')"
MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
MACOS_BUILD="$(sw_vers -buildVersion 2>/dev/null || echo 'Unknown')"
MODEL_ID="$(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
SERIAL_NUMBER=""
if $INCLUDE_SERIAL; then
  SERIAL_NUMBER="$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F\" '/IOPlatformSerialNumber/{print $4; exit}' || true)"
fi

CHIP_TYPE="Intel"
if [[ "$(uname -m 2>/dev/null || true)" == "arm64" ]]; then
  CHIP_TYPE="Apple Silicon"
elif sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi "apple"; then
  CHIP_TYPE="Apple Silicon"
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       MDM Liberator — Local Evidence Check v1.3.1       ║${RESET}"
echo -e "${BOLD}║                  mdmliberator.com                        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "Scanning this Mac for local MDM enrollment and management indicators..."
echo "${TIMESTAMP_LOCAL}"

section "1/9 System Info"
echo "  macOS Version  : ${MACOS_VERSION} (${MACOS_BUILD})"
echo "  Model          : ${MODEL_ID}"
echo "  Chip           : ${CHIP_TYPE}"
echo -e "  ${PASS} System info collected"

section "2/9 DEP / Automated Device Enrollment"
if PROFILES_STATUS="$(profiles status -type enrollment 2>/dev/null)"; then
  if echo "${PROFILES_STATUS}" | grep -qiE "enrolled via DEP:[[:space:]]*Yes|enrolled via Automated Device Enrollment:[[:space:]]*Yes"; then
    echo -e "  ${FAIL} Device reports DEP / Automated Device Enrollment locally"
    echo "       This is a local signal only; server-side ABM/ADE release cannot be confirmed from this Mac."
    mark_detected "dep_ade_local_signal" "request_release" "high" "enrollment" "Device reports DEP / Automated Device Enrollment locally." "high"
  elif echo "${PROFILES_STATUS}" | grep -qiE "MDM enrollment:[[:space:]]*Yes"; then
    echo -e "  ${FAIL} Device reports MDM enrollment locally"
    mark_detected "mdm_enrollment_local_signal" "request_release" "high" "enrollment" "Device reports MDM enrollment locally." "high"
  else
    echo -e "  ${PASS} No MDM enrollment reported by profiles status"
  fi
else
  echo -e "  ${WARN} Could not run 'profiles status -type enrollment'"
  echo "       Rerun with appropriate privileges for a fuller local evidence record."
  mark_partial_permissions "profiles_status_unavailable" "Enrollment status check was inconclusive because profiles status could not run."
fi

section "3/9 Installed Configuration Profiles"
if PROFILE_LIST="$(profiles list 2>/dev/null)"; then
  if echo "${PROFILE_LIST}" | grep -qiE "(MDM|management|enrollment|payload|com.apple.mdm)"; then
    echo -e "  ${FAIL} MDM-related configuration profile content detected"
    mark_detected "mdm_profile_content_detected" "request_release" "high" "profile" "MDM-related configuration profile content was detected." "high"
  elif echo "${PROFILE_LIST}" | grep -qi "attribute"; then
    echo -e "  ${WARN} Configuration profile attributes found, but MDM-specific content was not confirmed"
    mark_inconclusive "profile_attributes_without_mdm_keywords" "low" "profile" "Configuration profile attributes were present without explicit MDM keywords." "low"
  else
    echo -e "  ${PASS} No configuration profiles detected by profiles list"
  fi
else
  echo -e "  ${WARN} 'profiles list' could not run with current permissions"
  mark_partial_permissions "profiles_list_unavailable" "Configuration profile check was inconclusive because profiles list could not run."
fi

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

DAEMON_HITS=()
for dir in "/Library/LaunchDaemons" "/Library/LaunchAgents"; do
  [[ -d "${dir}" ]] || continue
  for vendor in "${MDM_VENDORS[@]}"; do
    while IFS= read -r -d '' plist; do
      DAEMON_HITS+=("$(basename "${plist}")")
    done < <(find "${dir}" -maxdepth 1 -name "${vendor}*" -print0 2>/dev/null)
  done
done

if [[ "${#DAEMON_HITS[@]}" -gt 0 ]]; then
  echo -e "  ${FAIL} MDM vendor launch daemons/agents found:"
  for hit in "${DAEMON_HITS[@]}"; do echo "       • ${hit}"; done
  mark_detected "mdm_vendor_agent_detected" "request_release" "medium" "agent" "MDM vendor launch daemon/agent files were found." "medium"
else
  echo -e "  ${PASS} No MDM vendor launch daemons or agents detected"
fi

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

TMPDIR_DEP="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_DEP}"' EXIT
REACHABLE_COUNT=0
LOCAL_OR_UNRESOLVED_COUNT=0

for domain in "${DEP_DOMAINS[@]}"; do
  (
    result="local_or_unresolved"
    output=""
    resolved_ip="$(dscacheutil -q host -a name "${domain}" 2>/dev/null | awk '/ip_address/{print $2; exit}' || true)"
    if [[ -n "${resolved_ip}" ]]; then
      if echo "${resolved_ip}" | grep -qE '^(127\.|0\.0\.0\.0|::1|::0)'; then
        output="  ${WARN} ${domain} → ${resolved_ip} (local/sinkhole resolution)"
      else
        result="reachable"
      fi
    fi
    if grep -qE "^[[:space:]]*::0[[:space:]]+${domain}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
      output="${output}"$'\n'"  ${WARN} ${domain} → ::0 (local/sinkhole hosts entry)"
    fi
    printf '%s\n' "${result}" > "${TMPDIR_DEP}/${domain}.result"
    printf '%s\n' "${output}" > "${TMPDIR_DEP}/${domain}.output"
  ) &
done
wait

for domain in "${DEP_DOMAINS[@]}"; do
  result="$(cat "${TMPDIR_DEP}/${domain}.result" 2>/dev/null || echo local_or_unresolved)"
  output="$(cat "${TMPDIR_DEP}/${domain}.output" 2>/dev/null || true)"
  [[ -n "${output}" ]] && echo -e "${output}"
  if [[ "${result}" == "reachable" ]]; then
    REACHABLE_COUNT=$((REACHABLE_COUNT + 1))
  else
    LOCAL_OR_UNRESOLVED_COUNT=$((LOCAL_OR_UNRESOLVED_COUNT + 1))
  fi
done

if [[ "${REACHABLE_COUNT}" -eq 0 ]]; then
  NETWORK_PATH="blocked_or_local"
  echo -e "  ${WARN} No reachable Apple enrollment endpoints observed in this DNS check"
  add_finding "apple_endpoint_resolution_blocked_or_local" "low" "network_path" "Apple enrollment endpoints were unresolved or locally routed in this DNS check. This is network-path evidence only." "low"
elif [[ "${LOCAL_OR_UNRESOLVED_COUNT}" -gt 0 ]]; then
  NETWORK_PATH="mixed"
  echo -e "  ${WARN} Mixed endpoint resolution: ${LOCAL_OR_UNRESOLVED_COUNT} unresolved/local, ${REACHABLE_COUNT} reachable"
  add_finding "apple_endpoint_resolution_mixed" "low" "network_path" "Apple enrollment endpoint resolution was mixed. This is network-path evidence only." "low"
else
  NETWORK_PATH="normal"
  echo -e "  ${INFO} Apple enrollment endpoints resolved to non-local addresses from this network"
fi

rm -rf "${TMPDIR_DEP}"
trap - EXIT

section "6/9 /etc/hosts Local/Sinkhole Entries"
HOSTS_LOCAL_COUNT=0
for pattern in "gdmf.apple.com" "deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com" "albert.apple.com"; do
  if grep -qE "^(127\.|0\.0\.0\.0)[[:space:]].*${pattern}" /etc/hosts 2>/dev/null; then
    HOSTS_LOCAL_COUNT=$((HOSTS_LOCAL_COUNT + 1))
  fi
done

if [[ "${HOSTS_LOCAL_COUNT}" -gt 0 ]]; then
  echo -e "  ${WARN} ${HOSTS_LOCAL_COUNT} Apple enrollment domain(s) resolve locally via /etc/hosts"
  echo "       Treat this as a network/path anomaly, not evidence of server-side release."
  [[ "${NETWORK_PATH}" == "normal" || "${NETWORK_PATH}" == "not_checked" ]] && NETWORK_PATH="blocked_or_local"
  add_finding "hosts_enrollment_domain_sinkhole" "low" "network_path" "Apple enrollment domain local/sinkhole entries were found in /etc/hosts." "low"
else
  echo -e "  ${PASS} No Apple enrollment local/sinkhole entries found in /etc/hosts"
fi

section "7/9 MDM Certificates (System Keychain)"
if CERT_OUTPUT="$(security find-certificate -a -Z /Library/Keychains/System.keychain 2>/dev/null)"; then
  if echo "${CERT_OUTPUT}" | grep -qiE "(MDM|mobile device management|management profile|jamf|mosyle|kandji|intune|simplemdm)"; then
    echo -e "  ${WARN} Possible MDM-related certificate text match in System Keychain"
    mark_inconclusive "possible_mdm_certificate_text_match" "low" "certificate" "Possible MDM-related certificate text was found in System Keychain." "low"
  else
    echo -e "  ${PASS} No MDM-related certificate text match found in System Keychain"
  fi
else
  echo -e "  ${WARN} Could not read System Keychain with current permissions"
  mark_partial_permissions "system_keychain_unavailable" "System Keychain certificate check was inconclusive with current permissions."
fi

section "8/9 DEP Enrollment Daemon (cloudconfigurationd)"
if pgrep -x "cloudconfigurationd" >/dev/null 2>&1; then
  echo -e "  ${WARN} cloudconfigurationd is running"
  echo "       This may be enrollment-related but is not proof of active management."
  mark_inconclusive "cloudconfigurationd_running" "low" "enrollment" "cloudconfigurationd was running during the scan; this is not proof of active management." "low"
else
  echo -e "  ${PASS} cloudconfigurationd is not running"
fi

section "9/9 Remote Management (ARD) Status"
if pgrep -x "ARDAgent" >/dev/null 2>&1; then
  echo -e "  ${FAIL} Remote Management (ARD) is active"
  mark_management_adjacent_detected "remote_management_active" "contact_it" "medium" "remote_management" "Remote Management / ARD agent was active." "medium"
elif launchctl list 2>/dev/null | grep -q "com.apple.RemoteDesktop.agent"; then
  echo -e "  ${FAIL} Remote Management agent is loaded"
  mark_management_adjacent_detected "remote_management_agent_loaded" "contact_it" "medium" "remote_management" "Remote Management / ARD launch agent was loaded." "medium"
else
  echo -e "  ${PASS} Remote Management appears disabled"
fi

if [[ "${NETWORK_PATH}" == "not_checked" ]]; then
  NETWORK_PATH="inconclusive"
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                    SCAN SUMMARY                         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Local MDM indicators       : ${BOLD}${LOCAL_MDM_INDICATORS}${RESET}"
echo -e "  Management-adjacent signals: ${BOLD}${MANAGEMENT_ADJACENT_INDICATORS}${RESET}"
echo -e "  Permissions                : ${BOLD}${PERMISSIONS}${RESET}"
echo -e "  Network path               : ${BOLD}${NETWORK_PATH}${RESET}"
echo -e "  ABM/ADE server-side status : ${BOLD}${ABM_ADE_SERVER_SIDE_STATUS}${RESET}"
echo -e "  Activation Lock            : ${BOLD}${ACTIVATION_LOCK}${RESET}"
echo -e "  Recommended next step      : ${BOLD}${RECOMMENDED_NEXT_STEP}${RESET}"
echo ""

if [[ "${#FINDING_IDS[@]}" -gt 0 ]]; then
  echo -e "${BOLD}Findings / caveats:${RESET}"
  for i in "${!FINDING_IDS[@]}"; do
    echo "  • ${FINDING_SUMMARIES[$i]}"
  done
  echo ""
fi

echo "This scan reports local device-visible evidence only."
echo "ABM/ADE assignment cannot be confirmed locally."
echo "Activation Lock is not checked, modified, bypassed, or removed by this tool."
echo "A scan with no local indicators is not proof of server-side release or future enrollment status."
echo "Use this tool only for devices you own or are authorized to evaluate."
echo ""

write_text_report() {
  local path="$1"
  {
    echo "MDM Liberator — Local Evidence Report"
    echo "Generated: ${TIMESTAMP_LOCAL}"
    echo ""
    echo "System"
    echo "  macOS: ${MACOS_VERSION} (${MACOS_BUILD})"
    echo "  Model: ${MODEL_ID}"
    echo "  Chip: ${CHIP_TYPE}"
    if $INCLUDE_SERIAL; then
      echo "  Serial: ${SERIAL_NUMBER:-Unknown}"
    fi
    echo ""
    echo "Classifications"
    echo "  Local MDM indicators: ${LOCAL_MDM_INDICATORS}"
    echo "  Management-adjacent signals: ${MANAGEMENT_ADJACENT_INDICATORS}"
    echo "  Permissions: ${PERMISSIONS}"
    echo "  Network path: ${NETWORK_PATH}"
    echo "  ABM/ADE server-side status: ${ABM_ADE_SERVER_SIDE_STATUS}"
    echo "  Activation Lock: ${ACTIVATION_LOCK}"
    echo "  Recommended next step: ${RECOMMENDED_NEXT_STEP}"
    echo ""
    echo "Findings"
    if [[ "${#FINDING_IDS[@]}" -eq 0 ]]; then
      echo "  None recorded."
    else
      for i in "${!FINDING_IDS[@]}"; do
        echo "  - [${FINDING_SEVERITIES[$i]}] ${FINDING_SUMMARIES[$i]}"
      done
    fi
    echo ""
    echo "Limitations"
    echo "  - ABM/ADE assignment cannot be confirmed locally."
    echo "  - Activation Lock is not checked, modified, bypassed, or removed."
    echo "  - No local indicators is not proof of server-side release or future enrollment status."
    echo "  - For devices you own or are authorized to evaluate."
  } > "${path}"
}

write_json_report() {
  local path="$1"
  {
    echo "{"
    echo "  \"tool\": \"mdm-liberator\","
    echo "  \"version\": \"1.3.1\","
    echo "  \"timestamp_local\": \"$(json_escape "${TIMESTAMP_LOCAL}")\","
    echo "  \"macos_version\": \"$(json_escape "${MACOS_VERSION}")\","
    echo "  \"macos_build\": \"$(json_escape "${MACOS_BUILD}")\","
    echo "  \"model_identifier\": \"$(json_escape "${MODEL_ID}")\","
    echo "  \"chip\": \"$(json_escape "${CHIP_TYPE}")\","
    if $INCLUDE_SERIAL; then
      echo "  \"serial_number\": \"$(json_escape "${SERIAL_NUMBER:-Unknown}")\","
    fi
    echo "  \"local_mdm_indicators\": \"${LOCAL_MDM_INDICATORS}\","
    echo "  \"management_adjacent_indicators\": \"${MANAGEMENT_ADJACENT_INDICATORS}\","
    echo "  \"permissions\": \"${PERMISSIONS}\","
    echo "  \"network_path\": \"${NETWORK_PATH}\","
    echo "  \"abm_ade_server_side_status\": \"${ABM_ADE_SERVER_SIDE_STATUS}\","
    echo "  \"activation_lock\": \"${ACTIVATION_LOCK}\","
    echo "  \"findings\": ["
    for i in "${!FINDING_IDS[@]}"; do
      [[ "$i" -gt 0 ]] && echo ","
      printf '    {"id":"%s","severity":"%s","category":"%s","summary":"%s","evidence_strength":"%s","local_only":true}' \
        "$(json_escape "${FINDING_IDS[$i]}")" \
        "$(json_escape "${FINDING_SEVERITIES[$i]}")" \
        "$(json_escape "${FINDING_CATEGORIES[$i]}")" \
        "$(json_escape "${FINDING_SUMMARIES[$i]}")" \
        "$(json_escape "${FINDING_STRENGTHS[$i]}")"
    done
    echo ""
    echo "  ],"
    echo "  \"limitations\": ["
    echo "    \"ABM/ADE assignment cannot be confirmed locally.\","
    echo "    \"Activation Lock is not checked, modified, bypassed, or removed.\","
    echo "    \"No local indicators is not proof of server-side release or future enrollment status.\""
    echo "  ],"
    echo "  \"recommended_next_step\": \"${RECOMMENDED_NEXT_STEP}\""
    echo "}"
  } > "${path}"
}

if [[ -n "${REPORT_PATH}" ]]; then
  write_text_report "${REPORT_PATH}"
  echo "Text report written locally: ${REPORT_PATH}"
fi

if [[ -n "${JSON_PATH}" ]]; then
  write_json_report "${JSON_PATH}"
  echo "JSON report written locally: ${JSON_PATH}"
fi

if [[ "${LOCAL_MDM_INDICATORS}" == "detected" || "${MANAGEMENT_ADJACENT_INDICATORS}" == "detected" ]]; then
    echo ""
    echo -e "${BOLD}Need help organizing local evidence?${RESET}"
    echo "The Evidence & Escalation Kit helps you preserve screenshots, organize local findings,"
    echo "and request written release confirmation. No bypass, removal, or ABM/ADE guarantee."
    echo "https://mdmliberator.com/evidence-kit"
fi
