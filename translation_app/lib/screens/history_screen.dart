import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:history/history.dart';

import '../l10n/app_localizations.dart';
import '../providers/history_provider.dart';
import '../widgets/bidi_markdown_view.dart';
import 'history_detail_screen.dart';

/// Screen displaying the list of past translations.
///
/// Features:
/// - Material 3 [SearchBar] with debounced FTS5 search.
/// - Swipe-to-delete with undo snackbar.
/// - "Clear all" with confirmation dialog.
/// - Pull-to-refresh via [RefreshIndicator].
class HistoryScreen extends ConsumerStatefulWidget {
  /// Creates the [HistoryScreen].
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = SearchController();
  Timer? _debounce;

  /// Current text in the search bar (updated on every keystroke).
  String _searchQuery = '';

  /// Results from the most recent search (empty when not searching).
  List<TranslationRecord> _searchResults = [];

  /// Whether a search request is in flight (including debounce wait).
  bool _isSearchLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Search ──────────────────────────────────────────────────────────

  /// Called on every keystroke in the [SearchBar].
  ///
  /// Immediately updates [_searchQuery] so the clear button reacts
  /// instantly, then starts a 300 ms debounce before triggering the
  /// actual FTS5 search.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
        _isSearchLoading = false;
      } else {
        // Show loading state during debounce so the user gets feedback.
        _isSearchLoading = true;
      }
    });

    if (query.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// Executes the FTS5 search and updates [_searchResults].
  Future<void> _performSearch(String query) async {
    setState(() => _isSearchLoading = true);

    try {
      final results = await ref
          .read(historyListProvider.notifier)
          .search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _isSearchLoading = false);
      }
    }
  }

  /// Clears the search bar and exits search mode.
  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearchLoading = false;
    });
  }

  // ── Date formatting ─────────────────────────────────────────────────

  /// Formats a Unix-millisecond timestamp into a human-readable label.
  static String _formatDate(AppLocalizations l10n, int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return l10n.historyToday;
    if (diff.inDays == 1) return l10n.historyYesterday;
    if (diff.inDays < 7) return l10n.historyDaysAgo(diff.inDays);
    return '${date.day}/${date.month}/${date.year}';
  }

  // ── Input type icon ─────────────────────────────────────────────────

  /// Returns the appropriate icon for a given [inputType].
  static IconData _inputTypeIcon(String inputType) {
    return switch (inputType) {
      'file' => Icons.insert_drive_file,
      'image' => Icons.image,
      'screenshot' => Icons.screenshot,
      _ => Icons.text_fields,
    };
  }

  // ── Delete ────────────────────────────────────────────────────────────

  /// Handles swipe-to-delete for a [record].
  ///
  /// Deletes the record from the database, refreshes the list (and search
  /// results if searching), then shows a snackbar with an undo action.
  Future<void> _handleDelete(TranslationRecord record) async {
    // Capture the record data before deletion for potential undo.
    final savedRecord = record;

    await ref
        .read(historyListProvider.notifier)
        .deleteRecord(
          // Record IDs are always set when loaded from the database.
          record.id!, // ignore: null_check_on_fail
        );

    // If searching, refresh search results so the deleted item disappears.
    if (_searchQuery.isNotEmpty) {
      await _performSearch(_searchQuery);
    }

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.historyDeletedSnackbar),
        action: SnackBarAction(
          label: l10n.historyUndoAction,
          onPressed: () async {
            final service = ref.read(historyServiceProvider);
            await service.insertWithId(savedRecord);
            await ref.read(historyListProvider.notifier).refresh();
            if (_searchQuery.isNotEmpty) {
              await _performSearch(_searchQuery);
            }
          },
        ),
      ),
    );
  }

  // ── Clear all ────────────────────────────────────────────────────────

  /// Shows a confirmation dialog and, if confirmed, deletes all history.
  Future<void> _handleClearAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.historyClearAllTitle),
        content: Text(l10n.historyClearAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.appCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.historyClearAllButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(historyListProvider.notifier).deleteAll();
      // Also clear search results since the underlying data is gone.
      _clearSearch();
    }
  }

  // ── Pull-to-refresh ─────────────────────────────────────────────────

  /// Refreshes the current view (main list or search results).
  Future<void> _handleRefresh() async {
    if (_searchQuery.isNotEmpty) {
      await _performSearch(_searchQuery);
    } else {
      await ref.read(historyListProvider.notifier).refresh();
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────

  void _navigateToDetail(TranslationRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryDetailScreen(record: record)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncRecords = ref.watch(historyListProvider);
    final isSearchMode = _searchQuery.isNotEmpty;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.historyClearAllTooltip,
            // Disable while searching — the user should clear the search
            // first to see the full list before bulk-deleting.
            onPressed: isSearchMode ? null : _handleClearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: l10n.historySearchHint,
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 8),

          // ── Content ────────────────────────────────────────────────
          Expanded(
            child: isSearchMode
                ? _buildSearchContent()
                : _buildMainContent(asyncRecords),
          ),
        ],
      ),
    );
  }

  // ── Search content ──────────────────────────────────────────────────

  /// Builds the content area when the user is actively searching.
  Widget _buildSearchContent() {
    if (_isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return _EmptyState(
        isSearching: true,
        searchQuery: _searchQuery,
        onRefresh: () => _performSearch(_searchQuery),
      );
    }
    return _buildRecordList(records: _searchResults, onRefresh: _performSearch);
  }

  // ── Main content ────────────────────────────────────────────────────

  /// Builds the content area for the full (non-search) history list.
  Widget _buildMainContent(AsyncValue<List<TranslationRecord>> asyncRecords) {
    return asyncRecords.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error, onRetry: _handleRefresh),
      data: (records) {
        if (records.isEmpty) {
          return _EmptyState(
            isSearching: false,
            searchQuery: '',
            onRefresh: _handleRefresh,
          );
        }
        return _buildRecordList(
          records: records,
          onRefresh: (_) => ref.read(historyListProvider.notifier).refresh(),
        );
      },
    );
  }

  // ── Shared list builder ─────────────────────────────────────────────

  /// Builds a [RefreshIndicator] wrapping a [ListView.builder] of records.
  Widget _buildRecordList({
    required List<TranslationRecord> records,
    required Future<void> Function(String) onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: () => onRefresh(_searchQuery),
      child: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return _HistoryListItem(
            // Record IDs are always set when loaded from the database.
            key: ValueKey(record.id),
            record: record,
            formatDate: (ts) => _formatDate(
              AppLocalizations.of(context),
              ts,
            ),
            inputTypeIcon: _inputTypeIcon,
            onTap: () => _navigateToDetail(record),
            onDismissed: () => _handleDelete(record),
          );
        },
      ),
    );
  }
}

