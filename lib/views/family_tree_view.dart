import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/family_controller.dart';
import '../models/person.dart';
import '../services/z_algorithm.dart';
import '../widgets/person_details_sidebar.dart';
import '../widgets/person_dialog.dart';
import '../theme/app_theme.dart';
import 'ai_assistant_view.dart';

// ─────────────────────────────────────────────
// Data model for a positioned node
// ─────────────────────────────────────────────
class _NodePosition {
  final Person person;
  final Offset center;   // absolute canvas position
  final double radius;   // avatar circle radius
  final int steps;       // blood-distance from root
  final int generation;  // signed generation (negative = ancestor)

  const _NodePosition({
    required this.person,
    required this.center,
    required this.radius,
    required this.steps,
    required this.generation,
  });
}

// ─────────────────────────────────────────────
// Galaxy Layout Engine  (v5 – 水波纹三层扩散)
// ─────────────────────────────────────────────
class GalaxyLayoutEngine {

  // Generation color
  static Color generationColor(int generation) {
    if (generation < -1) return const Color(0xFF2196F3); // 祖辈 - 蓝
    if (generation == -1) return const Color(0xFFFFC107); // 父辈 - 黄
    if (generation == 0) return const Color(0xFF4CAF50);  // 平辈 - 绿
    return const Color(0xFFFF5722);                        // 子辈 - 橙
  }

  /// Build tiered ripple layout.
  static List<_NodePosition> compute({
    required List<Person> allPeople,
    required String rootId,
    required Offset canvasCenter,
    required Map<int, List<Person>> generationMap,
    int? seed,
  }) {
    if (allPeople.isEmpty) return [];

    final byId = {for (final p in allPeople) p.id: p};
    if (!byId.containsKey(rootId)) return [];

    // 使用水波纹三层扩散布局算法
    final layout = TieredRippleLayout(seed: seed);
    final layoutData = layout.compute(
      allPeople: allPeople,
      rootId: rootId,
      canvasCenter: canvasCenter,
      generationMap: generationMap,
    );

    // 转换为 _NodePosition 格式
    return layoutData.map((data) => _NodePosition(
      person: data.person,
      center: data.center,
      radius: data.radius,
      steps: data.tier,
      generation: data.generation,
    )).toList();
  }
}

// ─────────────────────────────────────────────
// Galaxy Painter  (v2 – with kinship lines)
// ─────────────────────────────────────────────
class GalaxyPainter extends CustomPainter {
  final List<_NodePosition> nodes;
  final String? selectedId;
  // Raw person list for drawing kinship edges
  final List<Person> people;

