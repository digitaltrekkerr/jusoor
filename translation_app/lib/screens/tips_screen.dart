import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/articles_service.dart';
import '../services/tips_service.dart';
import 'article_screen.dart';

/// Tips screen — quick tips, how-to-use steps, and links to the setup
/// articles (04–06), all resolved to the active app locale.
class TipsScreen extends StatelessWidget {
  /// Creates the [TipsScreen].
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTips)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionHeader(
              title: l10n.tipsQuickTipsHeader,
              icon: Icons.lightbulb_outline,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            for (final tip in kTipsQuickTips) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    tip.title.resolve(languageCode),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: Text(
                      tip.body.resolve(languageCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _SectionHeader(
              title: l10n.tipsUsageHeader,
              icon: Icons.playlist_play,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            for (final step in kTipsUsageSteps) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.arrow_forward,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    step.title.resolve(languageCode),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: Text(
                      step.body.resolve(languageCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _SectionHeader(
              title: l10n.tipsSetupHeader,
              icon: Icons.menu_book_outlined,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            for (final id in kTipsSetupArticleIds) ...[
              _ArticleLinkCard(articleId: id, languageCode: languageCode),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small section header with an icon, matching the Settings section style.
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Card linking to a setup article (resolved to the active locale).
class _ArticleLinkCard extends StatelessWidget {
  final String articleId;
  final String languageCode;

  const _ArticleLinkCard({
    required this.articleId,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final article = kAppArticles
        .where((a) => a.id == articleId)
        .firstOrNull;
    if (article == null) {
      return const SizedBox.shrink();
    }

    return Card(
      key: ValueKey('tips-article-$articleId'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        leading: Icon(Icons.article_outlined, color: colorScheme.primary),
        title: Text(
          article.titleFor(languageCode),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsetsDirectional.only(top: 4),
          child: Text(
            article.excerptFor(languageCode),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
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
  }
}