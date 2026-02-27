import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';
import '../controllers/family_controller.dart'; // 必须引入 Controller

class PersonDetailsSidebar extends StatelessWidget {
  final Person? person;
  final FamilyController controller; // 增加 controller 属性
  final VoidCallback onClose;
  final VoidCallback onAddParent;
  final VoidCallback onAddChild;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PersonDetailsSidebar({
    super.key,
    required this.person,
    required this.controller, // 构造函数要求传入
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
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey.withValues(alpha: 0.95),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部的固定标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
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
            ),
            
            // 下方内容区域设为可滚动
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头像
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
                    // 姓名
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
                    
                    // --- 基础信息区 ---
                    _buildInfoSection('备注', person!.bio),
                    const SizedBox(height: 24),
                    _buildInfoSection('性别', person!.gender),
                    const SizedBox(height: 32),

                    // --- 新增：动态关系网络展示区 ---
                    const Text(
                      '亲缘关系',
                      style: TextStyle(
                        color: AppTheme.electricBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRelationRow('配偶', _getSpouseName(person!, controller)),
                          const SizedBox(height: 12),
                          _buildRelationRow('父母', _getParentNames(person!, controller)),
                          const SizedBox(height: 12),
                          _buildRelationRow('子女', _getChildrenNames(person!, controller)),
                          const SizedBox(height: 12),
                          _buildRelationRow('兄弟姐妹', _getSiblingNames(person!, controller)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    
                    // --- 操作区 ---
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
                    _buildActionButton(context, icon: Icons.person_add, label: '添加父母', onTap: onAddParent),
                    _buildActionButton(context, icon: Icons.child_care, label: '添加子女', onTap: onAddChild),
                    _buildActionButton(context, icon: Icons.edit, label: '编辑信息', onTap: onEdit),
                    if (person!.id != 'root')
                      _buildActionButton(
                        context,
                        icon: Icons.delete,
                        label: '删除',
                        onTap: onDelete,
                        isDestructive: true,
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 关系行 UI 辅助组件 ---
  Widget _buildRelationRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
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

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, bool isDestructive = false}) {
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
              border: Border.all(color: isDestructive ? Colors.red.withValues(alpha: 0.5) : AppTheme.minimalistBlue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isDestructive ? Colors.redAccent : Colors.white70),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 辅助方法：通过 ID 查真实姓名 ---
  String _getSpouseName(Person p, FamilyController c) {
    if (p.spouse == null) return '暂无';
    return c.getPerson(p.spouse!)?.name ?? '未知';
  }

  String _getParentNames(Person p, FamilyController c) {
    if (p.parents.isEmpty) return '暂无';
    final names = p.parents.map((id) => c.getPerson(id)?.name ?? '').where((n) => n.isNotEmpty).toList();
    return names.isEmpty ? '暂无' : names.join('、');
  }

  String _getChildrenNames(Person p, FamilyController c) {
    if (p.children.isEmpty) return '暂无';
    final names = p.children.map((id) => c.getPerson(id)?.name ?? '').where((n) => n.isNotEmpty).toList();
    return names.isEmpty ? '暂无' : names.join('、');
  }

  String _getSiblingNames(Person p, FamilyController c) {
    if (p.parents.isEmpty) return '暂无';
    final parent = c.getPerson(p.parents.first);
    if (parent == null || parent.children.length <= 1) return '暂无';
    
    final siblingNames = parent.children
        .where((id) => id != p.id)
        .map((id) => c.getPerson(id)?.name ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    
    return siblingNames.isEmpty ? '暂无' : siblingNames.join('、');
  }
}