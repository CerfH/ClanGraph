import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../controllers/family_controller.dart';
import 'share_config_page.dart';

class ExportDialog extends StatelessWidget {
  final FamilyController controller;

  const ExportDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.minimalistBlue.withValues(alpha: 0.5)),
      ),
      title: const Text(
        '导出数据',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: const Text('请选择导出模式', style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () async {
            final jsonData = controller.exportToJSON();
            await Clipboard.setData(ClipboardData(text: jsonData));
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
            }
          },
          child: Text('完整备份', style: TextStyle(color: AppTheme.electricBlue)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShareConfigPage(controller: controller),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.electricBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('亲友分享'),
        ),
      ],
    );
  }
}
