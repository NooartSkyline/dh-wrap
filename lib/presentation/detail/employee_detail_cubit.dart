import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error_text.dart';
import '../../domain/usecases/get_employee.dart';
import 'employee_detail_state.dart';

class EmployeeDetailCubit extends Cubit<EmployeeDetailState> {
  EmployeeDetailCubit(this._getEmployee) : super(const EmployeeDetailLoading());

  final GetEmployee _getEmployee;
  String? _personId;

  Future<void> load(String personId) async {
    _personId = personId;
    emit(const EmployeeDetailLoading());
    try {
      final employee = await _getEmployee(personId);
      if (isClosed) return;
      if (employee == null) {
        emit(const EmployeeDetailMissing());
        return;
      }
      emit(EmployeeDetailLoaded(employee));
    } catch (error) {
      if (isClosed) return;
      emit(EmployeeDetailFailure(errorText(error)));
    }
  }

  Future<void> retry() async {
    final personId = _personId;
    if (personId == null || personId.isEmpty) {
      emit(const EmployeeDetailMissing());
      return;
    }
    await load(personId);
  }
}
