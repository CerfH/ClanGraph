import 'package:flutter/material.dart';
import '../controllers/family_controller.dart';
import '../models/person.dart';
import '../widgets/person_node_widget.dart';
import '../widgets/person_details_sidebar.dart';
import '../widgets/person_dialog.dart';
import '../theme/app_theme.dart';

class FamilyTreeView extends StatefulWidget {
  final FamilyController controller;

  const FamilyTreeView({super.key, required this.controller});

  @override
  State<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends State<FamilyTreeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家族智慧图谱'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final centerPerson = widget.controller.centerPerson;
          final selectedPerson = widget.controller.selectedPerson;
          final generations = widget.controller.calculateGenerations();

          if (centerPerson == null) {
            return const Center(child: Text('暂无数据'));
          }

          // Sort generations keys
          final sortedGenKeys = generations.keys.toList()..sort();

          return Stack(
            children: [
              // Background Grid
              Positioned.fill(child: CustomPaint(painter: GridPainter())),

              // Dynamic Tree View
              Positioned.fill(
                // 占满全屏，确保手势随处可用
                child: InteractiveViewer(
                  // 1. 允许无限外扩的边界
                  boundaryMargin: const EdgeInsets.all(2000),
                  minScale: 0.1,
                  maxScale: 2.0,
                  // 2. 初始位置：我们将内容放在一个巨大的 Container 里
                  child: Container(
                    width: 5000, // 设定一个 5000 像素宽的虚拟空间
                    height: 5000, // 设定一个 5000 像素高的虚拟空间
                    color: Colors.transparent, // 必须透明，否则背景网格看不见
                    child: OverflowBox(
                      // 允许内部内容超出，不受父级约束
                      minWidth: 0,
                      maxWidth: double.infinity,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // 让家谱始终处于这 5000 像素的中心
                        children: sortedGenKeys.map((gen) {
                          return _buildGenerationRow(gen, generations[gen]!);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              // Sidebar
              if (selectedPerson != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: PersonDetailsSidebar(
                    person: selectedPerson,
                    onClose: () => widget.controller.clearSelection(),
                    onAddParent: () =>
                        _showAddParentDialog(context, selectedPerson.id),
                    onAddChild: () =>
                        _showAddChildDialog(context, selectedPerson.id),
                    onEdit: () =>
                        _showEditPersonDialog(context, selectedPerson),
                    onDelete: () =>
                        _showDeleteConfirmation(context, selectedPerson.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGenerationRow(int gen, List<Person> people) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Generation Label
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            _getGenerationLabel(gen),
            style: _generationStyle.copyWith(
              color: gen == 0 ? AppTheme.electricBlue : Colors.white24,
            ),
          ),
        ),

        // People Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: people
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildNode(p),
                  ),
                )
                .toList(),
          ),
        ),

        // Connector Line (only if not the last generation)
        // Note: In this simplified view, we just add spacing.
        // Real connecting lines between specific parents/children would require a much more complex layout engine.
        const SizedBox(height: 40),
      ],
    );
  }

  String _getGenerationLabel(int gen) {
    if (gen == 0) return '当前辈分';
    if (gen < 0) return '祖辈 ${gen.abs()} 代';
    return '子辈 $gen 代';
  }

  void _showAddParentDialog(BuildContext context, String childId) {
    showDialog(
      context: context,
      builder: (ctx) => PersonDialog(
        title: '添加父母',
        onSubmit: (name, relationship, bio, gender) {
          widget.controller.addParent(childId, name, relationship, bio, gender);
        },
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, String parentId) {
    showDialog(
      context: context,
      builder: (ctx) => PersonDialog(
        title: '添加子女',
        onSubmit: (name, relationship, bio, gender) {
          widget.controller.addChild(parentId, name, relationship, bio, gender);
        },
      ),
    );
  }

  void _showEditPersonDialog(BuildContext context, Person person) {
    showDialog(
      context: context,
      builder: (ctx) => PersonDialog(
        title: '编辑信息',
        initialName: person.name,
        initialRelationship: person.relationship,
        initialBio: person.bio,
        initialGender: person.gender,
        onSubmit: (name, relationship, bio, gender) {
          widget.controller.updatePerson(
            person.id,
            name,
            relationship,
            bio,
            gender,
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceGrey,
        title: const Text('确认删除', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定要删除该成员吗？此操作无法撤销。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              widget.controller.deletePerson(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(Person person) {
    final isCenter = person.id == 'root';
    return Container(
      decoration: isCenter
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppTheme.minimalistBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            )
          : null,
      child: PersonNodeWidget(
        person: person,
        isSelected: widget.controller.selectedPerson?.id == person.id,
        onTap: () => widget.controller.selectPerson(person.id),
      ),
    );
  }

  static const _generationStyle = TextStyle(
    color: Colors.white24,
    fontSize: 10,
    letterSpacing: 2.0,
    fontWeight: FontWeight.bold,
  );
}

// Simple grid background for "Tech" feel
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const double spacing = 40;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
