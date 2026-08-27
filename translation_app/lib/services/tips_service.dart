/// Bilingual (Arabic-first, English fallback) text content for the Tips
/// screen. Each entry carries both the Arabic and English strings; callers
/// resolve the right one from the active app locale.
class BilingualText {
  /// Arabic (canonical) string.
  final String ar;

  /// English string. Falls back to [ar] when `null`.
  final String en;

  const BilingualText({required this.ar, required this.en});

  /// Returns the string for [languageCode] (`en` → English when available,
  /// otherwise Arabic).
  String resolve(String languageCode) =>
      languageCode == 'en' ? en : ar;
}

/// A single quick tip shown on the Tips screen.
class TipsQuickTip {
  /// Tip title.
  final BilingualText title;

  /// Tip body.
  final BilingualText body;

  const TipsQuickTip({required this.title, required this.body});
}

/// A usage section (a numbered step) shown on the Tips screen.
class TipsUsageStep {
  /// Step title.
  final BilingualText title;

  /// Step body.
  final BilingualText body;

  const TipsUsageStep({required this.title, required this.body});
}

/// Quick tips rendered under "Quick tips".
///
/// Short, actionable advice about fast & cheap models, word limits, target
/// language, overlay templates, fallback profiles, and searchable history.
const List<TipsQuickTip> kTipsQuickTips = [
  TipsQuickTip(
    title: BilingualText(
      ar: 'استخدم نماذج سريعة ورخيصة',
      en: 'Use fast, cheap models',
    ),
    body: BilingualText(
      ar:
          'نماذج مثل gemini-3.5-flash-lite (Gemini) أو openai/gpt-5.6-luna '
          'و deepseek/deepseek-chat (OpenRouter) تعطي ترجمة سريعة وبتكلفة '
          'شبه معدومة للمهام اليومية. احتفظ بالنماذج الكبيرة للمهام المعقدة.',
      en:
          'Models like gemini-3.5-flash-lite (Gemini) or openai/gpt-5.6-luna '
          'and deepseek/deepseek-chat (OpenRouter) translate fast at nearly '
          'zero cost for daily use. Save the big models for complex tasks.',
    ),
  ),
  TipsQuickTip(
    title: BilingualText(
      ar: 'أبقِ النص المُدخَل محدّدًا',
      en: 'Keep your input focused',
    ),
    body: BilingualText(
      ar:
          'اضبط حد الكلمات في الإعدادات واقسم النصوص الطويلة إلى فقرات '
          'مستقلة. يُحسّن ذلك دقة الترجمة ويُسرّعها في آنٍ واحد.',
      en:
          'Set the word limit in Settings and split long texts into separate '
          'paragraphs. This improves both translation accuracy and speed.',
    ),
  ),
  TipsQuickTip(
    title: BilingualText(
      ar: 'حدّد لغة الهدف دائمًا',
      en: 'Always set a target language',
    ),
    body: BilingualText(
      ar:
          'اختر لغة الهدف قبل الترجمة من الشاشة الرئيسية أو النافذة العائمة. '
          'يوفر المزود تقدير لغة المصدر تلقائيًا، لكن الهدف الواضح يمنع '
          'النتائج غير المتوقعة للنصوص المختلطة.',
      en:
          'Pick a target language before translating, on the home screen or '
          'the overlay. The provider auto-detects the source language, but a '
          'clear target prevents surprises with mixed-language text.',
    ),
  ),
  TipsQuickTip(
    title: BilingualText(
      ar: 'اختر قالب النافذة العائمة المناسب',
      en: 'Pick the right overlay template',
    ),
    body: BilingualText(
      ar:
          'من الإعدادات ← الترجمة العائمة اختر قالبًا يدعم النصوص (نص وصورة) '
          'للعمل فوق أي تطبيق، أو «نص فقط» إن كنت لا تستخدم لقطات الشاشة. '
          'القالب الصحيح يجعل النافذة أخف وأسرع.',
      en:
          'From Settings ← Floating Overlay pick a template that supports '
          'text & image for use above any app, or text-only if you do not '
          'use screenshots. The right template keeps the overlay light and '
          'fast.',
    ),
  ),
  TipsQuickTip(
    title: BilingualText(
      ar: 'استخدم ملفًا احتياطيًا (Fallback Profile)',
      en: 'Set up a fallback profile',
    ),
    body: BilingualText(
      ar:
          'من الإعدادات ← ملفات المزوّدين عيّن ملفًا بديلًا بمزوّد مختلف. '
          'إذا فشل المزوّد الأساسي (مفتاح خاطئ أو انقطاع خدمة) تتولى الترجمة '
          'تلقائيًا دون أن تكسر تدفق عملك.',
      en:
          'In Settings ← Provider Profiles, set a fallback profile with a '
          'different provider. If the primary provider fails (bad key or '
          'outage), the fallback takes over automatically without breaking '
          'your flow.',
    ),
  ),
  TipsQuickTip(
    title: BilingualText(
      ar: 'استخدم السجل القابل للبحث',
      en: 'Use the searchable history',
    ),
    body: BilingualText(
      ar:
          'كل ترجمة تُحفظ في السجل المحلي. افتح تبويب السجل وابحث عن ترجمة '
          'قديمة لنسخها أو مشاركتها — لا حاجة لإعادة الترجمة من الصفر.',
      en:
          'Every translation is saved to local history. Open the History tab '
          'and search for an old translation to copy or share — no need to '
          're-translate from scratch.',
    ),
  ),
];

