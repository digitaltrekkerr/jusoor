# TASKS.md — خطة التنفيذ الشاملة

خطة موافَق عليها من المستخدم.
المرحلة أ: مقالات ثنائية اللغة + صفحة "نصائح" + إلغاء سريع.
المرحلة ب: إصلاحات PROBLEMS_REPORT.md (تغيير النماذج الافتراضية + إصلاحات متوسطة + أمن + تشغيلي).
الإصدار من 0.1.6 إلى 0.1.7 (رفع الباتش +1، حسب AGENTS.md).

**قواعد عامة:** flutter gen-l10n عند تعديل ARB، melos analyze، melos run test. لا تُلتزم حتى النهاية (التزام واحد بكل التغييرات).

---

## المرحلة أ

### أ1 — مقالات ثنائية اللغة (عربي/إنجليزي حسب لغة التطبيق)

- [ ] **أ1.1** توسيع `translation_app/lib/services/articles_service.dart`:
  - إضافة `assetEn`/`titleEn`/`excerptEn` (nullable) إلى `AppArticle`.
  - دوال: `titleFor(languageCode)` / `excerptFor(languageCode)` / `assetFor(languageCode)` مع الرجوع للعربية عند غياب الإنجليزية.
  - `loadArticleBody(article, {String? languageCode})` → يحمّل `assetFor`.
  - ملء الحقول الإنجليزية للمقالات 01–03 وإضافة 04/05/06 بالنسختين.

- [ ] **أ1.2** إنشاء ملفات `translation_app/assets/articles/`:
  - الإنجليزية: `01-what-is-jusoor.en.md`، `02-overlay-guide.en.md`، `03-security-permissions.en.md` (تُنفَّذ بعد تصحيح ب3.2).
  - الجديدة: 04 إعداد المزود+القالب+مفتاح API، 05 مفتاح Gemini من AI Studio، 06 مفتاح OpenRouter — بامتدادين `.md` (عربي) و`.en.md` (إنجليزي).
  - محتوى 04: كيفية إضافة مزود، تعيين القالب الأساسي، إدخال مفتاح API، تفعيل البروفايل الاحتياطي.
  - محتوى 05: زيارة aistudio.google.com، إنشاء مفتاح API، نسخه إلى حقل Gemini API Key.
  - محتوى 06: زيارة openrouter.ai/keys، إنشاء مفتاح، نسخه إلى حقل OpenRouter API Key.

- [ ] **أ1.3** `articles_screen.dart` و`article_screen.dart`: حلّ اللغة عبر `Localizations.localeOf(context).languageCode` واختيار العنوان/المقتطف/الأصل المناسب؛ حذف تعليق "Arabic-only by design".

- [ ] **أ1.4** تحديث `translation_app/test/articles_service_test.dart`: حذف مجموعة "ثبات المحتوى العربي"؛ إضافة ثبات ثنائي اللغة (كل مقال له en غير فارغ، `assetFor('en')` يعيد `.en.md`، الرجوع للعربية عند `assetEn == null`).

### أ2 — صفحة "نصائح" (تحت "مقالات" في الإعدادات)

- [ ] **أ2.1** `translation_app/lib/services/tips_service.dart` (جديد): `BilingualText{ar,en}` مع `resolve(languageCode)`؛ `TipsQuickTip`، `TipsSection`؛ `kTipsQuickTips`، `kTipsUsageSections`؛ `kTipsSetupArticleIds = ['04','05','06']`.

- [ ] **أ2.2** محتوى النصائح السريعة (عربي+إنجليزي):
  1. استخدم نماذج سريعة ورخيصة — أمثلة: `gemini-3.5-flash-lite`، `openai/gpt-5.6-luna`، `deepseek/deepseek-chat`، `gpt-5.4-nano`.
  2. أبقِ النص المُدخَل محدّدًا (حد الكلمات في الإعدادات).
  3. حدّد لغة الهدف دائمًا.
  4. اختر قالب النافذة العائمة المناسب (نص/صورة).
  5. استخدم ملفًا احتياطيًا (Fallback Profile).
  6. السجل قابل للبحث.

- [ ] **أ2.3** خطوات استخدام التطبيق (6 خطوات، عربي+إنجليزي):
  1. اختيار القالب → 2. لغة الهدف → 3. الإدخال → 4. الترجمة والمشاركة → 5. النافذة العائمة (أذونات + بلاط QS + زر ✕ السريع) → 6. ترجمة لقطة الشاشة.

- [ ] **أ2.4** `translation_app/lib/screens/tips_screen.dart` (جديد): 3 أقسام (نصائح سريعة / كيفية الاستخدام / الإعداد خطوة بخطوة)؛ بطاقات المقالات تفتح `ArticleScreen` عبر ids من `kTipsSetupArticleIds`.