  const GalaxyPainter({
    required this.nodes,
    required this.people,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Layer 1 – grid
    _drawGrid(canvas, size);

    // Layer 2 – orbit rings (compact radii)
    _drawOrbitRings(canvas, center);

    // Layer 3 – kinship lines (below nodes)
    _drawKinshipLines(canvas);

    // Layer 4 – nodes on top
    for (final node in nodes) {
      _drawNode(canvas, node);
    }
  }

  // ── Grid ────────────────────────────────────
  void _drawGrid(Canvas canvas, Size size) {
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

  // ── Orbit rings (compact) ───────────────────
  void _drawOrbitRings(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [80.0, 160.0, 240.0, 300.0]) {
      canvas.drawCircle(center, r, paint);
    }
  }

  // ── Kinship lines ────────────────────────────
  // 贝塞尔曲线连线: 仅在 Parent-Child 和 Spouse-Spouse 之间绘制
  // 样式: 淡灰色贝塞尔曲线, 穿过圆圈下方
  void _drawKinshipLines(Canvas canvas) {
    // 淡灰色贝塞尔曲线
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Build fast id → center lookup
    final Map<String, Offset> centerOf = {
      for (final n in nodes) n.person.id: n.center
    };
    final Map<String, double> radiusOf = {
      for (final n in nodes) n.person.id: n.radius
    };

    // Track drawn pairs to avoid duplicates
    final Set<String> drawn = {};

    for (final person in people) {
      final fromPos = centerOf[person.id];
      if (fromPos == null) continue;

      // Parent-Child 贝塞尔曲线
      for (final childId in person.children) {
        final toPos = centerOf[childId];
        if (toPos == null) continue;
        
        final key = _edgeKey(person.id, childId);
        if (drawn.add(key)) {
          _drawBezierCurve(canvas, fromPos, toPos, radiusOf[person.id] ?? 0, 
              radiusOf[childId] ?? 0, linePaint);
        }
      }

      // Spouse-Spouse 贝塞尔曲线
      if (person.spouse != null) {
        final toPos = centerOf[person.spouse!];
        if (toPos != null) {
          final key = _edgeKey(person.id, person.spouse!);
          if (drawn.add(key)) {
            _drawBezierCurve(canvas, fromPos, toPos, radiusOf[person.id] ?? 0,
                radiusOf[person.spouse!] ?? 0, linePaint);
          }
        }
      }
    }
  }

  /// 绘制穿过圆圈下方的贝塞尔曲线
  void _drawBezierCurve(Canvas canvas, Offset from, Offset to, 
                        double fromRadius, double toRadius, Paint paint) {
    // 计算方向向量
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    
    if (distance < 1) return;

    // 单位向量
    final ux = dx / distance;
    final uy = dy / distance;

    // 起点和终点 (从圆圈边缘开始, 穿过下方)
    final start = Offset(
      from.dx + ux * fromRadius,
      from.dy + uy * fromRadius + fromRadius * 0.3, // 稍微向下偏移
    );
    final end = Offset(
      to.dx - ux * toRadius,
      to.dy - uy * toRadius + toRadius * 0.3, // 稍微向下偏移
    );

    // 控制点: 使曲线向下弯曲
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;
    final controlY = midY + distance * 0.15; // 向下弯曲

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(midX, controlY, end.dx, end.dy);

    canvas.drawPath(path, paint);
  }

  static String _edgeKey(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  // ── Individual node ──────────────────────────
  void _drawNode(Canvas canvas, _NodePosition node) {
    final isSelected = node.person.id == selectedId;
    final isRoot = node.person.id == 'root';
    final color = GalaxyLayoutEngine.generationColor(node.generation);
    final r = node.radius;
    final center = node.center;

    // Glow for selected / root
    if (isSelected || isRoot) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: isRoot ? 0.35 : 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, r + 8, glowPaint);
    }

    // Background fill
    final bgPaint = Paint()
      ..color = isRoot
          ? color.withValues(alpha: 0.9)
          : const Color(0xFF1A2030).withValues(alpha: 0.96);
    canvas.drawCircle(center, r, bgPaint);

    // Border ring
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.5;
    canvas.drawCircle(center, r, borderPaint);

    // Text sizing
    final fontSize = r >= 35 ? 13.0 : (r >= 24 ? 11.0 : 9.0);

    // Name
    final name = node.person.name;
    final namePainter = TextPainter(
      text: TextSpan(
        text: name.length > 4 ? '${name.substring(0, 3)}…' : name,
        style: TextStyle(
          color: isRoot ? Colors.white : color,
          fontSize: fontSize,
          fontWeight: isRoot ? FontWeight.bold : FontWeight.w500,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: r * 2);

    // Relationship label
    final rel = node.person.relationship;
    final relPainter = TextPainter(
      text: TextSpan(
        text: rel.length > 4 ? rel.substring(0, 4) : rel,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: math.max(7.0, fontSize - 2),
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: r * 2);

    // Vertical stack: relation above, name below
    final totalH = relPainter.height + 2 + namePainter.height;
    final topY = center.dy - totalH / 2;

    relPainter.paint(
      canvas,
      Offset(center.dx - relPainter.width / 2, topY),
    );
    namePainter.paint(
      canvas,
      Offset(center.dx - namePainter.width / 2, topY + relPainter.height + 2),
    );
  }

  @override
  bool shouldRepaint(covariant GalaxyPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.people != people;
  }
}

// ─────────────────────────────────────────────
// Main View
// ─────────────────────────────────────────────
class FamilyTreeView extends StatefulWidget {
  final FamilyController controller;

  const FamilyTreeView({super.key, required this.controller});

  @override
  State<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends State<FamilyTreeView> {
  // 布局刷新种子
  int _layoutSeed = DateTime.now().millisecondsSinceEpoch;

  void _refreshLayout() {
    setState(() {
      _layoutSeed = DateTime.now().millisecondsSinceEpoch;
    });
  }

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

  /// Given a canvas position and a list of nodes, return the tapped person id.
  String? _hitTest(Offset localPos, List<_NodePosition> nodes) {
    for (final node in nodes.reversed) {
      if ((localPos - node.center).distance <= node.radius) {
        return node.person.id;
      }
    }
    return null;
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
          final latestSelectedPerson =
              selectedId != null ? widget.controller.getPerson(selectedId) : null;

          if (centerPerson == null) {
            return const Center(child: Text('暂无数据'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                math.max(constraints.maxWidth, 1000),
                math.max(constraints.maxHeight, 1000),
              );
              final canvasCenter = Offset(canvasSize.width / 2, canvasSize.height / 2);

              final generationMap = widget.controller.calculateGenerations();
              final nodes = GalaxyLayoutEngine.compute(
                allPeople: widget.controller.allPeople,
                rootId: 'root',
                canvasCenter: canvasCenter,
                generationMap: generationMap,
                seed: _layoutSeed,
              );

              return Stack(
                children: [
                  // 0. 刷新按钮 (左上角)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _refreshLayout,
                      tooltip: '刷新布局',
                    ),
                  ),

                  // 1. Galaxy canvas (interactive)
                  Positioned.fill(
                    child: InteractiveViewer(
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(5000),
                      minScale: 0.1,
                      maxScale: 4.0,
                      child: GestureDetector(
                        onTapUp: (details) {
                          final id = _hitTest(details.localPosition, nodes);
                          if (id != null) {
                            widget.controller.selectPerson(id);
                          } else {
                            widget.controller.clearSelection();
                          }
                        },
                        child: CustomPaint(
                          size: canvasSize,
                          painter: GalaxyPainter(
                            nodes: nodes,
                            people: widget.controller.allPeople,
                            selectedId: selectedId,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Detail sidebar
                  if (latestSelectedPerson != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: PersonDetailsSidebar(
                        person: latestSelectedPerson,
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
}