// ── Empty state widget ─────────────────────────────────────────────────

/// Shown when the history list or search results are empty.
///
/// Wrapped in a [RefreshIndicator] over a full-height always-scrollable view
/// so pull-to-refresh keeps working even when there is no data to scroll.
class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final String searchQuery;
  final Future<void> Function() onRefresh;

  /// Creates the empty state.
  const _EmptyState({
    required this.isSearching,
    required this.searchQuery,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final Widget content;
    if (isSearching) {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          // Isolate the query with LRI…PDI so Arabic/mixed queries keep
          // their internal order instead of scrambling around the quotes.
          l10n.historyNoResults('\u2066$searchQuery\u2069'),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.historyEmptyState,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      // A bare Center cannot trigger the RefreshIndicator; stretch the
      // content to the viewport height inside an always-scrollable view.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

// ── Error state widget ─────────────────────────────────────────────────

/// Shown when the history list fails to load.
class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  /// Creates the error state.
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l10n.historyLoadFailed, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(l10n.articleRetry),
          ),
        ],
      ),
    );
  }
}

// ── History list item ──────────────────────────────────────────────────

/// A single row in the history list with swipe-to-delete support.
class _HistoryListItem extends StatelessWidget {
  final TranslationRecord record;
  final String Function(int) formatDate;
  final IconData Function(String) inputTypeIcon;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  /// Truncates [text] to at most 80 characters, grapheme-safe so multi-unit
  /// characters (emoji etc.) are never split in half.
  static String _truncatePreview(String text) {
    final chars = text.characters;
    if (chars.length <= 80) return text;
    return '${chars.take(80).string}…';
  }

  /// Creates the list item.
  const _HistoryListItem({
    super.key,
    required this.record,
    required this.formatDate,
    required this.inputTypeIcon,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = BiDiMarkdownView.isRtl(record.inputText);

    return Dismissible(
      // Record IDs are always set when loaded from the database.
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Input type icon
              Icon(
                inputTypeIcon(record.inputType),
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _truncatePreview(record.inputText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                      textDirection:
                          isRtl ? TextDirection.rtl : TextDirection.ltr,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          record.targetLanguage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (record.wordCount != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            // wordCount is null-checked by the enclosing if.
                            AppLocalizations.of(
                              context,
                            ).homeWordCount(record.wordCount!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Date label
              Text(
                formatDate(record.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
