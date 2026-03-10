import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 水波纹三层扩散布局 (Tiered Ripple Layout)
//
// Core Algorithm:
//   1. 三级尺寸定义:
//      - T1 (38dp): 我、父母、配偶、亲兄妹、子女
//      - T2 (28dp): 祖父母、姑/舅、表/堂亲
//      - T3 (18dp): 其他
//
//   2. 水波纹层级布局:
//      - 中心: 'Me' 固定在屏幕中央
//      - 第一环 (100-140dp): 仅放置 T1 节点
//      - 第二环 (180-260dp): 仅放置 T2 节点
//      - 第三环 (300-380dp): 仅放置 T3 节点
//
//   3. 硬核防重叠:
//      - Distance(C1, C2) < (R1 + R2 + 15dp) 时重新随机位置
//      - 直到完全不重叠为止
//
//   4. 血缘连线:
//      - 仅保留"父母-子女"和"配偶-配偶"之间的淡灰色贝塞尔曲线
//      - 连线穿过圆圈下方
// ═══════════════════════════════════════════════════════════════════════════════

/// 节点布局数据
class NodeLayoutData {
  final Person person;
  final Offset center;
  final double radius;
  final int tier;           // 层级: 1, 2, 3
  final int generation;     // 代数
  final double angle;       // 极坐标角度
  final double orbitRadius; // 极坐标半径
  final bool isInLaw;       // 是否为姻亲

  const NodeLayoutData({
    required this.person,
    required this.center,
    required this.radius,
    required this.tier,
    required this.generation,
    required this.angle,
    required this.orbitRadius,
    this.isInLaw = false,
  });

  @override
  String toString() {
    final type = isInLaw ? '[姻]' : '[血]';
    return '$type ${person.name}(T$tier, r=${radius.toInt()}dp)';
  }
}

/// 三级尺寸定义
class TierConfig {
  /// T1 (38dp): 我、父母、配偶、亲兄妹、子女
  static const double radiusT1 = 38.0;
  
  /// T2 (28dp): 祖父母、姑/舅、表/堂亲  
  static const double radiusT2 = 28.0;
  
  /// T3 (18dp): 其他
  static const double radiusT3 = 18.0;

  /// 第一环半径范围: 100-140dp
  static const double ring1Min = 100.0;
  static const double ring1Max = 140.0;

  /// 第二环半径范围: 180-260dp
  static const double ring2Min = 180.0;
  static const double ring2Max = 260.0;

  /// 第三环半径范围: 300-380dp
  static const double ring3Min = 300.0;
  static const double ring3Max = 380.0;

  /// 防重叠间隙
  static const double collisionGap = 15.0;

  /// 根据层级获取半径
  static double getRadius(int tier) {
    switch (tier) {
      case 1: return radiusT1;
      case 2: return radiusT2;
      case 3: return radiusT3;
      default: return radiusT3;
    }
  }

  /// 根据层级获取半径范围
  static (double min, double max) getRingRange(int tier) {
    switch (tier) {
      case 1: return (ring1Min, ring1Max);
      case 2: return (ring2Min, ring2Max);
      case 3: return (ring3Min, ring3Max);
      default: return (ring3Min, ring3Max);
    }
  }
}

/// 水波纹三层扩散布局引擎
class TieredRippleLayout {
  final math.Random _random;

  TieredRippleLayout({int? seed}) : _random = math.Random(seed);

