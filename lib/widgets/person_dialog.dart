import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PersonDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialRelationship;
  final String? initialBio;
  final String? initialGender;
  final Function(String name, String relationship, String bio, String gender) onSubmit;

  const PersonDialog({
    super.key,
    required this.title,
    this.initialName,
    this.initialRelationship,
    this.initialBio,
    this.initialGender,
    required this.onSubmit,
  });

  @override
  State<PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<PersonDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _relationshipController;
  late TextEditingController _bioController;
  String _gender = '男';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _relationshipController = TextEditingController(text: widget.initialRelationship);
    _bioController = TextEditingController(text: widget.initialBio);
    if (widget.initialGender != null) {
      _gender = widget.initialGender!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _nameController,
                  label: '姓名',
                  validator: (v) => v?.isEmpty == true ? '请输入姓名' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _relationshipController,
                  label: '称呼',
                  validator: (v) => v?.isEmpty == true ? '请输入称呼' : null,
                ),
                const SizedBox(height: 16),
                _buildGenderSelector(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _bioController,
                  label: '备注',
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.minimalistBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          widget.onSubmit(
                            _nameController.text,
                            _relationshipController.text,
                            _bioController.text,
                            _gender,
                          );
                          Navigator.of(context).pop();
                        }
                      },
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.electricBlue),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('性别', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: '男',
              label: Text('男'),
              icon: Icon(Icons.male),
            ),
            ButtonSegment<String>(
              value: '女',
              label: Text('女'),
              icon: Icon(Icons.female),
            ),
          ],
          selected: {_gender},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _gender = newSelection.first;
            });
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.minimalistBlue;
                }
                return Colors.transparent;
              },
            ),
            foregroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.white70;
              },
            ),
            side: WidgetStateProperty.all(
              BorderSide(color: AppTheme.minimalistBlue.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  // Helper method _genderRadio is no longer needed
}
