import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../controllers/family_controller.dart';
import '../models/person.dart';
import '../services/z_algorithm.dart';
import '../widgets/person_details_sidebar.dart';
import '../widgets/person_dialog.dart';
import '../theme/app_theme.dart';
import 'ai_assistant_view.dart';

// 搜索匹配算法: 匹配 name 或 relationship (case-insensitive)
bool _personMatchesQuery(Person p, String query) {
  if (query.isEmpty) return false;
  final q = query.toLowerCase();
  return p.name.toLowerCase().contains(q) ||
      p.relationship.toLowerCase().contains(q);
}

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
// Galaxy Painter  (v5 – Detail-Panel Aligned Highlighting)
// ─────────────────────────────────────────────
class GalaxyPainter extends CustomPainter {
  final List<_NodePosition> nodes;
  final String? selectedId;
  final List<Person> people;
  // 搜索高亮: 匹配到的节点 ID 集合
  final Set<String> highlightedIds;
  // 呼吸灯动画进度 [0, 1]
  final double breathPhase;

  const GalaxyPainter({
    required this.nodes,
    required this.people,
    this.selectedId,
    this.highlightedIds = const {},
    this.breathPhase = 0.0,
  });

  // 快速查找: id -> Person
  Map<String, Person> get _personById => {
    for (final p in people) p.id: p,
  };

  // ========== 关系计算 (与详细信息面板完全对齐) ==========
  
  // 获取配偶ID集合 (使用详细信息面板相同的算法)
  Set<String> _getSpouseIds(Person p) {
    final spouses = <String>{};
    // 通过子女反向查找配偶
    for (final childId in p.children) {
      final child = _personById[childId];
      if (child != null) {
        for (final parentId in child.parents) {
          if (parentId != p.id) {
            spouses.add(parentId);
          }
        }
      }
    }
    return spouses;
  }

  // 获取父母ID集合 (包含父母的配偶)
  Set<String> _getParentIds(Person p) {
    final parentIds = <String>{};
    // 先加直接关联的父母
    for (final id in p.parents) {
      final parent = _personById[id];
      if (parent != null) {
        parentIds.add(id);
        // 关键：顺便把父母的配偶也算进来（解决舅舅只有外婆没有外公的问题）
        for (final spouseChildId in parent.children) {
          final spouseChild = _personById[spouseChildId];
          if (spouseChild != null) {
            for (final otherParentId in spouseChild.parents) {
              if (otherParentId != id) {
                parentIds.add(otherParentId);
              }
            }
          }
        }
      }
    }
    return parentIds;
  }

  // 获取子女ID集合 (包含配偶的孩子)
  Set<String> _getChildrenIds(Person p) {
    final childrenIds = <String>{};
    // 自己的孩子
    for (final id in p.children) {
      childrenIds.add(id);
    }
    // 探测配偶的孩子（解决配偶的孩子也是我的孩子）
    for (final childId in p.children) {
      final child = _personById[childId];
      if (child != null) {
        for (final parentId in child.parents) {
          if (parentId != p.id) {
            final spouse = _personById[parentId];
            if (spouse != null) {
              for (final sChildId in spouse.children) {
                childrenIds.add(sChildId);
              }
            }
          }
        }
      }
    }
    return childrenIds;
  }

  // 获取兄弟姐妹ID集合
  Set<String> _getSiblingIds(Person p) {
    final siblingIds = <String>{};
    if (p.parents.isEmpty) return siblingIds;
    
    for (final parentId in p.parents) {
      final parent = _personById[parentId];
      if (parent != null) {
        for (final childId in parent.children) {
          if (childId != p.id) {
            siblingIds.add(childId);
          }
        }
      }
    }
    return siblingIds;
  }

  // 预计算所有需要连线的关系 (双向指针映射)
  // key: personId, value: 需要与之连线的节点ID集合
  Map<String, Set<String>> _buildConnectionMap() {
    final map = <String, Set<String>>{};
    
    for (final person in people) {
      final connections = <String>{};
      
      // 1. 父母连线
      connections.addAll(_getParentIds(person));
      
      // 2. 子女连线
      connections.addAll(_getChildrenIds(person));
      
      // 3. 配偶连线
      connections.addAll(_getSpouseIds(person));
      
      if (connections.isNotEmpty) {
        map[person.id] = connections;
      }
    }
    
    return map;
  }

  // 预计算所有关联节点 (用于高亮)
  // 包含: 父母、子女、配偶、兄弟姐妹
  Set<String> _buildRelatedSet(String personId) {
    final related = <String>{};
    final person = _personById[personId];
    if (person == null) return related;
    
    // 父母
    related.addAll(_getParentIds(person));
    // 子女
    related.addAll(_getChildrenIds(person));
    // 配偶
    related.addAll(_getSpouseIds(person));
    // 兄弟姐妹 (高亮但不连线)
    related.addAll(_getSiblingIds(person));
    
    return related;
  }