 /// 计算节点层级 (T1, T2, T3)
  /// 
  /// T1 (38dp): 我、父母、配偶、亲兄妹、子女
  /// T2 (28dp): 祖父母、姑/舅、表/堂亲
  /// T3 (18dp): 其他
  ///
  /// Fix 1 - 姻亲等级继承: 若一人初判为 T3，但其配偶为 T1/T2，则继承配偶等级
  /// Fix 2 - 表亲双路径: 无论表弟的父母是"大姑"还是"大姑父"被录入系统，都能正确识别为 T2
  /// Fix 3 - 祖辈辈分推断: 利用 relationship 字段关键词兜底，解决 AI 无法判断关系时辈分错乱
  int _calculateTier(Person person, Map<String, Person> byId, String rootId) {
    // Root 永远是 T1
    if (person.id == rootId) return 1;

    final root = byId[rootId];
    if (root == null) return 3;

    // 检查是否为配偶
    if (root.spouse == person.id) return 1;

    // 检查是否为父母
    if (root.parents.contains(person.id)) return 1;

    // 检查是否为子女
    if (root.children.contains(person.id)) return 1;

    // 检查是否为亲兄妹 (有共同父母)
    for (final parentId in root.parents) {
      final parent = byId[parentId];
      if (parent != null && parent.children.contains(person.id)) {
        return 1;
      }
    }

    // 检查是否为祖父母 (父母的父母)
    for (final parentId in root.parents) {
      final parent = byId[parentId];
      if (parent != null) {
        if (parent.parents.contains(person.id)) return 2; // 祖父母
        if (parent.spouse == person.id) return 2; // 父母的配偶 (继父母等)
      }
    }

    // 检查是否为姑/舅 (父母的兄妹)
    for (final parentId in root.parents) {
      final parent = byId[parentId];
      if (parent != null) {
        for (final grandparentId in parent.parents) {
          final grandparent = byId[grandparentId];
          if (grandparent != null && grandparent.children.contains(person.id)) {
            return 2; // 父母的兄妹
          }
        }
      }
    }

    // ── Fix 2: 表/堂亲双路径检查 ──────────────────────────────────
    // 路径 A: 通过血亲侧（姑/舅是血亲子女）
    // 路径 B: 通过姻亲侧（姑/舅的配偶被录入系统，其配偶是父母的兄妹）
    // 只要 person 的父母中任意一人是"父母的兄妹"或"父母兄妹的配偶"，该人即为 T2
    for (final personParentId in person.parents) {
      final personParent = byId[personParentId];
      if (personParent == null) continue;

      // 路径 A: personParent 是 root 的父母的兄妹 (血亲姑/舅)
      for (final rootParentId in root.parents) {
        final rootParent = byId[rootParentId];
        if (rootParent == null) continue;
        for (final gpId in rootParent.parents) {
          final gp = byId[gpId];
          if (gp != null && gp.children.contains(personParentId)) {
            return 2; // 表/堂亲 (血亲路径)
          }
        }
      }

      // 路径 B: personParent 的配偶是 root 的父母的兄妹 (姻亲路径，小姑父→表弟)
      if (personParent.spouse != null) {
        final personParentSpouseId = personParent.spouse!;
        for (final rootParentId in root.parents) {
          final rootParent = byId[rootParentId];
          if (rootParent == null) continue;
          for (final gpId in rootParent.parents) {
            final gp = byId[gpId];
            if (gp != null && gp.children.contains(personParentSpouseId)) {
              return 2; // 表/堂亲 (姻亲路径)
            }
          }
        }
      }
    }

    // ── Fix 1: 姻亲等级继承 ──────────────────────────────────────
    // 若当前节点初判为 T3，但其配偶已经是 T1/T2，则继承配偶等级
    // 这确保了「小姑父」与「小姑」始终同等级、同大小
    if (person.spouse != null) {
      final spouse = byId[person.spouse!];
      if (spouse != null) {
        final spouseTier = _calculateTierBloodOnly(spouse, byId, rootId);
        if (spouseTier < 3) return spouseTier;
      }
    }

    // ── Fix 3: relationship 关键词辅助兜底 ──────────────────────
    // 当 AI 录入时只知道存在某人但无法建立完整关系链时，
    // 通过 relationship 字段中的辅助关键词进行层级推断
    final tier = _inferTierFromRelationship(person.relationship);
    if (tier != null) return tier;

    // 其他为 T3
    return 3;
  }

