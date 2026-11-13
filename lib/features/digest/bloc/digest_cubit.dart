import 'package:equatable/equatable.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/usecases/recall/recall_usecases.dart';

/// The digest plus an optional AI recap generated on request.
class DigestView extends Equatable {
  const DigestView({required this.digest, this.recap, this.isWritingRecap = false});

  final Digest digest;
  final String? recap;
  final bool isWritingRecap;

  DigestView copyWith({String? recap, bool? isWritingRecap}) => DigestView(
    digest: digest,
    recap: recap ?? this.recap,
    isWritingRecap: isWritingRecap ?? this.isWritingRecap,
  );

  @override
  List<Object?> get props => [digest, recap, isWritingRecap];
}

class DigestCubit extends AutoRefreshCubit<DigestView> {
  DigestCubit({
    required GetDigest getDigest,
    required WriteWeeklyRecap writeRecap,
    required super.changes,
  }) : _getDigest = getDigest,
       _writeRecap = writeRecap;

  final GetDigest _getDigest;
  final WriteWeeklyRecap _writeRecap;

  @override
  Future<Result<DigestView>> fetch() async {
    final previousRecap = data?.recap;
    final result = await _getDigest.run();
    return result.fold(
      onSuccess: (digest) => Success(DigestView(digest: digest, recap: previousRecap)),
      onFailure: Err.new,
    );
  }

  Future<void> writeRecap() async {
    final current = data;
    if (current == null || current.isWritingRecap) return;
    emit(Loaded(current.copyWith(isWritingRecap: true)));
    final recap = await _writeRecap(current.digest.week);
    if (isClosed) return;
    emit(
      Loaded(
        current.copyWith(
          recap: recap.valueOrNull ?? recap.failureOrNull?.message,
          isWritingRecap: false,
        ),
      ),
    );
  }
}