/// Step-by-step usage sections rendered under "How to use the app".
const List<TipsUsageStep> kTipsUsageSteps = [
  TipsUsageStep(
    title: BilingualText(
      ar: '1. اختر القالب',
      en: '1. Pick a template',
    ),
    body: BilingualText(
      ar:
          'افتح الشاشة الرئيسية واختر قالب الترجمة من القائمة العلوية. '
          'القالب يحدد أسلوب الترجمة والمزود المستخدم.',
      en:
          'Open the home screen and pick a translation template from the '
          'top dropdown. The template defines the style and the provider.',
    ),
  ),
  TipsUsageStep(
    title: BilingualText(
      ar: '2. حدد لغة الهدف',
      en: '2. Set the target language',
    ),
    body: BilingualText(
      ar:
          'اختر اللغة التي تريد الترجمة إليها من القائمة المنسدلة بجانب زر '
          'الترجمة. اللغة المصدر تُقدَّر تلقائيًا.',
      en:
          'Choose the language you want to translate into from the dropdown '
          'next to the translate button. The source language is detected '
          'automatically.',
    ),
  ),
  TipsUsageStep(
    title: BilingualText(
      ar: '3. أدخل النص أو الصورة',
      en: '3. Enter text or an image',
    ),
    body: BilingualText(
      ar:
          'اكتب النص أو الصقه، أو شارك محتوى إلى جسور من أي تطبيق، '
          'أو ارفع ملفًا من الشاشة الرئيسية.',
      en:
          'Type or paste text, share content into Jusoor from any app, or '
          'upload a file from the home screen.',
    ),
  ),
  TipsUsageStep(
    title: BilingualText(
      ar: '4. ترجم وشارك',
      en: '4. Translate and share',
    ),
    body: BilingualText(
      ar:
          'اضغط «ترجم» وسترى النتيجة تتدفق. عند الانتهاء يمكنك النسخ، '
          'المشاركة، أو الحفظ كملف Markdown عبر الأزرار أسفل النتيجة.',
      en:
          'Press Translate and watch the result stream in. When done you can '
          'copy, share, or save as a Markdown file via the buttons below the '
          'result.',
    ),
  ),
  TipsUsageStep(
    title: BilingualText(
      ar: '5. فعّل النافذة العائمة',
      en: '5. Enable the floating overlay',
    ),
    body: BilingualText(
      ar:
          'من الإعدادات ← الأذونات امنح «العرض فوق التطبيقات» ثم شغّل النافذة '
          'من بلاطة «ترجم» في الإعدادات السريعة. استخدم زر ✕ لإغلاقها سريعًا، '
          'ومفتاح الإلغاء لوقف الترجمة فورًا.',
      en:
          'From Settings ← Permissions grant "Display over other apps", then '
          'launch the overlay from the Translate tile in Quick Settings. Use '
          'the ✕ button to close it quickly, and the cancel button to stop a '
          'translation instantly.',
    ),
  ),
  TipsUsageStep(
    title: BilingualText(
      ar: '6. ترجم لقطات الشاشة',
      en: '6. Translate screenshots',
    ),
    body: BilingualText(
      ar:
          'داخل النافذة العائمة اضغط «لقطة شاشة» لترجمة ما على الشاشة — '
          'القوائم، النصوص غير القابلة للتحديد، والمحتوى المرئي. وافق على '
          'حوار النظام عند أول استخدام.',
      en:
          'Inside the overlay press "Screenshot" to translate what is on '
          'screen — menus, non-selectable text, and visual content. Accept '
          'the system dialog on first use.',
    ),
  ),
];

/// Article IDs that the Tips screen links to under "Step-by-step setup".
const List<String> kTipsSetupArticleIds = ['04', '05', '06'];