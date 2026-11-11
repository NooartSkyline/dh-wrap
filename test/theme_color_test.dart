import 'package:dh_wrap/core/theme/app_theme.dart';
import 'package:dh_wrap/presentation/theme/theme_color_dialog.dart';
import 'package:dh_wrap/presentation/theme/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('สีเดิมคงชุดสีเดิม และสีอื่นเปลี่ยนธีมแต่สถานะพนักงานไม่เปลี่ยน', () {
    expect(
      AppColors.fromSeed(AppColors.standardSeed).ink,
      AppColors.standard.ink,
    );

    const red = Color(0xFFE53935);
    final themed = AppColors.fromSeed(red);
    expect(themed.leaf.toARGB32(), isNot(AppColors.standard.leaf.toARGB32()));
    expect(themed.ink.toARGB32(), isNot(AppColors.standard.ink.toARGB32()));
    expect(themed.working, AppColors.standard.working);
    expect(themed.idle, AppColors.standard.idle);
  });

  testWidgets('ยกเลิกไม่จำสี และยืนยันแล้วใช้สีที่เลือก', (tester) async {
    final saved = <Color>[];
    final cubit = ThemeCubit((color) async {
      saved.add(color);
    }, AppColors.standardSeed);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ThemeCubit, Color>(
          builder: (context, seed) {
            return MaterialApp(
              theme: AppTheme.light(seed),
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: FilledButton(
                      onPressed: () async {
                        final picked = await showThemeColorDialog(
                          context: context,
                          seed: AppColors.of(context).seed,
                        );
                        if (picked == null || !context.mounted) return;
                        await context.read<ThemeCubit>().select(picked);
                      },
                      child: const Text('เปิด'),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    tester
        .widget<Slider>(find.byKey(const Key('employee-theme-hue')))
        .onChanged!(200);
    await tester.pump();
    await tester.tap(find.byKey(const Key('employee-theme-cancel')));
    await tester.pumpAndSettle();
    expect(cubit.state, AppColors.standardSeed);
    expect(saved, isEmpty);

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    tester
        .widget<Slider>(find.byKey(const Key('employee-theme-hue')))
        .onChanged!(200);
    await tester.pump();
    await tester.tap(find.byKey(const Key('employee-theme-apply')));
    await tester.pumpAndSettle();
    expect(cubit.state.toARGB32(), isNot(AppColors.standardSeed.toARGB32()));
    expect(saved.single.toARGB32(), cubit.state.toARGB32());

    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    tester
        .widget<Slider>(find.byKey(const Key('employee-theme-hue')))
        .onChanged!(40);
    await tester.pump();
    await tester.tap(find.byKey(const Key('employee-theme-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('employee-theme-apply')));
    await tester.pumpAndSettle();
    expect(cubit.state.toARGB32(), AppColors.standardSeed.toARGB32());
  });
}
