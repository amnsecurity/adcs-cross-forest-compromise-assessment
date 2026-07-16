# AMN SECURITY sanitized Active Directory cross-forest compromise assessment: ADCS ESC13/ESC4, Kerberos trust abuse, gMSA, RBCD, MSSQL privilege escalation.

## Title
AMN SECURITY sanitized Active Directory cross-forest compromise assessment: ADCS ESC13/ESC4, Kerberos trust abuse, gMSA, RBCD, MSSQL privilege escalation.

## Executive Summary
نفّذت **AMN SECURITY** اختبار اختراق داخلي على بيئة Active Directory مؤسسية مجزّأة تحتوي على نطاقين موثوقين من Windows. أظهر التقييم مسار اختراق كامل يبدأ من مستخدم عادي في النطاق وصولاً إلى صلاحيات مدير النطاق (Domain Administrator)، من خلال ربط سلسلة من نقاط الضعف: سوء إعدادات خدمات الشهادات (AD CS)، إساءة استخدام ثقة Kerberos العابرة بين النطاقات، كشف حسابات الخدمة المُدارة الجماعياً (gMSA)، تفويض مقيد يعتمد على الموارد (RBCD)، ورفع الصلاحيات المحلي داخل SQL Server.

تم تعمية جميع معرّفات العميل، وأسماء المضيفين، وعناوين IP، وأسماء المستخدمين، وكلمات المرور، والهاشات، والمفاتيح، وأسماء الملفات في هذا التقرير العام. لكن التسلسل التقني وشروط الخطر والتوصيات الدفاعية تبقى دقيقة وقابلة للتطبيق الفعلي.

| البند | القيمة |
|---|---|
| نوع التقييم | اختبار اختراق داخلي لـ Active Directory |
| البيئة | شبكة مؤسسية مجزّأة من Windows |
| الأثر | اختراق كامل للنطاق (أ) والنطاق (ب) |
| مستوى الوصول الابتدائي | مستخدم عادي مصادَق عليه |
| مستوى الوصول النهائي | Domain Administrator |
| الخطورة | حرجة (Critical) |
| درجة CVSS v3.1 | 9.8 |

[Additional low-level evidence was omitted from the public version.]

| Attribute | Value |
|---|---|
| CVSS / Severity | 9.8 |
## Technical Analysis
The weakness was assessed from an application-security and infrastructure-risk perspective. The core issue is classified as **Privilege Escalation** and was documented in a sanitized form suitable for public portfolio publication.

The compromise was not caused by a single vulnerability. It resulted from a chain of identity-control weaknesses:

1. Certificate templates granted enrollment to overly broad principals.
2. Issuance policies were linked to privileged authorization groups.
3. Cross-forest trust permissions were not reviewed for unintended privilege paths.
4. gMSA reader groups were modifiable by accounts outside their intended administrative boundary.
5. PowerShell history was not controlled on privileged/restricted endpoints.
6. SQL Server service accounts retained impersonation privileges and were reachable from pivoted network paths.
7. AD CS certificate templates allowed unsafe modification by non-CA administrators.

## Impact
حقق مستخدم منخفض الصلاحيات اختراقاً كاملاً لنطاقين موثوقين من Active Directory. وفر مسار الهجوم:

- وصول إدارة عن بُعد لأنظمة النطاق (أ).
- العبور إلى نطاق موثوق مجزّأ.
- قراءة مادة كلمة مرور gMSA.
- استرداد كلمات مرور صريحة من تاريخ PowerShell.
- تنفيذ أوامر عبر SQL Server.
- تنفيذ محلي كـ SYSTEM عبر إساءة استخدام صلاحية الانتحال.
- مسؤول محلي على متحكم/مضيف SQL.
- استخراج انتقائي للاعتمادات.
- السيطرة على قالب شهادة.
- مصادقة Domain Administrator عبر تسجيل شهادة مزوّر.

## Remediation
- Upgrade affected components to the fixed vendor-supported release and confirm dependency pinning across all deployment artifacts.
- Replace denylist-based validation with allowlist validation for user-controlled parameters, file paths, and integration options.
- Enforce authentication and authorization checks on every administrative, backup, and integration endpoint.
- Store secrets using a managed secret store; rotate any credential that may have been exposed during testing.
- Add regression tests for the abused code path and monitor logs for anomalous requests, process launches, or file-access patterns.
- Apply least-privilege execution for application services and isolate high-risk parsers or converters in sandboxed runtime profiles.

## Lessons Learned & Mitigation Strategy
- Treat every integration boundary as untrusted, especially when application logic forwards user-controlled values to filesystems, shells, parsers, or external tools.
- Security reviews should validate the complete exploit chain, not only the first vulnerable endpoint; low-severity misconfigurations can become critical when chained.
- Public-facing documentation should describe risk, root cause, and remediation without exposing operational identifiers, credentials, or reusable exploitation artifacts.
- Defensive controls should combine preventive validation, runtime least privilege, telemetry, and patch governance to reduce both exploitability and blast radius.

## Publication Sanitization Notes
- Sensitive infrastructure identifiers, IP addresses, hostnames, credentials, hashes, and e-mail addresses were replaced with explicit placeholders.
- Reusable operational evidence was minimized or abstracted to keep the document suitable for public GitHub publication.
- The document uses a consultant-style structure aligned with common web security testing report practices such as OWASP WSTG reporting expectations.
