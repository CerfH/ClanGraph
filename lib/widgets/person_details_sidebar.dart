import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';

class PersonDetailsSidebar extends StatelessWidget {
  final Person? person;
  final VoidCallback onClose;
  final VoidCallback onAddParent;
  final VoidCallback onAddChild;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PersonDetailsSidebar({
    super.key,
    required this.person,
    required this.onClose,
    required this.onAddParent,
    required this.onAddChild,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (person == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 320,
      height: double.infinity,
      color: AppTheme.surfaceGrey.withValues(alpha: 0.95),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '详细信息',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.electricBlue,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.deepSpaceGrey,
              child: Icon(
                person!.gender == '男' ? Icons.face : Icons.face_3,
                size: 48,
                color: AppTheme.electricBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              person!.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 24,
              ),
            ),
          ),
          Center(
            child: Text(
              person!.relationship,
              style: const TextStyle(
                color: AppTheme.electricBlue,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoSection('备注', person!.bio),
          const SizedBox(height: 24),
          _buildInfoSection('性别', person!.gender),
          const SizedBox(height: 32),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            '操作',
            style: TextStyle(
              color: AppTheme.electricBlue,
              letterSpacing: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            context,
            icon: Icons.person_add,
            label: '添加父母',
            onTap: onAddParent,
          ),
          _buildActionButton(
            context,
            icon: Icons.child_care,
            label: '添加子女',
            onTap: onAddChild,
          ),
          _buildActionButton(
            context,
            icon: Icons.edit,
            label: '编辑信息',
            onTap: onEdit,
          ),
          if (person!.id != 'root')
            _buildActionButton(
              context,
              icon: Icons.delete,
              label: '删除',
              onTap: onDelete,
              isDestructive: true,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDestructive ? Colors.red.withValues(alpha: 0.5) : AppTheme.minimalistBlue,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDestructive ? Colors.redAccent : Colors.white70,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isDestructive ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
