import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit extends Cubit<Color> {
  ThemeCubit(this._save, Color initial) : super(initial);

  final Future<void> Function(Color color) _save;

  Future<void> select(Color color) async {
    if (color.toARGB32() == state.toARGB32()) return;
    emit(color);
    await _save(color);
  }
}
