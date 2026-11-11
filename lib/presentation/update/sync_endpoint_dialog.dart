import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/sync/employee_snapshot_client.dart';

Future<String?> showSyncEndpointDialog({
  required BuildContext context,
  required String initialUrl,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SyncEndpointDialog(initialUrl: initialUrl),
  );
}

class _SyncEndpointDialog extends StatefulWidget {
  const _SyncEndpointDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_SyncEndpointDialog> createState() => _SyncEndpointDialogState();
}

class _SyncEndpointDialogState extends State<_SyncEndpointDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      csvUriFromBase(_controller.text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('อัปเดตข้อมูลล่าสุด'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ดึงชุดใหม่มาแทนที่ข้อมูลในเครื่อง ใช้เวลาประมาณหนึ่งถึงสองนาที ถ้าดึงไม่สำเร็จ ข้อมูลเดิมยังอยู่',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('employee-sync-url'),
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'ที่อยู่เครื่องที่เปิดตัวดึง',
              hintText: 'http://192.168.1.10:8787',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.idle)),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('employee-sync-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const Key('employee-sync-start'),
          onPressed: _submit,
          child: const Text('เริ่มอัปเดต'),
        ),
      ],
    );
  }
}
