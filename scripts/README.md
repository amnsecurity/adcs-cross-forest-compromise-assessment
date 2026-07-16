# Operator Scripts — Sanitized

This directory contains the **original code written during the assessment**, not the
third-party tools that were downloaded and used (e.g. `winrmexec`, `certipy`,
`bloodyAD`, `impacket`, `SharpHound`, `nc.exe`, `GodPotato`, `ligolo` agent/binary).

All scripts here are sanitized: no real client identifiers, hostnames, IP addresses,
usernames, passwords, hashes, or sensitive proof artifacts are included. Replace the placeholders at the
top of each script with your engagement values.

## Scripts

| Script | Purpose |
|---|---|
| `psrp_restricted_history.py` | Python (pypsrp) script to read PowerShell console history from a *restricted* WinRM endpoint via Kerberos. This was the key original code that recovered reusable credentials from `ConsoleHost_history.txt`. |
| `env_setup.sh` | Prepares the environment: time sync for Kerberos, `/etc/hosts` mapping, and `krb5.conf` deployment. |
| `initial_access.sh` | Implements the AD CS ESC13 initial-access chain: TGT → `certipy find` → `certipy req` → `certipy auth`. |
| `ligolo_proxy.sh` | Launches the Ligolo-ng proxy with a self-signed certificate for the TUN pivot. |
| `http_serve.sh` | Serves payloads over HTTP for transfer to the target via `certutil`. |
| `winrm_target.sh` | Wrapper around `winrmexec.py` for a Kerberos-authenticated WinRM shell. |

## Configuration Templates

| File | Purpose |
|---|---|
| `../config/krb5.conf.template` | Multi-realm Kerberos configuration for the two trusted domains. |
| `../config/ligolo-ng.yaml` | Ligolo-ng autobind config that brings up a TUN interface and routes the segmented network. |

## Requirements

```bash
pip install pypsrp krb5 gssapi        # for psrp_restricted_history.py
apt-get install ntpdate               # for env_setup.sh
```

## Legal Notice

These scripts are provided for authorized security testing and educational purposes
only. Unauthorized use is illegal. Always obtain written authorization before
performing security testing.
