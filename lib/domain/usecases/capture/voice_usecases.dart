import '../../../core/error/failure.dart';
import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../services/ai_services.dart';

final class StartVoiceRecording implements UseCase<Result<void>, NoParams> {
  const StartVoiceRecording(this._recorder, this._logger);

  final VoiceRecorder _recorder;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(NoParams _) async {
    if (!await _recorder.isSupported()) {
      return const Err(ValidationFailure('Voice recording is not available on this device.'));
    }
    final result = await guard(_logger, 'Start recording', _recorder.start);
    return result.isSuccess
        ? result
        : const Err(ValidationFailure('Could not use the microphone. Check its permission.'));
  }
}

/// Stops recording and returns the recording's path.
final class StopVoiceRecording implements UseCase<Result<String>, NoParams> {
  const StopVoiceRecording(this._recorder, this._logger);

  final VoiceRecorder _recorder;
  final AppLogger _logger;

  @override
  Future<Result<String>> call(NoParams _) => guard(_logger, 'Stop recording', _recorder.stop);
}

final class CancelVoiceRecording implements UseCase<void, NoParams> {
  const CancelVoiceRecording(this._recorder);

  final VoiceRecorder _recorder;

  @override
  Future<void> call(NoParams _) => _recorder.cancel();
}
