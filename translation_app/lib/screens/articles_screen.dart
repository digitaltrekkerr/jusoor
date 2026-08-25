import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/articles_service.dart';
import 'article_screen.dart';

/// Articles list — bundled, offline Markdown articles rendered as a
/// scrollable list. Tapping a row pushes [ArticleScreen] for that article.
///
/// The list is intentionally simple: no search, no filter, no categories.
/// The article set is small (three entries) and curated; navigating by title
/// is faster than a search affordance would be at this scale.
class ArticlesScreen extends StatelessWidget {
  /// Creates the [ArticlesScreen].
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsArticles)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: kAppArticles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final article = kAppArticles[index];
            return Card(
              key: ValueKey('article-row-${article.id}'),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                title: Text(
                  article.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4),
                  child: Text(
                    article.excerpt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleScreen(article: article),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}