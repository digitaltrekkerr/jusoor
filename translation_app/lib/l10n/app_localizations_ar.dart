// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'جسور';

  @override
  String get appCancel => 'إلغاء';

  @override
  String get appProceed => 'متابعة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navHistory => 'السجل';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get homeSelectTextTemplate => 'اختر قالب النص';

  @override
  String get homeSelectImageTemplate => 'اختر قالب الصورة';

  @override
  String get homeTextTemplateTitle => 'قالب النص';

  @override
  String get homeImageTemplateTitle => 'قالب الصورة';

  @override
  String get homeTargetLanguageHint => 'اللغة الهدف';

  @override
  String get langRow_targetTooltip => 'لغة الهدف';

  @override
  String get langAuto_selectTitle => 'اختر اللغة';

  @override
  String get langAuto_searchHint => 'البحث عن لغة...';

  @override
  String get homeInputHint => 'أدخل النص للترجمة...';

  @override
  String get homePasteTooltip => 'لصق من الحافظة';

  @override
  String get homePickImageTooltip => 'اختيار صورة';

  @override
  String get homeUploadFileTooltip => 'رفع ملف';

  @override
  String homeWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كلمة',
      many: '$count كلمة',
      few: '$count كلمات',
      two: 'كلمتان',
      one: 'كلمة واحدة',
      zero: 'لا توجد كلمات',
    );
    return '$_temp0';
  }

  @override
  String get homeTranslateButton => 'ترجمة';

  @override
  String get historyAutoDetected => 'تلقائي';

  @override
  String get homeClearButton => 'مسح';

  @override
  String get homeShareTooltip => 'مشاركة الترجمة';

  @override
  String get homeShareText => 'نتيجة الترجمة';

  @override
  String get homeShareSubject => 'نتيجة جسور';

  @override
  String get homeOutputTitle => 'الترجمة';

  @override
  String get homeCopyTooltip => 'نسخ الترجمة';

  @override
  String get homeCopiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String homeModelInfo(String model, int seconds) {
    return 'النموذج: $model · $seconds ثانية';
  }

  @override
  String get homeWordLimitTitle => 'تم تجاوز حد الكلمات';

  @override
  String homeWordLimitBody(int count, int limit) {
    return 'نصّك يحتوي على $count كلمة، وهذا يتجاوز الحد المسموح به وهو $limit كلمة. هل تريد المتابعة؟';
  }

  @override
  String get homeErrorSharedContent => 'تعذّر قراءة المحتوى المُشارك.';

  @override
  String get homeErrorFileBytes => 'تعذّر قراءة بيانات الملف.';

  @override
  String get shareFileTooLarge =>
      'هذا الملف كبير جدًا على الفتح (أكثر من 50 ميجابايت). اختر ملفًا أصغر.';

  @override
  String get homeFileWillBeChunked => 'سيتم ترجمة الملف على دفعات';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsApiKeys => 'مفاتيح API';

  @override
  String get settingsProviderProfiles => 'ملفات الموفّر';

  @override
  String get settingsTemplates => 'القوالب';

  @override
  String get settingsSectionOverlay => 'الترجمة العائمة';

  @override
  String get settingsSectionGeneral => 'عام';

  @override
  String get settingsSectionAdvanced => 'متقدّم';

  @override
  String get settingsDefaultTargetLanguage => 'اللغة الهدف الافتراضية';

  @override
  String get settingsWordLimit => 'حد الكلمات';

  @override
  String get settingsWordLimitHint => '5000';

  @override
  String get settingsTargetLanguageHint => 'لغة الهدف';

  @override
  String get settingsAppLanguage => 'لغة التطبيق';

  @override
  String get settingsAppLanguageSystem => 'حسب النظام';

  @override
  String get settingsAppLanguageTitle => 'لغة التطبيق';

  @override
  String get settingsFallbackProfile => 'ملف الموفّر البديل';

  @override
  String get settingsNoneOption => '(بلا)';

  @override
  String get settingsRestoreBuiltIn => 'استعادة العناصر المضمّنة';

  @override
  String get settingsAlreadyPresent => 'جميع العناصر المضمّنة موجودة بالفعل.';

  @override
  String settingsRestoredSnackbar(int profiles, int templates) {
    return 'تمت استعادة $profiles ملف(ات) و$templates قالب(ات).';
  }

  @override
  String get settingsOverlayTemplate => 'قالب الترجمة العائمة';

  @override
  String get settingsSelectOverlayTemplate => 'اختر قالب الترجمة العائمة';

  @override
  String get settingsOverlayTemplateDescription =>
      'يُستخدم لترجمة النصوص والصور داخل النافذة العائمة.';

  @override
  String get settingsOverlayTextAndImage => 'نص وصورة';

  @override
  String get settingsOverlayTextOnly => 'نص فقط';

  @override
  String get settingsOverlayImageOnly => 'صورة فقط';

  @override
  String get settingsSizeMode => 'وضع الحجم';

  @override
  String get settingsOverlaySizeModeTitle => 'وضع حجم الترجمة العائمة';

  @override
  String get settingsOverlaySizeModeDescription =>
      'اختر كيفية ملء الترجمة العائمة لشاشة الجهاز.';

  @override
  String get settingsOverlaySizeCompressed => 'مضغوط';

  @override
  String get settingsOverlaySizeFull => 'كامل';

  @override
  String get settingsOverlaySizeCompressedDescription =>
      'بطاقة عائمة في المنتصف تشغل نحو 75% من ارتفاع الشاشة، مع تعتيم بقية الخلفية.';

  @override
  String get settingsOverlaySizeFullDescription =>
      'تملأ الترجمة العائمة كامل المساحة بين شريط الحالة وشريط التنقل، دون حدود أو ظلال.';

  @override
  String get settingsSupport => 'الدعم';

  @override
  String get settingsPermissions => 'الأذونات';

  @override
  String get settingsInstructions => 'التعليمات';

  @override
  String get settingsSectionHelp => 'المساعدة والدعم';

  @override
  String get settingsArticles => 'مقالات';

  @override
  String get settingsArticlesSubtitle => 'أدلة سريعة وشروحات';

  @override
  String get settingsTips => 'نصائح';

  @override
  String get settingsTipsSubtitle => 'نصائح سريعة وأدلة خطوة بخطوة';

  @override
  String get tipsQuickTipsHeader => 'نصائح سريعة';

  @override
  String get tipsUsageHeader => 'كيفية استخدام التطبيق';

  @override
  String get tipsSetupHeader => 'الإعداد خطوة بخطوة';

  @override
  String get articleLoadError => 'تعذّر تحميل المقال.';

  @override
  String get articleRetry => 'إعادة المحاولة';

  @override
  String get pagesSupportTitle => 'دعم جسور';

  @override
  String get pagesPatreonTitle => 'ادعمنا عبر Patreon';

  @override
  String get pagesPatreonSubtitle =>
      'انضم كعضوٍ داعم للمساهمة في تمويل التطوير المستمر والحصول على مزايا حصرية للداعمين.';

  @override
  String get pagesGithubTitle => 'أعطنا نجمة على GitHub';

  @override
  String get pagesGithubSubtitle =>
      'أظهر دعمك للمشروع بوضع نجمة عليه ومتابعة الإصدارات الجديدة.';

  @override
  String get pagesWebsiteTitle => 'الموقع';

  @override
  String get pagesWebsiteSubtitle =>
      'تفضل بزيارة digitaltrekkerr.com لمعرفة المزيد عن المشروع.';

  @override
  String get pagesEmailTitle => 'البريد';

  @override
  String get pagesEmailSubtitle => 'support@digitaltrekkerr.com';

  @override
  String get pagesOpeningLink => 'يتم الفتح في المتصفح...';

  @override
  String get supportInvalidUrl => 'رابط غير صالح';

  @override
  String get pagesPermissionsTitle => 'الأذونات';

  @override
  String get pagesPermissionScreenCaptureTitle =>
      'التقاط الشاشة (ترجمة لقطات الشاشة)';

  @override
  String get pagesPermissionScreenCaptureBody =>
      'عند النقر على زر \"لقطة شاشة\" في النافذة العائمة، يُخفي جسور نافذته ويلتقط كل ما هو ظاهر على الشاشة — بما في ذلك التطبيقات الأخرى — ثم يُرسل هذه الصورة إلى مزوّد الترجمة الذي ضبطته (مثل OpenRouter أو Gemini أو OpenAI أو مزوّد مخصّص) لترجمة النصوص الموجودة فيها. لا تُحفظ الصورة على جهازك؛ يُحفظ النص المترجَم فقط في السجل. يعرض أندرويد مربع موافقة قبل أي التقاط، ويتوقف الالتقاط عند إغلاق النافذة العائمة.';

  @override
  String get pagesPermissionScreenCaptureGrant => 'جرّب الآن';

  @override
  String get pagesPermissionOverlayTitle =>
      'العرض فوق التطبيقات (النافذة العائمة)';

  @override
  String get pagesPermissionOverlayBody =>
      'يرسم جسور نافذة الترجمة العائمة فوق التطبيقات الأخرى. لا تُفتح إلا عند النقر على بلاطة \"ترجم\" في الإعدادات السريعة أو على زر النافذة العائمة. أثناء فتحها، تُعالَج اللمسات داخل المنطقة المظللة العليا بواسطة النافذة العائمة؛ ولا تعمل أبداً بشكل مخفي.';

  @override
  String get pagesPermissionOverlayGrant => 'تفعيل';

  @override
  String get pagesPermissionNotificationsTitle => 'الإشعارات';

  @override
  String get pagesPermissionNotificationsBody =>
      'يتطلب أندرويد إشعاراً مرئياً أثناء تشغيل خدمة النافذة العائمة للترجمة. يعرض هذا الإشعار عبارة \"النافذة العائمة للترجمة نشطة\" ويختفي عند إغلاق النافذة العائمة. يُستخدم فقط لإبقاء النافذة العائمة حيّة.';

  @override
  String get pagesPermissionNotificationsGrant => 'تفعيل';

  @override
  String get pagesPermissionFgsTitle =>
      'الخدمة الخلفية (محرّك النافذة العائمة)';

  @override
  String get pagesPermissionFgsBody =>
      'تبقي خدمة خلفية صغيرة النافذة العائمة تعمل أثناء استخدامك لتطبيقات أخرى. يعرضها أندرويد دائماً في قائمة التطبيقات النشطة مع إشعار. تبدأ عند فتح النافذة العائمة وتتوقف عند إغلاقها.';

  @override
  String get pagesPermissionInternetTitle => 'الوصول إلى الإنترنت';

  @override
  String get pagesPermissionInternetBody =>
      'يُرسل جسور المحتوى الذي تترجمه (النصّ الذي تكتبه، أو الملفات التي تشاركها، أو لقطات الشاشة) عبر اتصالٍ مشفّر إلى مزوّد الترجمة الذي اخترته في الإعدادات. أي شخصٍ يملك مفتاح API الخاص بك يمكنه قراءة ما يُرسَل إلى ذلك المزوّد — فاحرص على سرّية مفاتيحك وانتبه لما تترجمه.';

  @override
  String get pagesPermissionClipboardTitle =>
      'الحافظة (اللصق في النافذة العائمة)';

  @override
  String get pagesPermissionClipboardBody =>
      'يقرأ زر \"لصق\" في النافذة العائمة محتوى حافظة جهازك لتترجم النصوص المنسوخة من تطبيقات أخرى. في الإصدارات الحديثة من أندرويد قد يُفتح لفترة وجيزة نافذة شفافة مرةً واحدة، ويحتفظ جسور بالنص في الذاكرة لدقيقة واحدة كحد أقصى كاحتياط. يُمسَح المحتوى المخزَّن مؤقتًا تلقائيًا بعد مرور دقيقة. لا يُخزَّن أي شيء بشكل دائم.';

  @override
  String get pagesPermissionShareTitle => 'المشاركة من تطبيقات أخرى';

  @override
  String get pagesPermissionShareBody =>
      'يمكن لأي تطبيق فتح جسور عبر قائمة المشاركة في النظام لترجمة النصوص أو الروابط أو الملفات. يُرسَل المحتوى المُشارك إلى مزوّد الترجمة لمعالجته. هذه هي طريقة الترجمة السريعة ولا يمكن تعطيلها دون فقدان هذه الميزة.';

  @override
  String get pagesPermissionQuickSettingsTitle =>
      'بلاطة \"ترجم\" في الإعدادات السريعة';

  @override
  String get pagesPermissionQuickSettingsBody =>
      'يضيف جسور بلاطةً إلى الإعدادات السريعة (أندرويد 7 وما فوق) لفتح النافذة العائمة مباشرةً. تتطلّب تفعيل إذن النافذة العائمة.';

  @override
  String get pagesPermissionFilesTitle => 'استيراد الملفات';

  @override
  String get pagesPermissionFilesBody =>
      'تُستورد الملفات عبر منتقي ملفات النظام — أنت من يختار كل ملف، ولا يفحص جسور مساحة التخزين لديك إطلاقاً. يُرسَل نص الملف المختار إلى مزوّد الترجمة لترجمته.';

  @override
  String get pagesGrantedAtInstall => 'ممنوح عند التثبيت';

  @override
  String get pagesPermissionStatusGranted => 'ممنوح';

  @override
  String get pagesPermissionStatusDenied => 'غير ممنوح';

  @override
  String get pagesPermissionStatusPermanent => 'مرفوض نهائياً — افتح الإعدادات';

  @override
  String get pagesPermissionStatusInformational => 'مفعَّل دائماً';

  @override
  String get pagesPermissionOpenSettings => 'افتح الإعدادات';

  @override
  String get pagesPermissionSettingsHint =>
      'إذا لم يظهر مربع حوار النظام، افتح إعدادات أندرويد ← التطبيقات ← جسور ← الأذونات.';

  @override
  String get pagesInstructionsTitle => 'التعليمات';

  @override
  String get pagesHowToUseHeader => 'كيفية استخدام التطبيق';

  @override
  String get pagesHowToUseStep1 =>
      'افتح جسور واختر قالب نص أو قالب صورة من أعلى الشاشة الرئيسية.';

  @override
  String get pagesHowToUseStep2 =>
      'اختر لغتك الهدف، ثم اكتب النص أو الصقه (أو اختر صورة) في منطقة الإدخال.';

  @override
  String get pagesHowToUseStep3 =>
      'اضغط على \"ترجم\" لمشاهدة النتيجة في الأسفل. يمكنك نسخها أو مشاركتها أو فتحها في عرض الإخراج الكامل.';

  @override
  String get pagesHowToUseStep4 =>
      'للترجمة من تطبيق آخر، استخدم قائمة المشاركة في النظام واختر جسور — النصوص والروابط والصور مدعومة.';

  @override
  String get pagesHowToUseStep5 =>
      'للحصول على مترجم عائم فوق أي تطبيق، أضف بلاطة \"ترجم\" من الإعدادات السريعة واضغط عليها لفتح النافذة العائمة.';

  @override
  String get pagesHowToWritePromptsHeader => 'كيف تكتب مطالبات (prompts) جيدة';

  @override
  String get pagesHowToWritePromptsTip1 =>
      'حدّد النبرة والأسلوب المطلوبين (رسمي، عامّي، تقني، تسويقي...) ليلائم النموذج جمهورك المستهدف.';

  @override
  String get pagesHowToWritePromptsTip2 =>
      'اذكر المجال (طبي، قانوني، برمجي، ألعاب...) ليستخدم النموذج المفردات والاصطلاحات المناسبة.';

  @override
  String get pagesHowToWritePromptsTip3 =>
      'اذكر أي مصطلحات أو أسماء علامات تجارية أو أسماء منتجات يجب أن تظل بدون ترجمة.';

  @override
  String get pagesHowToWritePromptsTip4 =>
      'وضّح للنموذج كيف يتعامل مع الغموض: يفضّل الترجمة الحرفية، أم الطبيعية، أم يطلب توضيحاً، أم يختار المعنى الأكثر شيوعاً.';

  @override
  String get pagesHowToWritePromptsTip5 =>
      'حدّد صيغة المخرجات التي تريدها: نصّ عادي، أو ماركداون، أو JSON، أو سطراً بسطر مع الحفاظ على بنية المصدر.';

  @override
  String get pagesHowToWritePromptsTip6 =>
      'أرفق أمثلة قصيرة على الأسلوب المطلوب — مثالان قبل/بعد غالباً ما يكونان أبلغ من قائمة قواعد طويلة.';

  @override
  String get tplEditNewTitle => 'قالب جديد';

  @override
  String get tplEditExistingTitle => 'تعديل القالب';

  @override
  String get tplEditNameLabel => 'الاسم';

  @override
  String get tplEditNameHint => 'مثال: مترجم محترف';

  @override
  String get tplEditProfileLabel => 'ملف الموفّر';

  @override
  String get tplEditSystemPromptLabel => 'مطالبة النظام';

  @override
  String tplEditWarningMissingTarget(String target_language) {
    return 'لا تحتوي مطالبة النظام على المتغير $target_language، وقد لا تعرف الترجمة أي لغة تستخدم.';
  }

  @override
  String get tplEditResetToDefault => 'استعادة الافتراضي';

  @override
  String get tplEditSupportsText => 'يدعم النصوص';

  @override
  String get tplEditSupportsTextSubtitle =>
      'يمكن استخدام هذا القالب لترجمة النصوص.';

  @override
  String get tplEditSupportsImage => 'يدعم الصور';

  @override
  String get tplEditSupportsImageSubtitle =>
      'يمكن استخدام هذا القالب لترجمة الصور (الترجمة البصرية).';

  @override
  String get tplSubTitle => 'الاستبدال التلقائي للغة الهدف';

  @override
  String tplSubSubtitle(String target_language) {
    return 'استبدال المتغير $target_language في المطالبة باللغة المختارة قبل الإرسال.';
  }

  @override
  String get tplOutLangFixedTitle => 'لغة إخراج ثابتة (بدون متغيّر)';

  @override
  String get tplOutLangFixedSubtitle =>
      'هذا القالب يعمل بدون متغيّر اللغة المستهدفة — سيُخفى اختيار اللغة في الصفحة الرئيسية، ولن يُعيَّن للأوفّرلاي.';

  @override
  String get tplEditSaveButton => 'حفظ';

  @override
  String get tplEditErrorNameRequired => 'اسم القالب مطلوب.';

  @override
  String get tplEditErrorProfileRequired => 'يرجى اختيار ملف موفّر.';

  @override
  String get tplEditErrorPromptRequired => 'مطالبة النظام مطلوبة.';

  @override
  String get tplEditErrorCapabilityRequired =>
      'فعّل إمكانية واحدة على الأقل (نص أو صورة).';

  @override
  String get settingsThemeMode => 'وضع المظهر';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get themeLight => 'نهاري';

  @override
  String get themeDark => 'ليلي';

  @override
  String get updateAvailableTitle => 'إصدار جديد متاح';

  @override
  String get updateAvailableAction => 'تنزيل';

  @override
  String updateAvailableSubtitle(String version) {
    return 'الإصدار $version متاح.';
  }

  @override
  String get copyAsPlain => 'نسخ كنص عادي';

  @override
  String get copyAsMarkdown => 'نسخ كـ Markdown';

  @override
  String get shareAsPlain => 'مشاركة كنص عادي';

  @override
  String get shareAsMarkdown => 'مشاركة كـ Markdown (.md)';

  @override
  String get saveToFile => 'حفظ إلى ملف';

  @override
  String get copyOptionsTitle => 'خيارات النسخ';

  @override
  String get shareOptionsTitle => 'خيارات المشاركة';

  @override
  String get sheetPlainSubtitle => 'بدون تنسيق Markdown';

  @override
  String get sheetMarkdownFileSubtitle => 'ملف نصي بالتنسيق الأصلي';

  @override
  String get sheetCopyMarkdownSubtitle => 'مع التنسيق الأصلي';

  @override
  String get sheetSaveToFileSubtitle => 'اختر مكان الحفظ من ورقة المشاركة';

  @override
  String get commonName => 'الاسم';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonSave => 'حفظ';

  @override
  String get badgeBuiltIn => 'مضمّن';

  @override
  String get badgeText => 'نص';

  @override
  String get badgeImage => 'صورة';

  @override
  String get apiKeysTitle => 'مفاتيح API';

  @override
  String get apiKeysAddTooltip => 'إضافة مفتاح API';

  @override
  String get apiKeysEmptyState =>
      'لا توجد مفاتيح API بعد. اضغط + لإضافة مفتاح.';

  @override
  String get apiKeysAddNewButton => 'إضافة مفتاح جديد';

  @override
  String get apiKeysAddTitle => 'إضافة مفتاح API';

  @override
  String get apiKeysEditTitle => 'تعديل مفتاح API';

  @override
  String get apiKeysNameHint => 'مثال: OpenRouter أو Gemini';

  @override
  String get apiKeysNameRequired => 'الاسم مطلوب';

  @override
  String get apiKeysValueLabel => 'قيمة مفتاح API';

  @override
  String get apiKeysValueRequired => 'قيمة مفتاح API مطلوبة';

  @override
  String apiKeysSaveFailed(String error) {
    return 'فشل حفظ مفتاح API: $error';
  }

  @override
  String get apiKeysDeleteTitle => 'حذف مفتاح API؟';

  @override
  String apiKeysDeleteBody(String name) {
    return 'هل أنت متأكد من حذف \"$name\"؟ لا يمكن التراجع عن هذا.\n\nستتم إزالة مرجع مفتاح API من ملفات الموفّر التي تستخدمه.';
  }

  @override
  String get apiKeysEmptyValue => '(فارغ)';

  @override
  String get historySearchHint => 'البحث في الترجمات...';

  @override
  String get historyClearAllTooltip => 'مسح السجل بالكامل';

  @override
  String get historyDeletedSnackbar => 'تم حذف الترجمة';

  @override
  String get historyUndoAction => 'تراجع';

  @override
  String get historyClearAllTitle => 'مسح السجل بالكامل';

  @override
  String get historyClearAllBody =>
      'سيؤدي هذا إلى حذف كل سجل الترجمة نهائيًا. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get historyClearAllButton => 'مسح الكل';

  @override
  String historyNoResults(String query) {
    return 'لا توجد نتائج لـ \'$query\'';
  }

  @override
  String get historyEmptyState => 'لا يوجد سجل ترجمة بعد';

  @override
  String get historyLoadFailed => 'تعذّر تحميل السجل';

  @override
  String get historyToday => 'اليوم';

  @override
  String get historyYesterday => 'أمس';

  @override
  String historyDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم واحد',
      zero: 'منذ 0 يوم',
    );
    return '$_temp0';
  }

  @override
  String get historyDetailTitle => 'تفاصيل الترجمة';

  @override
  String get historyInputLabel => 'النص المُدخل';

  @override
  String get historyOutputLabel => 'الترجمة الناتجة';

  @override
  String get templatesAddTooltip => 'إضافة قالب';

  @override
  String get templatesEmptyState => 'لا توجد قوالب بعد. اضغط + لإضافة قالب.';

  @override
  String get templatesUnknownProfile => 'ملف موفّر غير معروف';

  @override
  String get templatesDeleteTitle => 'حذف القالب؟';

  @override
  String templatesDeleteBody(String name) {
    return 'هل أنت متأكد من حذف \"$name\"؟ لا يمكن التراجع عن هذا.';
  }

  @override
  String get templatesBuiltInWarning =>
      'هذا قالب مضمّن. يمكنك استعادته من الإعدادات بالضغط على \"استعادة العناصر المضمّنة\".';

  @override
  String get profilesAddTooltip => 'إضافة ملف موفّر';

  @override
  String get profilesEmptyState =>
      'لا توجد ملفات موفّر بعد. اضغط + لإضافة ملف.';

  @override
  String get profilesDeleteTitle => 'حذف ملف الموفّر؟';

  @override
  String profilesDeleteBody(String name) {
    return 'هل أنت متأكد من حذف \"$name\"؟ لا يمكن التراجع عن هذا.';
  }

  @override
  String get profilesBuiltInWarning =>
      'هذا ملف موفّر مضمّن. يمكنك استعادته من الإعدادات بالضغط على \"استعادة العناصر المضمّنة\".';

  @override
  String profilesModelLabel(String model) {
    return 'النموذج: $model';
  }

  @override
  String profilesApiKeyLabel(String name) {
    return 'مفتاح API: $name';
  }

  @override
  String get profileEditTitle => 'تعديل ملف الموفّر';

  @override
  String get profileNewTitle => 'ملف موفّر جديد';

  @override
  String get profileNameHint => 'مثال: ملف OpenRouter الخاص بي';

  @override
  String get profileProviderTypeLabel => 'نوع الموفّر';

  @override
  String get profileModelLabel => 'النموذج';

  @override
  String get profileVisionModelLabel => 'نموذج الرؤية (اختياري)';

  @override
  String get profileSelectModelHint => 'اختر نموذجًا';

  @override
  String get profileSelectApiKeyFirstHint => 'اختر مفتاح API أولًا';

  @override
  String get profileVisionModelPlaceholder => 'لترجمة الصور';

  @override
  String get profileApiKeyLabel => 'مفتاح API';

  @override
  String get profileFallbackApiKeyLabel => 'مفتاح API احتياطي (اختياري)';

  @override
  String get profileSelectModelTitle => 'اختر النموذج';

  @override
  String get profileSelectVisionModelTitle => 'اختر نموذج الرؤية';

  @override
  String get profileSelectApiKeyTitle => 'اختر مفتاح API';

  @override
  String get profileSelectFallbackApiKeyTitle => 'اختر مفتاح API الاحتياطي';

  @override
  String get profileSearchModelsHint => 'البحث عن نماذج...';

  @override
  String get profileRefreshModelsTooltip => 'تحديث النماذج';

  @override
  String profileLoadModelsFailed(String error) {
    return 'فشل تحميل النماذج: $error';
  }

  @override
  String get profileNameRequired => 'اسم ملف الموفّر مطلوب.';

  @override
  String get profileModelRequired => 'يجب اختيار نموذج.';

  @override
  String get profileBaseUrlInvalid =>
      'أدخل رابطًا صالحًا يبدأ بـ http:// أو https://.';

  @override
  String get profileBaseUrlHttpsRequired =>
      'عناوين http:// غير مسموحة للخواديم البعيدة. استخدم https:// (يُسمح بـ http فقط لـ localhost/127.0.0.1).';

  @override
  String get profileBaseUrlHttpsHint =>
      'أدخل رابطًا صالحًا يبدأ بـ https:// (أو http://localhost للنماذج المحلية).';

  @override
  String get profileOpenAiSettingsTitle => 'إعدادات متوافقة مع OpenAI';

  @override
  String get profileBaseUrlLabel => 'رابط الأساس (Base URL)';

  @override
  String get profileModelAccessTitle => 'يلزم تحديد مفتاح API أولًا';

  @override
  String get profileModelAccessBody =>
      'اختر مفتاحًا موجودًا من قائمتك، أو أضف مفتاحًا جديدًا للبدء بجلب النماذج.';

  @override
  String get profileModelAccessPickExisting => 'اختر مفتاحًا موجودًا';

  @override
  String get profileModelAccessAddNew => 'إضافة مفتاح جديد';
}
