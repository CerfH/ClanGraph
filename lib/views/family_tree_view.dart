import 'package:flutter/material.dart';
import '../controllers/family_controller.dart';
import '../models/person.dart';
import '../widgets/person_node_widget.dart';
import '../widgets/person_details_sidebar.dart';
import '../widgets/person_dialog.dart';
import '../theme/app_theme.dart';
import 'ai_assistant_view.dart'; // 引入 AI 助手页面

class FamilyTreeView extends StatefulWidget {
  final FamilyController controller;

  const FamilyTreeView({super.key, required this.controller});

  @override
  State<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends State<FamilyTreeView> {
  void _showAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: AIAssistantView(controller: widget.controller),
        ),
      ),
    );
  }

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
          final selectedId = widget.controller.selectedPerson?.id;
          final latestSelectedPerson = selectedId != null ? widget.controller.getPerson(selectedId) : null;
          final generations = widget.controller.calculateGenerations();
          if (centerPerson == null) {
            return const Center(child: Text('暂无数据'));
          }

          // Sort generations keys
          final sortedGenKeys = generations.keys.toList()..sort();

          return Stack(
            children: [
              // 1. 底层：Background Grid
              Positioned.fill(child: CustomPaint(painter: GridPainter())),

              // 2. 中层：Dynamic Tree View (交互层)
              Positioned.fill(
                child: InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(10000),
                  minScale: 0.05,
                  maxScale: 3.0,
                  // --- 核心手术区：移除 OverflowBox，改用 Center ---
                  child: Container(
                    // 给图谱外围加一点基础的内边距，防止贴边
                    padding: const EdgeInsets.all(100), 
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // 紧凑排列
                      children: sortedGenKeys.map((gen) {
                        return _buildGenerationRow(gen, generations[gen]!);
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // 3. 顶层：Sidebar (操作层)
              if (latestSelectedPerson != null) // 使用最新获取的对象
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: PersonDetailsSidebar(
                    person: latestSelectedPerson, // 传入最新的引用
                    controller: widget.controller,
                    onClose: () => widget.controller.clearSelection(),
                    onAddParent: () =>
                        _showAddParentDialog(context, latestSelectedPerson.id),
                    onAddChild: () =>
                        _showAddChildDialog(context, latestSelectedPerson.id),
                    onEdit: () =>
                        _showEditPersonDialog(context, latestSelectedPerson),
                    onDelete: () => _showDeleteConfirmation(
                      context,
                      latestSelectedPerson.id,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAIAssistant,
        backgroundColor: AppTheme.electricBlue,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
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
