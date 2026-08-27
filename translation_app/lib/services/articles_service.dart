import 'package:flutter/services.dart' show rootBundle;

/// Metadata for a built-in article rendered inline in Settings.
///
/// Article bodies are bundled Markdown files under `assets/articles/`. The
/// title/excerpt here drive the ExpansionTile labels; bodies are loaded lazily
/// via [loadArticleBody] when the user expands a tile.
///
/// Articles are bilingual: Arabic fields are the canonical content, English
/// fields are optional. When the app locale is English, [titleFor],
/// [excerptFor], and [assetFor] select the English variant, falling back to
/// Arabic when English content is missing.
class AppArticle {
  /// Stable identifier (matches the file basename prefix, e.g. `01`).
  final String id;

  /// Path to the Arabic Markdown body, e.g.
  /// `assets/articles/01-what-is-jusoor.md`.
  final String asset;

  /// English Markdown body path (e.g. `assets/articles/01-what-is-jusoor.en.md`),
  /// or `null` when no English translation exists.
  final String? assetEn;

  /// Arabic title shown in the list tile.
  final String title;

  /// English title, or `null` when not provided.
  final String? titleEn;

  /// Arabic short teaser shown beneath the title.
  final String excerpt;

  /// English short teaser, or `null` when not provided.
  final String? excerptEn;

  const AppArticle({
    required this.id,
    required this.asset,
    this.assetEn,
    required this.title,
    this.titleEn,
    required this.excerpt,
    this.excerptEn,
  });

  /// Title for [languageCode] (`en` → English when available, else Arabic).
  String titleFor(String languageCode) =>
      languageCode == 'en' ? (titleEn ?? title) : title;

  /// Excerpt for [languageCode] (`en` → English when available, else Arabic).
  String excerptFor(String languageCode) =>
      languageCode == 'en' ? (excerptEn ?? excerpt) : excerpt;

  /// Asset path for [languageCode] (`en` → `.en.md` when available, else
  /// the Arabic asset).
  String assetFor(String languageCode) =>
      languageCode == 'en' ? (assetEn ?? asset) : asset;
}

/// The articles rendered inside Settings → Help & Support.
///
/// Order matters: this is the visual order under the section.
const List<AppArticle> kAppArticles = [
  AppArticle(
    id: '01',
    asset: 'assets/articles/01-what-is-jusoor.md',
    assetEn: 'assets/articles/01-what-is-jusoor.en.md',
    title: 'ما هو تطبيق جسور للترجمة الفورية على Android؟',
    titleEn: 'What is Jusoor — instant on-screen translation for Android?',
    excerpt:
        'جسور تطبيق أندرويد مجاني ومفتوح المصدر يضع ترجمة الذكاء الاصطناعي في نافذة عائمة فوق أي تطبيق — دون نسخ ولصق، ودون أن تغادر الشاشة التي تعمل عليها.',
    excerptEn:
        'Jusoor is a free, open-source Android app that brings AI translation '
        'into a floating window above any app — no copy-paste, no leaving the '
        'screen you are working on.',
  ),
  AppArticle(
    id: '02',
    asset: 'assets/articles/02-overlay-guide.md',
    assetEn: 'assets/articles/02-overlay-guide.en.md',
    title: 'كيفية استخدام overlay الترجمة على أي تطبيق',
    titleEn: 'How to use the translation overlay on any app',
    excerpt:
        'دليل عملي خطوة بخطوة لتفعيل النافذة العائمة في جسور وترجمة أي نص أو صورة فوق أي تطبيق — من منح الأذونات حتى قراءة النتيجة.',
    excerptEn:
        'A practical step-by-step guide to enabling Jusoor\'s floating window '
        'and translating any text or image above any app — from granting '
        'permissions to reading the result.',
  ),
  AppArticle(
    id: '03',
    asset: 'assets/articles/03-security-permissions.md',
    assetEn: 'assets/articles/03-security-permissions.en.md',
    title: 'أمان وخصوصية Jusoor — لماذا يحتاج تلك الأذونات؟',
    titleEn: 'Jusoor security & privacy — why does it need those permissions?',
    excerpt:
        'جسور يطلب أذونات حساسة مثل التقاط الشاشة والعرض فوق التطبيقات. في هذا المقال نشرح كل إذن بشفافية كاملة، ونوضح أين تُحفظ مفاتيحك وإلى أين تسافر بياناتك فعلاً.',
    excerptEn:
        'Jusoor requests sensitive permissions such as screen capture and '
        'display-over-apps. This article explains each permission transparently, '
        'where your keys are stored, and where your data actually travels.',
  ),
  AppArticle(
    id: '04',
    asset: 'assets/articles/04-setup-provider-template-key.md',
    assetEn: 'assets/articles/04-setup-provider-template-key.en.md',
    title: 'الإعداد من الصفر: المزود، القالب، ومفتاح API',
    titleEn: 'Setup from scratch: provider, template, and API key',
    excerpt:
        'كيف تضيف مزود ترجمة (OpenRouter أو Gemini أو OpenAI)، تعيّن قالب الترجمة الأساسي، وتدخل مفتاح API الخاص بك — في خمس دقائق.',
    excerptEn:
        'How to add a translation provider (OpenRouter, Gemini, or OpenAI), '
        'set your primary translation template, and enter your API key — in '
        'five minutes.',
  ),
  AppArticle(
    id: '05',
    asset: 'assets/articles/05-gemini-api-key.md',
    assetEn: 'assets/articles/05-gemini-api-key.en.md',
    title: 'الحصول على مفتاح Gemini API مجانًا',
    titleEn: 'Get a free Gemini API key',
    excerpt:
        'خطوات الحصول على مفتاح Gemini من Google AI Studio، وربطه بحساب فوترة، ولصقه في إعدادات جسور لتفعيل نموذج Gemini.',
    excerptEn:
        'Steps to get a Gemini key from Google AI Studio, attach a billing '
        'account, and paste it into Jusoor settings to enable a Gemini model.',
  ),
  AppArticle(
    id: '06',
    asset: 'assets/articles/06-openrouter-api-key.md',
    assetEn: 'assets/articles/06-openrouter-api-key.en.md',
    title: 'الحصول على مفتاح OpenRouter API',
    titleEn: 'Get an OpenRouter API key',
    excerpt:
        'كيفية إنشاء مفتاح OpenRouter، إضافة رصيد، واختيار نماذج متعددة عبر مزود واحد — مع نماذج مجانية للبدء.',
    excerptEn:
        'How to create an OpenRouter key, add credits, and access many models '
        'through one provider — including free models to start with.',
  ),
];

/// Loads the raw Markdown body for [article] from the app bundle.
///
/// [languageCode] selects the English variant (`.en.md`) when available and
/// the locale is English; otherwise the Arabic asset is loaded.
Future<String> loadArticleBody(
  AppArticle article, {
  String? languageCode,
}) {
  return rootBundle.loadString(article.assetFor(languageCode ?? 'ar'));
}