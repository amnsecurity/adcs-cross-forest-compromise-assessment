#!/usr/bin/env bash
# ligolo_proxy.sh
#
# Operator script to launch the Ligolo-ng proxy with a self-signed certificate.
# Used to establish a TUN pivot from the compromised host into a segmented
# (trusted) network during the cross-forest portion of the assessment.

set -euo pipefail

# Adjust this path to your ligolo-ng proxy binary
PROXY_BIN="/opt/ligolo-ng/proxy"

sudo "$PROXY_BIN" -selfcert -laddr 0.0.0.0:11601 -daemon -nobanner
