import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<Color?> showThemeColorDialog({
  required BuildContext context,
  required Color seed,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ThemeColorDialog(seed: seed),
  );
}

class _ThemeColorDialog extends StatefulWidget {
  const _ThemeColorDialog({required this.seed});

  final Color seed;

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  late double _hue;
  late double _saturation;
  late double _lightness;
  Color? _exact;

  @override
  void initState() {
    super.initState();
    _apply(widget.seed);
  }

  void _apply(Color color) {
    final hsl = HSLColor.fromColor(color);
    _exact = color;
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
  }

  Color get _color {
    return _exact ??
        HSLColor.fromAHSL(1, _hue, _saturation, _lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final picked = _color;
    return AlertDialog(
      backgroundColor: colors.card,
      title: const Text('สีธีม'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: picked,
              shape: BoxShape.circle,
              border: Border.all(color: colors.line),
            ),
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'สี',
            value: _hue,
            max: 360,
            activeColor: picked,
            sliderKey: const Key('employee-theme-hue'),
            onChanged: (value) => setState(() {
              _exact = null;
              _hue = value;
            }),
          ),
          _SliderRow(
            label: 'ความสด',
            value: _saturation,
            max: 1,
            activeColor: picked,
            sliderKey: const Key('employee-theme-saturation'),
            onChanged: (value) => setState(() {
              _exact = null;
              _saturation = value;
            }),
          ),
          _SliderRow(
            label: 'ความสว่าง',
            value: _lightness,
            max: 1,
            activeColor: picked,
            sliderKey: const Key('employee-theme-lightness'),
            onChanged: (value) => setState(() {
              _exact = null;
              _lightness = value;
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('employee-theme-reset'),
          onPressed: () => setState(() => _apply(AppColors.standardSeed)),
          child: const Text('สีเดิม'),
        ),
        TextButton(
          key: const Key('employee-theme-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const Key('employee-theme-apply'),
          onPressed: () => Navigator.pop(context, picked),
          child: const Text('ใช้สีนี้'),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.sliderKey,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final Color activeColor;
  final Key sliderKey;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value.clamp(0, max),
            max: max,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
