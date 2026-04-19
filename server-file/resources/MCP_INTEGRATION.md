# تكامل بروتوكول MCP مع إطار عمل COREX

**المصدر:** [Model Context Protocol Examples](https://modelcontextprotocol.io/examples)  
**الهدف:** ربط سيرفر FiveM (COREX) بنماذج الذكاء الاصطناعي الخارجية.

---

## 1. تحليل الأمثلة وإسقاطها على COREX

بناءً على الأمثلة الموجودة في الموقع، إليك كيف يمكننا الاستفادة منها في مشروع COREX:

### أ. سيرفر الأدوات (Tools Server) - *الأكثر أهمية*
في أمثلة MCP، يتم استخدام "Tools" لتمكين الـ AI من تنفيذ أوامر.
*   **التطبيق في COREX:** إنشاء مورد يعرض وظائف `corex-core` كأدوات للـ AI.
    *   `get_player_info(source)` -> تجلب بيانات اللاعب من `Corex.Functions.GetPlayer`.
    *   `add_money(source, type, amount)` -> تستخدم `Corex.Functions.AddMoney`.
    *   `spawn_vehicle(model, coords)` -> تستخدم دوال السيرفر.

### ب. سيرفر قواعد البيانات (Database Server)
المثال يوضح الربط مع PostgreSQL/SQLite.
*   **التطبيق في COREX:** يمكن إنشاء MCP Server يتصل مباشرة بقاعدة بيانات `oxmysql` لتحليل الاقتصاد أو تتبع الغشاشين دون التأثير على أداء السيرفر الرئيسي.

### ج. سيرفر نظام الملفات (Filesystem Server)
*   **التطبيق في COREX:** قراءة ملفات السجل (Logs) وتحليلها فورياً لاكتشاف الأخطاء أو المشاكل الأمنية.

---

## 2. المقترح التقني: مورد `corex-mcp`

نقترح إنشاء مورد جديد (Resource) يعمل ببيئة **Node.js** داخل FiveM ليكون هو الجسر.

### هيكلية المورد المقترحة:
```text
[corex]/
  └── corex-mcp/
      ├── fxmanifest.lua
      ├── package.json      (dependencies: @modelcontextprotocol/sdk)
      └── src/
          └── index.ts      (سيرفر MCP الذي يعرف الأدوات)
```

### آلية العمل:
1.  يعمل `corex-mcp` كمورد FiveM عادي.
2.  يفتح اتصال Socket أو HTTP (SSE) لاستقبال أوامر MCP.
3.  عند طلب أداة (مثلاً `give_money`)، يقوم المورد باستدعاء `exports['corex-core']:GetCoreObject()` وتنفيذ الأمر.

---

## 3. خطوات التنفيذ القادمة

إذا كنت ترغب في تنفيذ هذا، يجب علينا:
1.  إنشاء المجلد `corex-mcp`.
2.  تثبيت حزمة SDK عبر NPM (يتطلب تثبيت Node.js على السيرفر).
3.  كتابة كود الـ Server Side لتعريف الأدوات (Tools).

**ملاحظة:** هذا يتطلب أن يكون لديك Node.js مثبتاً في بيئة التطوير الخاصة بك.
