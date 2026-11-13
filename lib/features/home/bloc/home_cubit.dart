import '../../../core/bloc/load_state.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/usecases/recall/recall_usecases.dart';

/// Loads the Home overview and refreshes it when data changes.
class HomeCubit extends AutoRefreshCubit<HomeOverview> {
  HomeCubit({required GetHomeOverview getOverview, required super.changes})
    : _getOverview = getOverview;

  final GetHomeOverview _getOverview;

  @override
  Future<Result<HomeOverview>> fetch() => _getOverview.run();
}
