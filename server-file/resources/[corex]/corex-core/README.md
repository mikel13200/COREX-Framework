# COREX Framework

إطار أساسي موجه لألعاب الزومبي والبقاء في `FiveM`.

المنظومة الحالية تحفظ بياناتها الدائمة في جدولين فقط:
- `players`
- `inventories`

## التثبيت

1. استورد الملف `sql/corex_framework.sql` داخل قاعدة البيانات.
2. تأكد أن `oxmysql` يعمل قبل `corex-core`.
3. أضف إلى `server.cfg`:

```cfg
ensure oxmysql
ensure corex-core
ensure corex-inventory
ensure corex-spawn
```

## ماذا ينشئ ملف SQL

الملف الموحد ينشئ هذه الجداول:
- `players`
- `inventories`

ولا توجد حاليًا جداول إضافية مطلوبة لـ:
- `corex-spawn`
- `corex-hud`
- `corex-weather`
- `corex-zombies`
- `corex-zones`

لأن هذه الموارد تعتمد على:
- `StateBag`
- بيانات `metadata`
- وذاكرة السيرفر أثناء التشغيل

## ملاحظات مهمة

- إذا حذفت البيانات بالكامل ثم استوردت الملف الجديد، فاللاعبون الجدد سيُعاد إنشاؤهم تلقائيًا عند الدخول.
- بيانات `skin` و`lastPosition` وحالات البقاء مثل `hunger` و`thirst` و`stress` و`infection` تُحفَظ كلها داخل `players.metadata`.
- بيانات الأغراض و`hotbar` محفوظة داخل جدول `inventories`.

## المرجع الرسمي

الملفان الرسميان للاستخدام اليومي:
- `README.md`
- `corex_api.md`

إذا وجدت دالة في الكود وغير موجودة في `corex_api.md`، فاعتبرها إما داخلية أو توافقًا قديمًا.