- [ ] **أ2.5** `settings_screen.dart`: إدخال `ListTile` جديد تحت "مقالات" (أيقونة `lightbulb_outline`، `l10n.settingsTips` + `settingsTipsSubtitle`) يفتح `TipsScreen`.

- [ ] **أ2.6** مفاتيح ARB (`app_en.arb` + `app_ar.arb` ثم `flutter gen-l10n`):
  - `settingsTips` — Tips / نصائح
  - `settingsTipsSubtitle` — Quick tips & step-by-step guides / نصائح سريعة وأدلة خطوة بخطوة
  - `tipsQuickTipsHeader` — Quick tips / نصائح سريعة
  - `tipsUsageHeader` — How to use the app / كيفية استخدام التطبيق
  - `tipsSetupHeader` — Step-by-step setup / الإعداد خطوة بخطوة

- [ ] **أ2.7** اختبارات: `test/services/tips_service_test.dart` (كل العناصر ar+en غير فارغة، كل `kTipsSetupArticleIds` موجودة في `kAppArticles`)، `test/screens/tips_screen_test.dart` (رؤوس الأقسام + تبديل اللغة).

### أ3 — تسريع زر الإلغاء (الحل الكامل: CancelToken)

- [ ] **أ3.1** `packages/translation_core/lib/src/exceptions/translation_cancelled_exception.dart` (جديد): `TranslationCancelledException`؛ تصدير من `translation_core.dart`.

- [ ] **أ3.2** واجهة: `translate(TranslationRequest request, {CancelToken? cancelToken})` في `lib/src/models/translation_provider.dart`.

- [ ] **أ3.3** المزودات الثلاث (gemini/openai/openrouter): تمرير `cancelToken` إلى `_dio.post`؛ في `on DioException`: `if (CancelToken.isCancel(e)) throw const TranslationCancelledException()`؛ بعد حلقة SSE: `if (token?.isCancelled == true) throw const TranslationCancelledException()` (حالة الإغلاق الصامت).

- [ ] **أ3.4** `translation_app/lib/providers/translation_provider.dart` (Notifier): `CancelToken? _cancelToken`؛ `cancel()` يلغيه؛ `translate()` ينشئه لكل دورة؛ استقبال `TranslationCancelledException` قبل الـ fallback (`state = TranslationIdle` بدون retry).

- [ ] **أ3.5** مسار IPC `overlay_utils.dart` + `overlay_handlers.dart`: حقل عام `streamTranslationCancelToken`؛ حالة `cancel_translation` تلغيه + تلغي الاشتراك؛ `onError` لا يبث "Error" عند الإلغاء.

- [ ] **أ3.6** مسار النافذة المباشر `main.dart`: استخراج مساعدة `_runOverlayTranslation()` — `Future.any([completer.future, cancelCompleter.future])`، إكمال `cancelCompleter` في `_handleCancel`، إلغاء الاشتراك بعد السباق.

- [ ] **أ3.7** اختبارات translation_core: لكل مزود — إلغاء التوكن → `TranslationCancelledException`.

- [ ] **أ3.8** اختبار Notifier: الإلغاء → `TranslationIdle` بدون استدعاء fallback.

---

## المرحلة ب

### ب1 — النماذج الافتراضية (موافقة المستخدم: النموذجان يدعمان الصور)

- [ ] **ب1.1** `translation_app/lib/services/settings_repository.dart` — استبدال ثوابت النماذج المضمّنة:
  - OpenRouter: `openrouter/free` → `openai/gpt-5.6-luna` (نص+رؤية).
  - Gemini: `gemini-2.5-flash` → `gemini-3.5-flash-lite` (نص+رؤية).

- [ ] **ب1.2** رفع `_currentBuiltInsRevision` إلى 3 + كتلة revision-3 في `_applyBuiltInRevisions`: تحدّث النماذج فقط إذا طابقت القيم القديمة — لا تمس تخصيصات المستخدم.

- [ ] **ب1.3** تحقق يدوي على الجهاز: الـ UI يظهر النماذج الجديدة.

### ب2 — إصلاحات متوسطة سريعة

- [ ] **ب2.1 (1.3)** رسالة "النموذج لا يدعم الصور" بدل 404 خام: في مزود OpenRouter — عند طلب صورة + DioException 404 → `TranslationException` برسالة واضحة.

- [ ] **ب2.2 (2.4)** `template_edit_screen.dart`: كتم `_systemPromptMissingTargetLanguage` عند `outputLanguageFixed == true`.

- [ ] **ب2.3 (2.5)** حارس نص فارغ في المزودات الثلاث: بداية `translate()` — `if (request.inputText.trim().isEmpty && (request.imageBase64?.isEmpty ?? true)) throw TranslationException('Empty input')`.

- [ ] **ب2.4 (5.1)** `history_detail_screen.dart`: تعريب الشريحتين — مفتاح جديد `historyAutoDetected` + إعادة استخدام plural `homeWordCount` مع `{count}`.

