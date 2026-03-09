import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/family_controller.dart';
import '../models/person.dart';

class GiftRecordDialog extends StatefulWidget {
  final FamilyController controller;
  final String personId;
  final GiftRecord? initialRecord; // For edit mode or pre-fill
  final bool allowMemberSelection; // Allow changing target member

  const GiftRecordDialog({
    super.key,
    required this.controller,
    required this.personId,
    this.initialRecord,
    this.allowMemberSelection = false,
  });

  @override
  State<GiftRecordDialog> createState() => _GiftRecordDialogState();
}

class _GiftRecordDialogState extends State<GiftRecordDialog> {
  final _amountController = TextEditingController();
  final _eventController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late String _selectedPersonId;
  bool _syncToSpouse = false;

  @override
  void initState() {
    super.initState();
    _selectedPersonId = widget.personId;
    if (widget.initialRecord != null) {
      _amountController.text = widget.initialRecord!.amount.toStringAsFixed(0); // Assuming integer amount for display
      _eventController.text = widget.initialRecord!.event;
      _selectedDate = widget.initialRecord!.date;
    } else {
      _selectedDate = DateTime.now();
    }
  }

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

      if (widget.initialRecord != null && widget.initialRecord!.id.isNotEmpty) {
        // Edit Mode (only when initialRecord has a valid id)
        final updatedRecord = GiftRecord(
          id: widget.initialRecord!.id,
          amount: amount,
          event: event,
          date: _selectedDate,
        );
        widget.controller.updateGiftRecord(_selectedPersonId, updatedRecord);
      } else {
        // Add Mode (including pre-fill mode)
        widget.controller.addGiftRecord(_selectedPersonId, amount, event, _selectedDate);

        // Sync to spouse if checked
        if (_syncToSpouse) {
           final person = widget.controller.getPerson(_selectedPersonId);
           if (person != null && person.spouse != null) {
             widget.controller.addGiftRecord(person.spouse!, amount, event, _selectedDate);
           }
        }
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.electricBlue,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceGrey,
              onSurface: Colors.white,
            ), dialogTheme: DialogThemeData(backgroundColor: AppTheme.surfaceGrey),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.controller.dynamicEventHistory;
    final isEditMode = widget.initialRecord != null && widget.initialRecord!.id.isNotEmpty;
    final person = widget.controller.getPerson(_selectedPersonId);
    final hasSpouse = person?.spouse != null;
    final allPeople = widget.controller.allPeople;

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
                  isEditMode ? '编辑礼金记录' : '添加礼金记录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Member Selection Dropdown (if allowed)
                if (widget.allowMemberSelection && allPeople.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPersonId,
                    decoration: InputDecoration(
                      labelText: '家庭成员',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.electricBlue),
                      ),
                    ),
                    dropdownColor: AppTheme.surfaceGrey,
                    style: const TextStyle(color: Colors.white),
                    items: allPeople.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${p.relationship})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPersonId = value;
                        });
                      }
                    },
                  ),
                if (widget.allowMemberSelection) const SizedBox(height: 16),
                
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
                            // Event Association Trigger
                            final defaultDate = widget.controller.getEventDefaultDate(event);
                            if (defaultDate != null) {
                              _selectedDate = defaultDate;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // Date Picker Row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '日期: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Icon(Icons.calendar_today, color: AppTheme.electricBlue, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Spouse Sync Checkbox (Only in Add mode and if spouse exists)
                if (!isEditMode && hasSpouse)
                  Row(
                    children: [
                      Checkbox(
                        value: _syncToSpouse,
                        activeColor: AppTheme.electricBlue,
                        onChanged: (val) {
                          setState(() {
                            _syncToSpouse = val ?? false;
                          });
                        },
                      ),
                      const Text(
                        '同步记录至配偶',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),

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
