# 🚀 دليل التثبيت والإعداد - Daily Cash/Bank Register

---

## 📋 المتطلبات

### System Requirements:
- ✅ **Odoo Version:** 18.0
- ✅ **Python:** 3.10+
- ✅ **Dependencies:** `account` module (مثبت افتراضياً)
- ✅ **Database:** PostgreSQL 12+

### User Requirements:
- ✅ صلاحيات Accounting/Accountant أو أعلى
- ✅ Company مُعدّة بشكل صحيح
- ✅ Chart of Accounts مُعدّ
- ✅ Bank/Cash Journals مُعدّة

---

## 📦 التثبيت

### الطريقة 1: التثبيت اليدوي

#### الخطوة 1: نسخ الملفات
```bash
# انتقل لمجلد addons
cd /path/to/odoo/addons/

# انسخ المجلد
cp -r /path/to/daily_cash_register ./

# تأكد من الصلاحيات
sudo chown -R odoo:odoo daily_cash_register
sudo chmod -R 755 daily_cash_register
```

#### الخطوة 2: إعادة تشغيل Odoo
```bash
# إعادة تشغيل الخدمة
sudo systemctl restart odoo

# أو إذا كنت تستخدم script
/path/to/odoo/odoo-bin --stop-after-init -d your_database

# ثم ابدأ من جديد
/path/to/odoo/odoo-bin -d your_database
```

#### الخطوة 3: تفعيل Developer Mode
1. اذهب إلى: **Settings**
2. انزل لأسفل
3. اضغط على **Activate the developer mode**

#### الخطوة 4: تحديث قائمة التطبيقات
1. اذهب إلى: **Apps**
2. في Developer Mode، اضغط على **Update Apps List**
3. اضغط **Update** في الـ popup

#### الخطوة 5: تثبيت الموديول
1. ابحث عن: **"Daily Cash"** أو **"Daily Register"**
2. اضغط **Install**
3. انتظر حتى ينتهي التثبيت

---

### الطريقة 2: التثبيت من ZIP

#### الخطوة 1: رفع الملف
```bash
# فك ضغط الملف
unzip daily_cash_register.zip -d /path/to/odoo/addons/

# تأكد من الصلاحيات
sudo chown -R odoo:odoo /path/to/odoo/addons/daily_cash_register
```

#### الخطوة 2-5: نفس الخطوات أعلاه

---

## ⚙️ الإعداد الأولي

### 1. إعداد الجورنال (Journal)

**لازم يكون عندك Bank أو Cash Journal:**

#### إعداد Bank Journal:
1. اذهب إلى: **Accounting → Configuration → Journals**
2. افتح Bank Journal الموجود أو اعمل جديد
3. تأكد من:
   - **Type:** Bank
   - **Default Account:** حساب البنك (مثلاً: 1011 - Bank ABC)
   - **Currency:** العملة المستخدمة

#### إعداد Cash Journal:
1. اذهب إلى: **Accounting → Configuration → Journals**
2. افتح Cash Journal أو اعمل جديد
3. تأكد من:
   - **Type:** Cash
   - **Default Account:** حساب الصندوق (مثلاً: 1001 - Cash)
   - **Currency:** العملة المستخدمة

**مثال إعداد:**
```
Journal Name: بنك ABC
Short Code: BNK1
Type: Bank
Default Account: 1011 - Bank ABC Account
Currency: AED
```

---

### 2. إعداد Chart of Accounts

تأكد من وجود الحسابات التالية (على الأقل):

#### حسابات الأصول (Assets):
- ✅ **1001** - Cash / الصندوق
- ✅ **1011** - Bank / البنك

#### حسابات المصروفات (Expenses):
- ✅ **6001** - Rent Expense / إيجار
- ✅ **6002** - Salaries / رواتب
- ✅ **6003** - Utilities / مرافق
- ✅ **6004** - Office Supplies / مستلزمات مكتبية

#### حسابات الإيرادات (Income):
- ✅ **4001** - Sales Revenue / إيرادات المبيعات
- ✅ **4002** - Service Revenue / إيرادات الخدمات

#### حسابات أخرى:
- ✅ **1201** - Accounts Receivable / عملاء
- ✅ **2001** - Accounts Payable / موردين

**إذا لم تكن موجودة:**
1. اذهب إلى: **Accounting → Configuration → Chart of Accounts**
2. اضغط **Create**
3. املأ البيانات وحفظ

---

### 3. إعداد الصلاحيات (Access Rights)

#### للمحاسبين (Accountants):
1. اذهب إلى: **Settings → Users & Companies → Users**
2. افتح المستخدم
3. في تبويب **Access Rights**:
   - **Accounting:** Accountant
   - **Bank:** Show Full Accounting Features (اختياري)

#### لمدير الحسابات (Manager):
- **Accounting:** Accountant + Adviser

---

## 🧪 الاختبار

### Test 1: إنشاء سجل بسيط

1. اذهب إلى: **Daily Register → Daily Registers → Create**
2. املأ:
   - **Date:** اليوم
   - **Journal:** Bank ABC
3. أضف سطر:
   - **Description:** تجربة
   - **Account:** Rent Expense
   - **Debit:** 100
4. اضغط **Post**

**✅ النتيجة المتوقعة:**
- Status يتحول لـ Posted
- Journal Entry يتم إنشاؤه
- رسالة نجاح تظهر

---

### Test 2: التحقق من القيد

1. اضغط على **View Journal Entry**
2. تأكد من:
   - ✅ سطران موجودان
   - ✅ Total Debit = Total Credit = 100
   - ✅ الحسابات صحيحة

---

### Test 3: منع التكرار

