#!/usr/bin/env bash
# winrm_target.sh
#
# Operator wrapper around winrmexec.py to obtain a Kerberos-authenticated WinRM
# shell on a target domain controller. Requires a valid KRB5CCNAME in the
# environment (e.g. from certipy auth or getTGT.py).
#
# Usage:
#   export KRB5CCNAME=user.ccache
#   ./winrm_target.sh dc-a01.corp.local -k
#   ./winrm_target.sh dc-a01.corp.local -k -X 'whoami /all'

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <TARGET_DC> [winrmexec args...]" >&2
  exit 1
fi

TARGET_DC="$1"
shift

python3 /opt/winrmexec/winrmexec.py "$TARGET_DC" -k "$@"
