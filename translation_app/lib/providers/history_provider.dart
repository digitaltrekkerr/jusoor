import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:history/history.dart';

/// Provides the [HistoryService] singleton.
///
/// The service is stateless (delegates to a static DB singleton), so a plain
/// [Provider] is sufficient.
final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService();
});

/// Reactive list of translation records.
///
/// Watch this provider to display the history list. Use
/// [HistoryListNotifier.refresh] after mutations that should update the UI.
final historyListProvider =
    NotifierProvider<HistoryListNotifier, AsyncValue<List<TranslationRecord>>>(
      HistoryListNotifier.new,
    );

/// Manages translation history state: loading, refreshing, deleting, and
/// searching.
///
/// Search is intentionally **not** part of the reactive state — it returns
/// results directly so that the UI can manage search mode independently
/// without disrupting the main list.
class HistoryListNotifier
    extends Notifier<AsyncValue<List<TranslationRecord>>> {
  @override
  AsyncValue<List<TranslationRecord>> build() {
    _loadRecords();
    return const AsyncValue.loading();
  }

  /// Loads all records from the database and updates [state].
  ///
  /// On error, sets [state] to [AsyncValue.error] so the UI can show a
  /// retry option.
  Future<void> _loadRecords() async {
    final service = ref.read(historyServiceProvider);
    try {
      final records = await service.getAll();
      state = AsyncValue.data(records);
    } on Object catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Silently reloads all records without showing a loading indicator.
  ///
  /// Use this for pull-to-refresh and post-mutation reloads so the list
  /// stays visible while the data is being fetched.
  Future<void> refresh() async {
    await _loadRecords();
  }

  /// Deletes a single record by [id] and reloads the list.
  Future<void> deleteRecord(int id) async {
    final service = ref.read(historyServiceProvider);
    await service.delete(id);
    await _loadRecords();
  }

  /// Deletes every record and sets [state] to an empty list.
  ///
  /// No reload is needed — we already know the result is empty.
  Future<void> deleteAll() async {
    final service = ref.read(historyServiceProvider);
    await service.deleteAll();
    state = const AsyncValue.data([]);
  }

  /// Searches for records matching [query] using LIKE queries.
  ///
  /// Does **not** modify [state]; returns the results directly so that
  /// the search UI can be managed independently.
  Future<List<TranslationRecord>> search(String query) async {
    final service = ref.read(historyServiceProvider);
    return service.search(query);
  }
}