1. حاول إنشاء register جديد لنفس اليوم ونفس الجورنال
2. أضف سطور
3. حاول Post

**✅ النتيجة المتوقعة:**
- رسالة خطأ تظهر
- يمنعك من الحفظ/Post

---

## 🐛 حل المشاكل الشائعة

### Problem 1: Module not found
**الأعراض:**
```
Module 'daily_cash_register' not found
```

**الحل:**
```bash
# تأكد من المسار
ls -la /path/to/odoo/addons/daily_cash_register

# تحقق من __manifest__.py
cat /path/to/odoo/addons/daily_cash_register/__manifest__.py

# أعد تشغيل Odoo مع update
/path/to/odoo/odoo-bin -d database -u daily_cash_register
```

---

### Problem 2: Access Rights Error
**الأعراض:**
```
Access Denied: You don't have permission...
```

**الحل:**
1. تحقق من صلاحيات المستخدم
2. تأكد من تثبيت الموديول بشكل صحيح
3. أعد تسجيل الدخول

```bash
# أو حدّث الصلاحيات
/path/to/odoo/odoo-bin -d database -u daily_cash_register --stop-after-init
```

---

### Problem 3: Journal Account Missing
**الأعراض:**
```
The selected journal does not have a default account
```

**الحل:**
1. اذهب إلى: **Accounting → Configuration → Journals**
2. افتح الجورنال
3. في **Account Configuration**:
   - املأ **Default Account**
4. احفظ

---

### Problem 4: Database Error
**الأعراض:**
```
psycopg2.errors.UniqueViolation...
```

**الحل:**
```bash
# أعد إنشاء الجداول
/path/to/odoo/odoo-bin -d database -u daily_cash_register --stop-after-init

# أو drop وأعد التثبيت
# في Odoo:
Apps → Daily Register → Uninstall
Apps → Daily Register → Install
```

---

### Problem 5: Lines Not Saving
**الأعراض:**
- السطور تختفي عند الحفظ

**الحل:**
1. تحقق من constraint errors في logs
2. تأكد من:
   - الحساب موجود
   - Debit أو Credit مملوء (ليس كلاهما)
   - الأرقام موجبة

---

## 📊 تكوين متقدم

### Multi-Company Setup

إذا كان عندك أكثر من شركة:

1. **لكل شركة:**
   - Chart of Accounts خاص
   - Journals خاصة
   - Registers منفصلة

2. **الصلاحيات:**
   - حدد للمستخدم الشركات المسموحة
   - الـ registers تظهر حسب الشركة

---

### Security Groups

**إنشاء مجموعة مخصصة:**

1. اذهب إلى: **Settings → Users & Companies → Groups**
2. اعمل Group جديد: "Daily Register User"
3. أضف Permissions:
   - Daily Cash Register: Read + Write + Create
   - Daily Cash Register Line: Read + Write + Create

---

### Automated Actions (اختياري)

**إنشاء تذكير يومي:**

1. اذهب إلى: **Settings → Technical → Automation → Automated Actions**
2. اعمل Action جديد:
   - **Model:** Daily Cash Register
   - **Trigger:** On Create
   - **Action:** Send Email
   - **Template:** إنشئ template للتذكير

---

## 📈 Performance Tips

### للبيئات الكبيرة:

```python
# في config file أو server parameters
[options]
db_maxconn = 64
workers = 4
max_cron_threads = 2
```

### Database Indexing:
```sql
-- في PostgreSQL
CREATE INDEX IF NOT EXISTS daily_register_date_journal_idx 
ON daily_cash_register(date, journal_id);
```

---

## 🔄 التحديث (Upgrade)

### من نفس الإصدار:

```bash
# 1. خذ backup
pg_dump database_name > backup.sql

# 2. استبدل الملفات
rm -rf /path/to/odoo/addons/daily_cash_register
cp -r /new/daily_cash_register /path/to/odoo/addons/

# 3. أعد تشغيل وحدّث
sudo systemctl restart odoo
# في Odoo UI: Apps → Daily Register → Upgrade
```

---

## 🗑️ إلغاء التثبيت (Uninstall)

### الطريقة الآمنة:

1. **احذف جميع السجلات:**
   - Daily Register → Daily Registers → Select All → Delete

2. **إلغاء التثبيت:**
   - Apps → Daily Register → Uninstall

3. **حذف الملفات (اختياري):**
```bash
rm -rf /path/to/odoo/addons/daily_cash_register
```

**⚠️ تحذير:**
إلغاء التثبيت سيحذف جميع البيانات!

---

## 📞 الدعم الفني

### Log Files:

تحقق من logs في:
```bash
# Ubuntu/Debian
/var/log/odoo/odoo-server.log

# أو
tail -f /var/log/odoo/odoo-server.log | grep daily_cash_register
```

### Debug Mode:

شغل Odoo في debug mode:
```bash
/path/to/odoo/odoo-bin -d database --log-level=debug
```

---

## ✅ Checklist التثبيت

- [ ] نسخ الملفات
- [ ] إعادة تشغيل Odoo
- [ ] Update Apps List
- [ ] تثبيت الموديول
- [ ] إعداد Journals
- [ ] إعداد Chart of Accounts
- [ ] إعداد الصلاحيات
- [ ] اختبار إنشاء register
- [ ] اختبار Post
- [ ] التحقق من Journal Entry

---

## 🎓 Next Steps

بعد التثبيت:
1. ✅ درّب المحاسبين على استخدام النظام
2. ✅ اعمل registers تجريبية
3. ✅ راجع القيود المحاسبية
4. ✅ ابدأ الاستخدام الفعلي

---

**Version:** 18.0.1.0.0  
**Last Updated:** 12-Nov-2025

**جاهز للعمل!** 🎉
