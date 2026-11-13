import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/logging/app_logger.dart';

/// Logs unexpected bloc errors in one place.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver(this._logger);

  final AppLogger _logger;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.error('${bloc.runtimeType} error', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