- [ ] **ب2.5 (2.6)** `pubspec.yaml`: إعلان `intl` صراحةً؛ حذف `cupertino_icons`.

- [ ] **ب2.6 (2.1)** `openrouter_provider.dart`: حذف `bodyTemplate`، `_kDefaultBodyTemplate`، `nonStreamingResponsePath` — المزود دفق دائم.

- [ ] **ب2.7 (2.2)** `openai_compatible_provider.dart`: تمرير حقل `stream` إلى جسم النص (أو حذفه إن ثَبُت أن `stream:false` لا يُضبَط أبدًا).

### ب3 — الأمن

- [ ] **ب3.1 (3.1)** حذف مسار `show_overlay_direct` كليًا:
  - `MainActivity.kt`: فرع `handleIntent` بالكامل + فرع `checkShowOverlayDirect` + مفاتيح prefs.
  - حذف `OverlayLaunchGuard.kt` كليًا.
  - حذف Dart `checkShowOverlayDirect` من `overlay_handlers.dart`.
  - حذف `lib/utils/overlay_launch_guard.dart` + اختباراته.

- [ ] **ب3.2 (3.2)** فرض `https://` على baseUrl في `profile_edit_screen.dart`: السماح بـ `http://` فقط لـ localhost/127.0.0.1/[::1]؛ رسالة وحظر الحفظ. تصحيح فقرة المقال 03 (L60).

- [ ] **ب3.3 (3.3)** سقف 50MB لمشاركة الملفات:
  - Dart `parseSharedFile`: `file.length()` قبل `readAsBytes()`.
  - Kotlin `readContentUri`: `openAssetFileDescriptor(uri,'r')?.length` قبل القراءة + كائن نتيجة يشير للكبرياء.
  - مفتاح ARB `shareFileTooLarge`.

### ب4 — تشغيلي ومنخفض

- [ ] **ب4.1 (2.7/4.4)** `update_checker_service.dart`: تصحيح التعليق (ثلاثة `jusoor-<abi>.apk`) + اختيار ABI عبر `Build.SUPPORTED_ABIS` من قناة موجودة.

- [ ] **ب4.2 (5.2)** تغطية استدعاءات `debugPrint` بـ `if (kDebugMode)` (أعلى: main.dart 27، settings_repository 19، overlay_handlers 16).

- [ ] **ب4.3 (4.2)** `.github/workflows/release.yml`:
  - إضافة `on: push: tags: ['v*']`.
  - عند التاج: `tag_name: ${{ github.ref_name }}`؛ `prerelease: false`.
  - عند main: إبقاء `build-<sha>` مع `prerelease: true`.
  - هكذا `releases/latest` هو semver ويعمل شريط التحديث.

---

## الاختبار والتحقق

- [ ] **ت1** `flutter gen-l10n` + `melos analyze` + `melos run test` (أخضر بالكامل).
- [ ] **ت3** E2E على redroid عبر مهارة `android-use`:
  - لغة التطبيق إنجليزية → المقالات بالإنجليزية؛ عربية → عربي.
  - "نصائح" تحت "مقالات" تفتح الصفحة بكل الأقسام والروابط.
  - إلغاء الترجمة: توقف فوري (لا fallback/خطأ).
  - النماذج الافتراضية: OpenRouter `gpt-5.6-luna`، Gemini `3.5-flash-lite`.
  - حفظ `http://192.168..` محظور؛ `http://localhost:11434` مقبول.
  - لا تحذير قالب مع "لغة إخراج ثابتة".
  - رقاقات التاريخ معرّبة.
  - `am start --ez show_overlay_direct true` → مرفوض.
  - إن وُجد مفتاح API: ترجمة حقيقية تنجح على الافتراضي الجديد.

## الالتزام النهائي (بدون push) — V2 فوق V1 مباشرة

- [ ] **ن1** رفع الإصدار `translation_app/pubspec.yaml`: `0.1.6` → `0.1.7`.
- [ ] **ن2** `flutter gen-l10n` + `melos analyze` + `melos run test` (أخضر بالكامل).
- [ ] **ن3** بناء: `flutter clean && flutter build apk --release --split-per-abi`.
- [ ] **ن4** دمج كل التعديلات في التزام واحد فوق V1:
     ```bash
     git reset --soft 158d206    # V1 — يعيد جميع التغييرات إلى الـ staging
     git commit -m "V2 — 0.1.7: bilingual articles, tips page, fast cancel, audit fixes"
     ```
     (5 التزامات وسيطة تختفي — تذهب إلى V2 واحد مباشرة بعد V1).
- [ ] **ن5** بدون `git push`.

## مؤجّل صراحةً (خارج النطاق)

- 3.4 تشفير التاريخ/TLS pinning
- 4.3 توثيق versionCode
- 5.3 إعادة هيكلة الكتل الكبيرة
- 3.3 الدفْق الحقيقي للنصوص
- 4.1 دفع الـ 5 التزامات القديمة + تحقق أسرار GitHub