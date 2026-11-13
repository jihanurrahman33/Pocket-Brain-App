import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/result.dart';
import '../../../domain/usecases/settings/settings_usecases.dart';

class SettingsState extends Equatable {
  const SettingsState({this.aiSuggestionsEnabled = true, this.isBusy = false});

  final bool aiSuggestionsEnabled;

  /// An export or wipe is running.
  final bool isBusy;

  SettingsState copyWith({bool? aiSuggestionsEnabled, bool? isBusy}) => SettingsState(
    aiSuggestionsEnabled: aiSuggestionsEnabled ?? this.aiSuggestionsEnabled,
    isBusy: isBusy ?? this.isBusy,
  );

  @override
  List<Object?> get props => [aiSuggestionsEnabled, isBusy];
}

/// Privacy and data settings. Model settings live in `ModelBloc`.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required GetAiSuggestionsEnabled getAiSuggestions,
    required SetAiSuggestionsEnabled setAiSuggestions,
    required ExportData exportData,
    required WipeAllData wipeAllData,
  }) : _getAiSuggestions = getAiSuggestions,
       _setAiSuggestions = setAiSuggestions,
       _exportData = exportData,
       _wipeAllData = wipeAllData,
       super(const SettingsState());

  final GetAiSuggestionsEnabled _getAiSuggestions;
  final SetAiSuggestionsEnabled _setAiSuggestions;
  final ExportData _exportData;
  final WipeAllData _wipeAllData;

  Future<void> load() async =>
      emit(state.copyWith(aiSuggestionsEnabled: await _getAiSuggestions.run()));

  Future<void> setAiSuggestions(bool enabled) async {
    emit(state.copyWith(aiSuggestionsEnabled: enabled));
    await _setAiSuggestions(enabled);
  }

  /// Returns the exported file path or a failure.
  Future<Result<String>> export() => _busy(_exportData.run);

  Future<Result<void>> wipe() => _busy(_wipeAllData.run);

  Future<T> _busy<T>(Future<T> Function() action) async {
    emit(state.copyWith(isBusy: true));
    try {
      return await action();
    } finally {
      if (!isClosed) emit(state.copyWith(isBusy: false));
    }
  }
}