  // 检查 targetId 是否与选中的人有关联 (用于节点高亮)
  bool _isRelated(String targetId) {
    if (selectedId == null) return false;
    if (targetId == selectedId) return true;
    
    final related = _buildRelatedSet(selectedId!);
    return related.contains(targetId);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Layer 1 – grid
    _drawGrid(canvas, size);

    // Layer 2 – orbit rings (compact radii)
    _drawOrbitRings(canvas, center);

    // Layer 3 – kinship lines (直线, below nodes)
    _drawKinshipLines(canvas);

    // Layer 4 – nodes on top
    for (final node in nodes) {
      _drawNode(canvas, node);
    }

    // Layer 5 – 高亮外环 (呼吸灯效果)
    if (highlightedIds.isNotEmpty) {
      _drawHighlightRings(canvas);
    }
    
    // Layer 6 – 选中节点的高亮光环
    if (selectedId != null) {
      _drawSelectedNodeRing(canvas);
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
  // 直线连线: 使用与详细信息面板完全相同的算法
  // 兄弟姐妹之间不画线，只高亮节点
  // 样式: 统一使用 Colors.grey.withOpacity(0.3)
  void _drawKinshipLines(Canvas canvas) {
    // Build fast id → center lookup
    final Map<String, Offset> centerOf = {
      for (final n in nodes) n.person.id: n.center
    };

    // Track drawn pairs to avoid duplicates
    final Set<String> drawn = {};
    
    // 预计算连线关系
    final connectionMap = _buildConnectionMap();

    for (final person in people) {
      final fromPos = centerOf[person.id];
      if (fromPos == null) continue;

      // 获取所有需要连线的人 (父母、子女、配偶)
      final connections = connectionMap[person.id] ?? <String>{};

      for (final targetId in connections) {
        final toPos = centerOf[targetId];
        if (toPos == null) continue;
        
        final key = _edgeKey(person.id, targetId);
        if (drawn.add(key)) {
          // 高亮条件: 选中的人是连线的一端
          final isHighlighted = selectedId != null && 
              (person.id == selectedId || targetId == selectedId);
          
          final linePaint = Paint()
            ..color = isHighlighted 
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.grey.withValues(alpha: 0.3)
            ..strokeWidth = isHighlighted ? 2.0 : 1.0
            ..style = PaintingStyle.stroke;
          
          canvas.drawLine(fromPos, toPos, linePaint);
        }
      }
    }
  }

  // ── 高亮外环 (呼吸灯效果) ──────────────────
  void _drawHighlightRings(Canvas canvas) {
    final pulse = 0.5 + 0.5 * math.sin(breathPhase * 2 * math.pi);
    final ringAlpha = 0.4 + 0.5 * pulse;
    final ringExpand = 4.0 + 5.0 * pulse;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final node in nodes) {
      if (!highlightedIds.contains(node.person.id)) continue;
      final color = GalaxyLayoutEngine.generationColor(node.generation)
          .withValues(alpha: ringAlpha);
      ringPaint.color = color;
      canvas.drawCircle(node.center, node.radius + ringExpand, ringPaint);
      final glowPaint = Paint()
        ..color = color.withValues(alpha: ringAlpha * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(node.center, node.radius + ringExpand + 4, glowPaint);
    }
  }

  // ── 选中节点的高亮光环 ────────────────────────
  void _drawSelectedNodeRing(Canvas canvas) {
    for (final node in nodes) {
      if (node.person.id != selectedId) continue;
      
      // 绘制高亮光环
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      
      // 外环
      canvas.drawCircle(node.center, node.radius + 6, ringPaint);
      
      // 发光效果
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(node.center, node.radius + 10, glowPaint);
    }
  }

  static String _edgeKey(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  // ── Individual node ──────────────────────────
  void _drawNode(Canvas canvas, _NodePosition node) {
    final isSelected = node.person.id == selectedId;
    final isRoot = node.person.id == 'root';
    // 使用双向指针判定关联关系 (直接关联 + 兄弟姐妹)
    final isRelated = _isRelated(node.person.id);
    final color = GalaxyLayoutEngine.generationColor(node.generation);
    final r = node.radius;
    final center = node.center;

    // 焦点模式: 计算透明度
    double opacity = 1.0;
    if (selectedId != null) {
      if (isSelected || isRelated) {
        opacity = 1.0; // 选中节点或关联节点保持不透明
      } else {
        opacity = 0.15; // 无关节点降低透明度
      }
    }

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
          ? color.withValues(alpha: 0.9 * opacity)
          : Color.fromRGBO(26, 32, 48, (0.96 * opacity).toDouble());
    canvas.drawCircle(center, r, bgPaint);

    // Border ring
    final borderPaint = Paint()
      ..color = isSelected 
          ? Colors.white.withValues(alpha: opacity)
          : color.withValues(alpha: opacity)
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
          color: (isRoot ? Colors.white : color).withValues(alpha: opacity),
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
          color: Colors.white.withValues(alpha: 0.5 * opacity),
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
        oldDelegate.people != people ||
        oldDelegate.highlightedIds != highlightedIds ||
        oldDelegate.breathPhase != breathPhase;
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

class _FamilyTreeViewState extends State<FamilyTreeView>
    with TickerProviderStateMixin {
  // 布局刷新种子
  int _layoutSeed = DateTime.now().millisecondsSinceEpoch;

  // 搜索相关
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // 呼吸灯动画
  late final AnimationController _breathCtrl;
  
  // 焦点模式: 选中节点的缩放动画
  late final AnimationController _scaleCtrl;
  String? _focusedId; // 当前焦点节点ID
  
  // 详细信息侧边栏显示控制
  bool _showDetailSidebar = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    
    // 缩放动画控制器
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _breathCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }
  
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
      // 考虑缩放后的半径进行命中测试
      final effectiveRadius = node.person.id == _focusedId 
          ? node.radius * 1.2 
          : node.radius;
      if ((localPos - node.center).distance <= effectiveRadius) {
        return node.person.id;
      }
    }
    return null;
  }
  
  // 显示详细信息侧边栏
  void _showPersonDetail() {
    setState(() {
      _showDetailSidebar = true;
    });
  }
  
  // 关闭详细信息侧边栏
  void _closeDetailSidebar() {
    setState(() {
      _showDetailSidebar = false;
    });
    widget.controller.clearSelection();
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
              
              // 搜索高亮: 匹配到的节点 ID
              final highlightedIds = _searchQuery.isEmpty
                  ? <String>{}
                  : widget.controller.allPeople
                      .where((p) => _personMatchesQuery(p, _searchQuery))
                      .map((p) => p.id)
                      .toSet();
              
              // 注意: 现在 GalaxyPainter 内部通过双向指针判定关联关系
              // 不再需要外部传入 relatedIds 和 spouseMap
              
              // 应用缩放动画到节点
              final animatedNodes = nodes.map((node) {
                if (node.person.id == _focusedId) {
                  final scale = 1.0 + (_scaleCtrl.value * 0.2); // 1.0 -> 1.2
                  return _NodePosition(
                    person: node.person,
                    center: node.center,
                    radius: node.radius * scale,
                    steps: node.steps,
                    generation: node.generation,
                  );
                }
                return node;
              }).toList();
              
              return Stack(
                children: [
                  // 0. 刷新按鈕 (左上角)
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
                            // 焦点模式: 点击节点只设置焦点，不弹出侧边栏
                            setState(() {
                              _focusedId = id;
                              _showDetailSidebar = false;
                            });
                            widget.controller.selectPerson(id);
                            _scaleCtrl.forward(from: 0.0);
                          } else {
                            // 点击空白处清除焦点
                            setState(() {
                              _focusedId = null;
                              _showDetailSidebar = false;
                            });
                            widget.controller.clearSelection();
                            _scaleCtrl.reverse();
                          }
                        },
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_breathCtrl, _scaleCtrl]),
                          builder: (context, _) => CustomPaint(
                            size: canvasSize,
                            painter: GalaxyPainter(
                              nodes: animatedNodes,
                              people: widget.controller.allPeople,
                              selectedId: _focusedId,
                              highlightedIds: highlightedIds,
                              breathPhase: _breathCtrl.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              
                  // 2. 搜索框 (顶部中间, 半透明毛玻璃)
                  Positioned(
                    top: 16,
                    left: 70,
                    right: 70,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '搜索姓名或关系…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 18,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.white.withValues(alpha: 0.6),
                                      size: 16,
                                    ),
                                    onPressed: () => _searchCtrl.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              
                  // 3. 底部浮动毛玻璃按钮 (仅在选中节点时显示)
                  if (_focusedId != null && !_showDetailSidebar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 40,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showPersonDetail,
                                  borderRadius: BorderRadius.circular(28),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '显示详细信息',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.white.withValues(alpha: 0.7),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // 4. Detail sidebar (仅点击按钮后显示)
                  if (_showDetailSidebar && latestSelectedPerson != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: PersonDetailsSidebar(
                        person: latestSelectedPerson,
                        controller: widget.controller,
                        onClose: _closeDetailSidebar,
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
