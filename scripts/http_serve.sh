#!/usr/bin/env bash
# http_serve.sh
#
# Operator script to serve payloads (enumerated binaries, agents, loot helpers)
# over HTTP on port 80 from the current directory. Used to transfer tools to the
# compromised Windows host via certutil.

set -euo pipefail

PORT="${1:-80}"
cd "$(dirname "$0")/.." 2>/dev/null || true
python3 -m http.server "$PORT"
