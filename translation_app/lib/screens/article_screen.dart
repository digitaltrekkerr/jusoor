import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/articles_service.dart';
import '../widgets/bidi_markdown_view.dart';

/// Reader screen for a single bundled article.
///
/// Loads the Markdown body lazily via [loadArticleBody] and renders it
/// through [BiDiMarkdownView], which already handles BiDi direction
/// detection, RTL-aware markdown layout, and long-text performance
/// (RegExp hoisting, capped direction-scan window, stable ValueKey).
///
/// The body is bilingual: when the app locale is English and an `.en.md`
/// variant exists for the article, it is loaded; otherwise the Arabic
/// content is shown.
class ArticleScreen extends StatefulWidget {
  /// The article to render. Required.
  final AppArticle article;

  /// Creates the [ArticleScreen] for [article].
  const ArticleScreen({super.key, required this.article});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Future<String>? _future;
  String _languageCode = 'ar';
  bool _initialized = false;

  void _reloadForLocale(String languageCode) {
    if (languageCode == _languageCode && _initialized) return;
    _initialized = true;
    _languageCode = languageCode;
    _future = loadArticleBody(widget.article, languageCode: languageCode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loads the correct locale variant on first build and whenever the app
    // locale changes while this screen is open.
    _reloadForLocale(Localizations.localeOf(context).languageCode);
  }

  Future<void> _retry() {
    final next = loadArticleBody(
      widget.article,
      languageCode: _languageCode,
    );
    setState(() => _future = next);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article.titleFor(_languageCode)),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final colorScheme = Theme.of(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.articleLoadError,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.articleRetry),
                    ),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                BiDiMarkdownView(markdownText: snap.data!),
              ],
            );
          },
        ),
      ),
    );
  }
}