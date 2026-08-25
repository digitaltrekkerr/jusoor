import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Support screen — links to the project's Patreon, GitHub, website, and email.
///
/// All user-visible strings are sourced from [AppLocalizations]. The external
/// URLs are intentionally not localized (they are constants).
class SupportScreen extends StatelessWidget {
  /// Creates the [SupportScreen].
  const SupportScreen({super.key});

  /// Patreon membership URL.
  static const String _patreonUrl =
      'https://www.patreon.com/cw/DigitalTrekkerr/membership';

  /// GitHub repository URL.
  static const String _githubUrl = 'https://github.com/digitaltrekkerr/jusoor';

  /// Project website URL.
  static const String _websiteUrl = 'https://www.digitaltrekkerr.com';

  /// Support email address (mailto URL).
  static const String _emailUrl = 'mailto:support@digitaltrekkerr.com';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pagesSupportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SupportCard(
              icon: Icons.favorite_outline,
              title: l10n.pagesPatreonTitle,
              subtitle: l10n.pagesPatreonSubtitle,
              onTap: () => _openExternal(context, _patreonUrl),
            ),
            const SizedBox(height: 16),
            _SupportCard(
              icon: Icons.star_outline,
              title: l10n.pagesGithubTitle,
              subtitle: l10n.pagesGithubSubtitle,
              onTap: () => _openExternal(context, _githubUrl),
            ),
            const SizedBox(height: 16),
            _SupportCard(
              icon: Icons.public,
              title: l10n.pagesWebsiteTitle,
              subtitle: l10n.pagesWebsiteSubtitle,
              onTap: () => _openExternal(context, _websiteUrl),
            ),
            const SizedBox(height: 16),
            _SupportCard(
              icon: Icons.email_outlined,
              title: l10n.pagesEmailTitle,
              subtitle: l10n.pagesEmailSubtitle,
              onTap: () => _openExternal(context, _emailUrl),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    if (uri == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.supportInvalidUrl)),
      );
      return;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.pagesOpeningLink),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[SupportScreen] launchUrl failed: $e');
    }
  }
}

/// One large tappable support card on the [SupportScreen].
class _SupportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(icon, size: 28, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
