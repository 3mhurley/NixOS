#!/usr/bin/env bash
set -u

TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="/tmp/net-diagnose-${TS}"
LOG_FILE="${OUT_DIR}/commands.log"
SUMMARY_FILE="${OUT_DIR}/summary.txt"
JOURNAL_FILE="${OUT_DIR}/journal-network.txt"

mkdir -p "${OUT_DIR}"
touch "${LOG_FILE}" "${SUMMARY_FILE}" "${JOURNAL_FILE}"

run() {
  local title="$1"
  shift
  {
    echo
    echo "===== ${title} ====="
    echo "+ $*"
    "$@"
  } >>"${LOG_FILE}" 2>&1
}

run_sh() {
  local title="$1"
  local cmd="$2"
  {
    echo
    echo "===== ${title} ====="
    echo "+ ${cmd}"
    bash -lc "${cmd}"
  } >>"${LOG_FILE}" 2>&1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

append_summary() {
  echo "$1" >>"${SUMMARY_FILE}"
}

append_header() {
  local git_rev
  local git_dirty
  local system_store
  local nixos_ver

  git_rev="$(git -C "$(pwd)" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  if git -C "$(pwd)" diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
    git_dirty="clean"
  else
    git_dirty="dirty"
  fi
  system_store="$(readlink -f /run/current-system 2>/dev/null || echo "unknown")"
  nixos_ver="$(nixos-version 2>/dev/null || echo "unknown")"

  {
    echo "Network Diagnose Summary"
    echo "Generated: $(date -Is)"
    echo "Output dir: ${OUT_DIR}"
    echo "Config git revision: ${git_rev} (${git_dirty})"
    echo "Running system: ${system_store}"
    echo "NixOS version: ${nixos_ver}"
    echo
  } >"${SUMMARY_FILE}"
}

collect() {
  run_sh "Config revision" "git -C \"$(pwd)\" rev-parse HEAD && git -C \"$(pwd)\" status --short"
  run "Current system store path" readlink -f /run/current-system
  run "nixos-version" nixos-version

  run "System" uname -a
  run "Hostname" hostnamectl

  if has_cmd nmcli; then
    run "NM general" nmcli general status
    run "NM devices" nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status
    run "NM connections" nmcli -t -f NAME,TYPE,DEVICE,AUTOCONNECT,AUTOCONNECT-PRIORITY connection show
    run "NM active" nmcli -t -f NAME,TYPE,DEVICE connection show --active
  else
    append_summary "WARN: nmcli not found; NetworkManager checks skipped."
  fi

  run "IPv4 routes" ip -4 route show
  run "IPv4 rules" ip -4 rule show
  run "Link state" ip -br link
  run "Addr state" ip -br -4 addr

  run "resolv.conf" cat /etc/resolv.conf

  if has_cmd ss; then
    run_sh "DNS listeners (:53/:5335)" "ss -lntup | grep -E '(:53\\b|:5335\\b)' || true"
  fi

  run "systemd NetworkManager" systemctl is-active NetworkManager
  run "systemd wireguard-wg0" systemctl is-active wireguard-wg0
  run "systemd adguardhome" systemctl is-active adguardhome
  run "systemd unbound" systemctl is-active unbound

  run_sh "Ping IPv4" "ping -4 -c 1 -W 2 1.1.1.1 || true"
  run_sh "DNS resolution" "getent hosts example.com || true"

  if has_cmd curl; then
    run_sh "HTTPS check" "curl -4 --max-time 5 -I https://example.com || true"
  fi

  run_sh "Boot journal (network units)" "journalctl -b --no-pager -u NetworkManager -u wireguard-wg0 -u adguardhome -u unbound -n 400"
  bash -lc "journalctl -b --no-pager -u NetworkManager -u wireguard-wg0 -u adguardhome -u unbound -n 400" >"${JOURNAL_FILE}" 2>&1 || true
}

analyze() {
  local default_route_count
  local uses_local_dns
  local adg_state
  local unbound_state
  local wg_unit_state
  local wg_nm_profiles
  local nm_resolve1_error
  local ping_ok
  local dns_ok

  default_route_count=$(grep -cE '^default ' "${LOG_FILE}" || true)
  uses_local_dns=0
  if grep -qE '^nameserver 127\.0\.0\.1$|^nameserver ::1$' "${LOG_FILE}"; then
    uses_local_dns=1
  fi

  adg_state="unknown"
  unbound_state="unknown"
  wg_unit_state="unknown"

  if grep -A2 -F "===== systemd adguardhome =====" "${LOG_FILE}" | grep -q '^active$'; then adg_state="active"; else adg_state="inactive"; fi
  if grep -A2 -F "===== systemd unbound =====" "${LOG_FILE}" | grep -q '^active$'; then unbound_state="active"; else unbound_state="inactive"; fi
  if grep -A2 -F "===== systemd wireguard-wg0 =====" "${LOG_FILE}" | grep -q '^active$'; then wg_unit_state="active"; else wg_unit_state="inactive"; fi

  # Count only WireGuard profiles listed under "NM connections", not device state lines.
  wg_nm_profiles=$(
    awk '
      /^===== NM connections =====$/ { in_nm_conn=1; next }
      /^===== NM active =====$/ { in_nm_conn=0 }
      in_nm_conn && $0 !~ /^(\+|=====|$)/ && $0 ~ /:wireguard:/ { c++ }
      END { print c+0 }
    ' "${LOG_FILE}"
  )

  if grep -q 'org\.freedesktop\.resolve1' "${LOG_FILE}"; then
    nm_resolve1_error=1
  else
    nm_resolve1_error=0
  fi

  if awk '/^===== Ping IPv4 =====/{f=1;next}/^=====/{if(f)exit}f' "${LOG_FILE}" | grep -q '1 received'; then
    ping_ok=1
  else
    ping_ok=0
  fi

  if awk '/^===== DNS resolution =====/{f=1;next}/^=====/{if(f)exit}f' "${LOG_FILE}" | grep -Eq '^[0-9a-fA-F:.]+\s+'; then
    dns_ok=1
  else
    dns_ok=0
  fi

  append_summary "Findings"

  if [ "${default_route_count}" -eq 0 ]; then
    append_summary "- CRITICAL: No default IPv4 route detected."
    append_summary "  Likely fix: enforce ethernet autoconnect + priority and verify route metrics."
  else
    append_summary "- OK: Default IPv4 route present (${default_route_count} entries in captured output)."
  fi

  if [ "${uses_local_dns}" -eq 1 ] && { [ "${adg_state}" != "active" ] || [ "${unbound_state}" != "active" ]; }; then
    append_summary "- HIGH: resolv.conf points to localhost but adguardhome/unbound is not fully active."
    append_summary "  Likely fix: repair DNS chain startup ordering and service health."
  else
    append_summary "- OK: Local DNS chain appears aligned with resolver settings."
  fi

  if [ "${wg_nm_profiles}" -gt 0 ] && [ "${wg_unit_state}" = "active" ]; then
    append_summary "- HIGH: Mixed WireGuard control detected (NM WireGuard profile(s) + wireguard-wg0 active)."
    append_summary "  Likely fix: keep a single control plane for WG to avoid route/DNS flapping."
  fi

  if [ "${nm_resolve1_error}" -eq 1 ]; then
    append_summary "- MEDIUM: NetworkManager attempted org.freedesktop.resolve1 but systemd-resolved is unavailable."
    append_summary "  Likely fix: keep NM DNS backend consistent with your local resolver stack."
  fi

  if [ "${ping_ok}" -eq 0 ]; then
    append_summary "- HIGH: No IPv4 reachability to 1.1.1.1."
    append_summary "  Likely fix: check default-route owner (wg0 vs WAN) and WireGuard tunnel health."
  fi

  if [ "${dns_ok}" -eq 0 ]; then
    append_summary "- HIGH: DNS lookup failed."
    append_summary "  Likely fix: if resolv.conf points to localhost, verify adguardhome -> unbound upstream path."
  fi

  append_summary ""
  append_summary "Next step"
  append_summary "- Compare this report with one captured when internet is working after toggles."
  append_summary "- Start with differences in: NM active connections, default route owner, DNS service states."
}

append_header
collect
analyze

cat <<MSG
Saved network diagnostic report to:
  ${OUT_DIR}

Key files:
  ${SUMMARY_FILE}
  ${LOG_FILE}
MSG
