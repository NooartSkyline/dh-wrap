import 'package:equatable/equatable.dart';

sealed class AppGateState extends Equatable {
  const AppGateState();
}

class AppGateChecking extends AppGateState {
  const AppGateChecking();

  @override
  List<Object?> get props => [];
}

class AppGateNeedsImport extends AppGateState {
  const AppGateNeedsImport();

  @override
  List<Object?> get props => [];
}

class AppGateReady extends AppGateState {
  const AppGateReady();

  @override
  List<Object?> get props => [];
}

class AppGateFailure extends AppGateState {
  const AppGateFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