  /// 仅通过血缘路径计算层级 (不含姻亲继承, 避免循环递归)
  int _calculateTierBloodOnly(Person person, Map<String, Person> byId, String rootId) {
    if (person.id == rootId) return 1;
    final root = byId[rootId];
    if (root == null) return 3;

    if (root.spouse == person.id) return 1;
    if (root.parents.contains(person.id)) return 1;
    if (root.children.contains(person.id)) return 1;

    for (final parentId in root.parents) {
      final parent = byId[parentId];
      if (parent != null && parent.children.contains(person.id)) return 1;
    }

    for (final parentId in root.parents) {
      final parent = byId[parentId];
      if (parent != null) {
        if (parent.parents.contains(person.id)) return 2;
        if (parent.spouse == person.id) return 2;
      }
    }

    for (final parentId in root.parents) {
      final parent = byId[parentId];
      if (parent != null) {
        for (final gpId in parent.parents) {
          final gp = byId[gpId];
          if (gp != null && gp.children.contains(person.id)) return 2;
        }
      }
    }

    // 表/堂亲血亲路径
    for (final personParentId in person.parents) {
      for (final rootParentId in root.parents) {
        final rootParent = byId[rootParentId];
        if (rootParent == null) continue;
        for (final gpId in rootParent.parents) {
          final gp = byId[gpId];
          if (gp != null && gp.children.contains(personParentId)) return 2;
        }
      }
    }

    return 3;
  }

  /// 通过 relationship 字段关键词推断层级
  /// 解决 AI 无法建立完整关系链时（如"老太"只知道是某人的父亲）的辈分错乱问题
  int? _inferTierFromRelationship(String relationship) {
    final rel = relationship.toLowerCase();

    // T1 关键词：直系亲属
    const t1Keywords = [
      '父亲', '母亲', '爸爸', '妈妈', '老爸', '老妈',
      '儿子', '女儿', '配偶', '丈夫', '妻子', '老公', '老婆',
      '兄弟', '姐妹', '哥哥', '弟弟', '姐姐', '妹妹',
      'father', 'mother', 'son', 'daughter', 'husband', 'wife', 'sibling',
    ];
    for (final kw in t1Keywords) {
      if (rel.contains(kw)) return 1;
    }

    // T2 关键词：祖辈、姑舅、表堂
    const t2Keywords = [
      '爷爷', '奶奶', '姥爷', '外公', '姥姥', '外婆', '祖父', '祖母', '外祖',
      '姑姑', '姑父', '舅舅', '舅妈', '姨妈', '姨夫', '伯父', '叔叔', '伯伯',
      '表哥', '表弟', '表姐', '表妹', '堂哥', '堂弟', '堂姐', '堂妹',
      '叔父', '大伯', '二伯', '大叔', '二叔',
      'grandfather', 'grandmother', 'grandpa', 'grandma', 'uncle', 'aunt', 'cousin',
    ];
    for (final kw in t2Keywords) {
      if (rel.contains(kw)) return 2;
    }

    // T2 关键词：曾祖辈（按T2处理，避免完全消失在T3边缘）
    const t2AncestorKeywords = [
      '老太', '太爷', '太奶', '曾祖', '高祖', '外曾祖', '外太',
      'great-grand', 'great grand',
    ];
    for (final kw in t2AncestorKeywords) {
      if (rel.contains(kw)) return 2;
    }

    return null; // 无法推断
  }

  /// 硬核防重叠检测
  bool _checkCollision(Offset candidate, double radius, List<NodeLayoutData> placed) {
    for (final node in placed) {
      final distance = (candidate - node.center).distance;
      final minDistance = radius + node.radius + TierConfig.collisionGap;
      if (distance < minDistance) {
        return true; // 发生碰撞
      }
    }
    return false;
  }

  /// 计算水波纹三层扩散布局
  List<NodeLayoutData> compute({
    required List<Person> allPeople,
    required String rootId,
    required Offset canvasCenter,
    required Map<int, List<Person>> generationMap,
  }) {
    if (allPeople.isEmpty) return [];

    final byId = {for (final p in allPeople) p.id: p};
    if (!byId.containsKey(rootId)) return [];

    // 构建代数映射
    final generationOf = <String, int>{};
    for (final entry in generationMap.entries) {
      for (final p in entry.value) {
        generationOf[p.id] = entry.key;
      }
    }

    // 1. 分类节点到三个层级
    final tier1Nodes = <Person>[];
    final tier2Nodes = <Person>[];
    final tier3Nodes = <Person>[];

    for (final person in allPeople) {
      final tier = _calculateTier(person, byId, rootId);
      switch (tier) {
        case 1: tier1Nodes.add(person); break;
        case 2: tier2Nodes.add(person); break;
        case 3: tier3Nodes.add(person); break;
      }
    }

    // 2. 放置节点 (从中心向外)
    final results = <NodeLayoutData>[];

    // Root 固定在中心
    results.add(NodeLayoutData(
      person: byId[rootId]!,
      center: canvasCenter,
      radius: TierConfig.radiusT1,
      tier: 1,
      generation: generationOf[rootId] ?? 0,
      angle: 0,
      orbitRadius: 0,
      isInLaw: false,
    ));

    // 放置 T1 节点 (第一环: 100-140dp)
    _placeTierNodes(
      tier1Nodes.where((p) => p.id != rootId).toList(),
      1,
      TierConfig.ring1Min,
      TierConfig.ring1Max,
      canvasCenter,
      results,
      generationOf,
    );

    // 放置 T2 节点 (第二环: 180-260dp)
    _placeTierNodes(
      tier2Nodes,
      2,
      TierConfig.ring2Min,
      TierConfig.ring2Max,
      canvasCenter,
      results,
      generationOf,
    );

    // 放置 T3 节点 (第三环: 300-380dp)
    _placeTierNodes(
      tier3Nodes,
      3,
      TierConfig.ring3Min,
      TierConfig.ring3Max,
      canvasCenter,
      results,
      generationOf,
    );

    return results;
  }

