import 'change_notifier.dart';

/// Recently used search queries.
abstract interface class SearchHistoryRepository implements Clearable {
  /// Most recent first.
  Future<List<String>> recent({required int limit});

  Future<void> add(String query, DateTime at);
}
