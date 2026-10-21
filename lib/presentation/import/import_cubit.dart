import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../data/datasources/employee_csv_asset.dart';
import '../../domain/usecases/import_employees.dart';
import 'import_state.dart';

class ImportCubit extends Cubit<ImportState> {
  ImportCubit(this._importEmployees, this._asset)
    : super(const ImportInProgress(done: 0, total: 0));

  final ImportEmployees _importEmployees;
  final EmployeeCsvAsset _asset;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    emit(const ImportInProgress(done: 0, total: 0));
    try {
      final csvText = await _asset.load();
      if (isClosed) return;
      final count = await _importEmployees(
        csvText,
        onProgress: (done, total) {
          if (!isClosed) emit(ImportInProgress(done: done, total: total));
        },
      );
      if (isClosed) return;
      emit(ImportSuccess(count));
    } catch (error) {
      if (isClosed) return;
      emit(ImportFailure(errorText(error)));
    } finally {
      _running = false;
    }
  }
}
