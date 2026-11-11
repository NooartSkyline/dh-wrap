import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../data/sync/employee_snapshot_source.dart';
import '../../domain/usecases/import_employees.dart';
import 'employee_update_state.dart';

class EmployeeUpdateCubit extends Cubit<EmployeeUpdateState> {
  EmployeeUpdateCubit(this._client, this._importEmployees)
    : super(
        const EmployeeUpdateInProgress(
          phase: EmployeeUpdatePhase.download,
          done: 0,
          total: 0,
        ),
      );

  final EmployeeSnapshotSource _client;
  final ImportEmployees _importEmployees;
  var _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    emit(
      const EmployeeUpdateInProgress(
        phase: EmployeeUpdatePhase.download,
        done: 0,
        total: 0,
      ),
    );
    try {
      var lastReported = 0;
      final csvText = await _client.download(
        onProgress: (received, total) {
          final finished = total != null && received >= total;
          if (!finished && received - lastReported < 256 * 1024) return;
          lastReported = received;
          if (isClosed) return;
          emit(
            EmployeeUpdateInProgress(
              phase: EmployeeUpdatePhase.download,
              done: received,
              total: total ?? 0,
            ),
          );
        },
      );
      if (isClosed) return;
      emit(
        const EmployeeUpdateInProgress(
          phase: EmployeeUpdatePhase.save,
          done: 0,
          total: 0,
        ),
      );
      final count = await _importEmployees(
        csvText,
        onProgress: (done, total) {
          if (isClosed) return;
          emit(
            EmployeeUpdateInProgress(
              phase: EmployeeUpdatePhase.save,
              done: done,
              total: total,
            ),
          );
        },
      );
      if (isClosed) return;
      emit(EmployeeUpdateSuccess(count));
    } catch (error) {
      if (isClosed) return;
      emit(EmployeeUpdateFailure(errorText(error)));
    } finally {
      _running = false;
    }
  }
}
