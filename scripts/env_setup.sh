#!/usr/bin/env bash
# env_setup.sh
#
# Operator script used to prepare the assessment environment for an AD CS / Kerberos
# engagement: time sync, /etc/hosts mapping, and krb5.conf template deployment.
#
# Sanitised reusable version. Set the placeholders below for your engagement.
# No real client identifiers, IPs, or credentials are included.

set -euo pipefail

# ─────────────────────────────────────────────
# EDIT THESE PLACEHOLDERS FOR YOUR ENGAGEMENT
# ─────────────────────────────────────────────
TARGET=""                 # DC IP of the primary domain (e.g. 10.10.10.10)
LHOST=""                  # Your attack host IP on the VPN tunnel
DOMAIN="corp.local"       # Primary domain FQDN
REALM="CORP.LOCAL"        # Primary domain realm (uppercase)
DC="dc-a01.corp.local"    # Primary DC FQDN
SECONDARY_DC="dc-b01.trust.local"
SECONDARY_DOMAIN="trust.local"
SECONDARY_IP="192.168.2.2" # Example internal IP behind the pivot (replace as needed)
# ─────────────────────────────────────────────

if [ -z "$TARGET" ]; then
  echo "Set TARGET in the script or pass it." >&2
  exit 1
fi

# Detect LHOST from the VPN tunnel if not set
if [ -z "$LHOST" ]; then
  LHOST="$(ip -4 addr show tun0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
fi
[ -z "$LHOST" ] && LHOST="$(ip -4 route get "$TARGET" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1)"
[ -z "$LHOST" ] && { echo "Could not detect LHOST. Is the VPN connected?" >&2; exit 1; }

# Sync clock (Kerberos is time-sensitive)
sudo systemctl stop systemd-timesyncd 2>/dev/null || true
sudo ntpdate -u "$TARGET" || true

# Map hosts
sudo cp /etc/hosts "/root/env_hosts.bak.$(date +%s)" 2>/dev/null || true
sudo sed -i "/$DOMAIN/d;/$SECONDARY_DOMAIN/d" /etc/hosts
printf '%s %s %s\n' "$TARGET" "$DC" "$DOMAIN" | sudo tee -a /etc/hosts >/dev/null
printf '%s %s %s\n' "$SECONDARY_IP" "$SECONDARY_DC" "$SECONDARY_DOMAIN" | sudo tee -a /etc/hosts >/dev/null

# Deploy krb5.conf template
sudo cp /etc/krb5.conf "/root/env_krb5.bak.$(date +%s)" 2>/dev/null || true
sudo cp "$(dirname "$0")/../config/krb5.conf.template" /etc/krb5.conf

cat <<EOF
[+] Environment ready
    TARGET=$TARGET
    LHOST=$LHOST
    DC=$DC
    Hosts updated for $DC and $SECONDARY_DC
EOF