  /// 放置指定层级的节点
  void _placeTierNodes(
    List<Person> nodes,
    int tier,
    double minRadius,
    double maxRadius,
    Offset canvasCenter,
    List<NodeLayoutData> placed,
    Map<String, int> generationOf,
  ) {
    final radius = TierConfig.getRadius(tier);

    for (final person in nodes) {
      // 硬核防重叠: 循环尝试直到不重叠
      Offset? finalPosition;
      double? finalAngle;
      double? finalOrbitRadius;

      const maxAttempts = 100;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final orbitRadius = minRadius + _random.nextDouble() * (maxRadius - minRadius);
        final angle = _random.nextDouble() * 2 * math.pi;
        
        final candidate = Offset(
          canvasCenter.dx + orbitRadius * math.cos(angle),
          canvasCenter.dy + orbitRadius * math.sin(angle),
        );

        if (!_checkCollision(candidate, radius, placed)) {
          finalPosition = candidate;
          finalAngle = angle;
          finalOrbitRadius = orbitRadius;
          break;
        }
      }

      // 如果还是冲突, 尝试微调半径
      if (finalPosition == null) {
        for (int attempt = 0; attempt < maxAttempts; attempt++) {
          final orbitRadius = maxRadius + 20 + _random.nextDouble() * 60;
          final angle = _random.nextDouble() * 2 * math.pi;
          
          final candidate = Offset(
            canvasCenter.dx + orbitRadius * math.cos(angle),
            canvasCenter.dy + orbitRadius * math.sin(angle),
          );

          if (!_checkCollision(candidate, radius, placed)) {
            finalPosition = candidate;
            finalAngle = angle;
            finalOrbitRadius = orbitRadius;
            break;
          }
        }
      }

      // 最终兜底: 随机位置
      finalPosition ??= Offset(
        canvasCenter.dx + (minRadius + maxRadius) / 2,
        canvasCenter.dy,
      );
      finalAngle ??= 0;
      finalOrbitRadius ??= (minRadius + maxRadius) / 2;

      placed.add(NodeLayoutData(
        person: person,
        center: finalPosition,
        radius: radius,
        tier: tier,
        generation: generationOf[person.id] ?? 0,
        angle: finalAngle,
        orbitRadius: finalOrbitRadius,
        isInLaw: _isInLaw(person, placed),
      ));
    }
  }

  /// 判断是否为姻亲
  bool _isInLaw(Person person, List<NodeLayoutData> placed) {
    if (person.spouse == null) return false;
    // 如果配偶已经在 placed 中, 则当前是姻亲
    return placed.any((n) => n.person.id == person.spouse);
  }
}

/// 兼容旧 API 的别名
class NaturalClusterLayout {
  static List<NodeLayoutData> compute({
    required List<Person> allPeople,
    required String rootId,
    required Offset canvasCenter,
    required Map<int, List<Person>> generationMap,
  }) {
    final layout = TieredRippleLayout();
    return layout.compute(
      allPeople: allPeople,
      rootId: rootId,
      canvasCenter: canvasCenter,
      generationMap: generationMap,
    );
  }
}

typedef ZScoreCalculator = TieredRippleLayout;
