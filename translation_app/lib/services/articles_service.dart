import 'package:flutter/services.dart' show rootBundle;

/// Metadata for a built-in article rendered inline in Settings.
///
/// Article bodies are bundled Markdown files under `assets/articles/`. The
/// title/excerpt here drive the ExpansionTile labels; bodies are loaded lazily
/// via [loadArticleBody] when the user expands a tile.
class AppArticle {
  /// Stable identifier (matches the file basename prefix, e.g. `01`).
  final String id;

  /// Path relative to the app bundle, e.g. `assets/articles/01-what-is-jusoor.md`.
  final String asset;

  /// Title shown in the ExpansionTile (already includes the `jusoor:` prefix
  /// when applicable; content is Arabic).
  final String title;

  /// Short teaser shown beneath the title in the tile header.
  final String excerpt;

  const AppArticle({
    required this.id,
    required this.asset,
    required this.title,
    required this.excerpt,
  });
}

/// The articles rendered inside Settings → Help & Support.
///
/// Order matters: this is the visual order under the section.
const List<AppArticle> kAppArticles = [
  AppArticle(
    id: '01',
    asset: 'assets/articles/01-what-is-jusoor.md',
    title: 'ما هو تطبيق جسور للترجمة الفورية على Android؟',
    excerpt:
        'جسور تطبيق أندرويد مجاني ومفتوح المصدر يضع ترجمة الذكاء الاصطناعي في نافذة عائمة فوق أي تطبيق — دون نسخ ولصق، ودون أن تغادر الشاشة التي تعمل عليها.',
  ),
  AppArticle(
    id: '02',
    asset: 'assets/articles/02-overlay-guide.md',
    title: 'كيفية استخدام overlay الترجمة على أي تطبيق',
    excerpt:
        'دليل عملي خطوة بخطوة لتفعيل النافذة العائمة في جسور وترجمة أي نص أو صورة فوق أي تطبيق — من منح الأذونات حتى قراءة النتيجة.',
  ),
  AppArticle(
    id: '03',
    asset: 'assets/articles/03-security-permissions.md',
    title: 'أمان وخصوصية Jusoor — لماذا يحتاج تلك الأذونات؟',
    excerpt:
        'جسور يطلب أذونات حساسة مثل التقاط الشاشة والعرض فوق التطبيقات. في هذا المقال نشرح كل إذن بشفافية كاملة، ونوضح أين تُحفظ مفاتيحك وإلى أين تسافر بياناتك فعلاً.',
  ),
];

/// Loads the raw Markdown body for [article] from the app bundle.
Future<String> loadArticleBody(AppArticle article) {
  return rootBundle.loadString(article.asset);
}