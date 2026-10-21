import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../domain/usecases/is_employee_data_imported.dart';
import 'app_gate_state.dart';

class AppGateCubit extends Cubit<AppGateState> {
  AppGateCubit(this._isImported) : super(const AppGateChecking());

  final IsEmployeeDataImported _isImported;

  Future<void> check() async {
    emit(const AppGateChecking());
    try {
      final imported = await _isImported();
      if (isClosed) return;
      emit(imported ? const AppGateReady() : const AppGateNeedsImport());
    } catch (error) {
      if (isClosed) return;
      emit(AppGateFailure(errorText(error)));
    }
  }

  void markReady() {
    if (isClosed) return;
    emit(const AppGateReady());
  }
}
