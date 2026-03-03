import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/family_controller.dart';

class GiftRecordDialog extends StatefulWidget {
  final FamilyController controller;
  final String personId;

  const GiftRecordDialog({
    super.key,
    required this.controller,
    required this.personId,
  });

  @override
  State<GiftRecordDialog> createState() => _GiftRecordDialogState();
}

class _GiftRecordDialogState extends State<GiftRecordDialog> {
  final _amountController = TextEditingController();
  final _eventController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final event = _eventController.text;

      widget.controller.addGiftRecord(widget.personId, amount, event);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.controller.dynamicEventHistory;

    return Dialog(
      backgroundColor: AppTheme.surfaceGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.minimalistBlue.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '添加礼金记录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 金额输入
                TextFormField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '金额',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixText: '￥',
                    prefixStyle: const TextStyle(color: Colors.white),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.electricBlue),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入金额';
                    }
                    if (double.tryParse(value) == null) {
                      return '请输入有效的数字';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 事件输入
                TextFormField(
                  controller: _eventController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '事件',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.electricBlue),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入事件';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 历史事件标签
                if (history.isNotEmpty) ...[
                  const Text(
                    '常用事件',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: history.map((event) {
                      final isSelected = _eventController.text == event;
                      return ChoiceChip(
                        label: Text(
                          event,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.electricBlue.withValues(alpha: 0.6),
                        backgroundColor: Colors.white10,
                        onSelected: (selected) {
                          setState(() {
                            _eventController.text = event;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),
                
                // 按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
