#!/bin/sh
# ServiceHub public IPv4 discovery — the single source used by both
# scripts/firewall.sh (hairpin egress allow) and scripts/setup.sh (runtime env).
#
# Usage (sourced): . scripts/public-ip.sh
#   valid_ipv4 <addr>                 exit 0 when <addr> is one dotted-quad IPv4
#   detect_servicehub_public_ipv4     print one public IPv4, exit 1 if unknown
#
# Detection order: EGRESS_SELF_IP override, OCI instance metadata (v2 then v1),
# then the host's outbound IPv4 via checkip.amazonaws.com. Each request has a
# bounded timeout; nothing partial is printed on failure.

valid_ipv4() {
  awk -F. -v address="$1" 'BEGIN {
    if (split(address, octets, ".") != 4) exit 1
    for (i = 1; i <= 4; i++)
      if (octets[i] !~ /^[0-9]+$/ || octets[i] + 0 > 255) exit 1
    exit 0
  }'
}

# Return a valid public unicast IPv4, or non-zero. Rejects private, loopback,
# link-local, shared (100.64/10), multicast, reserved and unspecified values so
# a broken metadata/checkip response cannot be taken for the host address.
detect_servicehub_public_ipv4() {
  _ip=
  if [ -n "${EGRESS_SELF_IP:-}" ]; then
    _ip=$EGRESS_SELF_IP
  else
    command -v curl >/dev/null 2>&1 || return 1
    _ip=$(curl --noproxy '*' -fsS -m 2 -H 'Authorization: Bearer Oracle' \
        http://169.254.169.254/opc/v2/vnics/ 2>/dev/null ||
      curl --noproxy '*' -fsS -m 2 http://169.254.169.254/opc/v1/vnics/ 2>/dev/null || true)
    _ip=$(printf '%s' "$_ip" |
      sed -n 's/.*"publicIp"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' | head -1)
    if ! valid_ipv4 "$_ip"; then
      _ip=$(curl --noproxy '*' -4 -fsS -m 5 https://checkip.amazonaws.com 2>/dev/null |
        tr -d ' \t\n')
    fi
  fi
  valid_ipv4 "$_ip" || return 1
  # Single-line only, and public unicast only (see header comment).
  printf '%s\n' "$_ip" | awk -F. '
    NF != 4 { exit 1 }
    {
      if ($1 == 0 || $1 == 10 || $1 == 127 || $1 >= 224) exit 1
      if ($1 == 100 && $2 >= 64 && $2 <= 127) exit 1
      if ($1 == 169 && $2 == 254) exit 1
      if ($1 == 172 && $2 >= 16 && $2 <= 31) exit 1
      if ($1 == 192 && $2 == 168) exit 1
      print
    }'
}

# Offline check of validation and range rejection (no root, no network).
# Runs only when this file is executed directly, never when sourced.
if [ "${0##*/}" = "public-ip.sh" ] && [ "${1:-}" = "selftest" ]; then
  fail=0
  # Accepted public unicast addresses
  for ip in 198.51.100.7 203.0.113.9 192.0.2.10; do
    EGRESS_SELF_IP=$ip; export EGRESS_SELF_IP
    [ "$(detect_servicehub_public_ipv4)" = "$ip" ] || { echo "FAIL: accept $ip"; fail=1; }
  done
  # Rejected: empty, invalid, private, loopback, link-local, shared, multicast,
  # reserved, unspecified, IPv6, multiline.
  reject_list=' 999.0.0.1 10.0.0.1 172.16.0.1 192.168.1.1 127.0.0.1 169.254.1.1 \
100.64.0.1 224.0.0.1 255.255.255.255 0.0.0.0 2606:4700::1'
  for ip in $reject_list '198.51.100.7
198.51.100.8'; do
    EGRESS_SELF_IP=$ip; export EGRESS_SELF_IP
    detect_servicehub_public_ipv4 >/dev/null 2>&1 &&
      { echo "FAIL: reject '${ip}'"; fail=1; }
  done
  unset EGRESS_SELF_IP
  [ "$fail" -eq 0 ] && echo "ok: public IPv4 validation and range rejection"
  exit "$fail"
fi
