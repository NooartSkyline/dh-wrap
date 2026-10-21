import 'package:equatable/equatable.dart';

sealed class ImportState extends Equatable {
  const ImportState();
}

class ImportInProgress extends ImportState {
  const ImportInProgress({required this.done, required this.total});

  final int done;
  final int total;

  double? get progress {
    if (total <= 0) return null;
    final value = done / total;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  @override
  List<Object?> get props => [done, total];
}

class ImportSuccess extends ImportState {
  const ImportSuccess(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}

class ImportFailure extends ImportState {
  const ImportFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
