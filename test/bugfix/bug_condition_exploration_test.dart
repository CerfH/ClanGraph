// Bugfix Spec: delete-color-export-center-fix
// Task 1: Bug 条件探索测试（修复前运行）
//
// 这些测试编码了期望行为。
// 在未修复代码上，这些测试应该 FAIL（失败即证明 Bug 存在）。
// 修复后，这些测试应该 PASS。
//
// **Validates: Requirements 1.1, 1.3, 1.4, 1.8**

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clangraph/controllers/family_controller.dart';
import 'package:clangraph/models/person.dart';
import 'package:clangraph/services/dfs_extractor.dart';
import 'package:clangraph/views/family_tree_view.dart';

/// 创建一个干净的 FamilyController（绕过 SharedPreferences 异步加载）
FamilyController _makeController() {
  SharedPreferences.setMockInitialValues({});
  return FamilyController();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 1 探索：删除配偶后，原人员的 spouseId 应被清除
  //
  // 期望行为：删除 B 后，A.spouseId 应为 null
  // 未修复代码上：A.spouseId 仍为 B 的 ID（悬空引用），测试 FAIL
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 1 探索：删除配偶后 spouseId 应被清除', () {
    test('删除配偶 B 后，A.spouseId 应为 null（期望行为）', () {
      final controller = _makeController();

      // 为 root（A）添加配偶 B
      controller.addSpouse('root', '配偶B', '配偶', '备注', '女');

      final personA = controller.getPerson('root')!;
      final spouseId = personA.spouseId;
      expect(spouseId, isNotNull, reason: '前置条件：A 应有配偶 B');

      // 删除 B
      controller.deletePerson(spouseId!);

      // 期望行为：A.spouseId 应为 null
      final personAAfterDelete = controller.getPerson('root')!;
      expect(
        personAAfterDelete.spouseId,
        isNull,
        reason:
            'Bug 1：删除 B 后，A.spouseId 应被清除为 null，但未修复代码中仍为 ${personAAfterDelete.spouseId}',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 2 探索：generationColor(-2) 与 generationColor(-1) 应返回不同颜色
  //
  // 期望行为：五代人各有不同颜色，-2 和 -1 颜色不同
  // 未修复代码上（按设计文档描述）：两者颜色相同，测试 FAIL
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 2 探索：五代颜色应显著区分', () {
    test('generationColor(-2) 与 generationColor(-1) 应返回不同颜色（期望行为）', () {
      final colorMinus2 = GalaxyLayoutEngine.generationColor(-2);
      final colorMinus1 = GalaxyLayoutEngine.generationColor(-1);

      expect(
        colorMinus2,
        isNot(equals(colorMinus1)),
        reason:
            'Bug 2：曾祖辈(generation=-2)与祖辈(generation=-1)应有不同颜色，'
            '但当前 colorMinus2=$colorMinus2, colorMinus1=$colorMinus1',
      );
    });

    test('generationColor(1) 与 generationColor(2) 应返回不同颜色（期望行为）', () {
      final color1 = GalaxyLayoutEngine.generationColor(1);
      final color2 = GalaxyLayoutEngine.generationColor(2);

      expect(
        color1,
        isNot(equals(color2)),
        reason:
            'Bug 2：子辈(generation=1)与孙辈(generation=2)应有不同颜色，'
            '但当前 color1=$color1, color2=$color2',
      );
    });

    test('五代颜色（≤-2, -1, 0, 1, ≥2）应各不相同（期望行为）', () {
      final colorAncestor2 = GalaxyLayoutEngine.generationColor(-2);
      final colorAncestor1 = GalaxyLayoutEngine.generationColor(-1);
      final colorSelf = GalaxyLayoutEngine.generationColor(0);
      final colorChild1 = GalaxyLayoutEngine.generationColor(1);
      final colorChild2 = GalaxyLayoutEngine.generationColor(2);

      final colors = [
        colorAncestor2,
        colorAncestor1,
        colorSelf,
        colorChild1,
        colorChild2,
      ];
      final uniqueColors = colors.toSet();

      expect(
        uniqueColors.length,
        equals(5),
        reason:
            'Bug 2：五代人应各有不同颜色，但当前只有 ${uniqueColors.length} 种不同颜色：$uniqueColors',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 3 探索：DfsExtractor 导出应包含叔伯（父母的兄弟姐妹）
  //
  // 家谱结构：中心人 → 父亲 → 祖父 → 叔叔
  // 期望行为：叔叔 ID 在导出集合中
  // 未修复代码上：叔叔不在导出集合中（路径长度=3，超出 maxGenerations=2），测试 FAIL
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 3 探索：导出应包含叔伯（父母的兄弟姐妹）', () {
    test('以中心人为起点导出，叔叔 ID 应在导出集合中（期望行为）', () {
      // 构造家谱：
      //   祖父(grandpa) → 父亲(father) → 中心人(center)
      //   祖父(grandpa) → 叔叔(uncle)
      const centerId = 'center';
      const fatherId = 'father';
      const grandpaId = 'grandpa';
      const uncleId = 'uncle';

      final people = <String, Person>{
        centerId: Person(
          id: centerId,
          name: '中心人',
          relationship: '本人',
          gender: '男',
          bio: '',
          parents: [fatherId],
          children: [],
        ),
        fatherId: Person(
          id: fatherId,
          name: '父亲',
          relationship: '父亲',
          gender: '男',
          bio: '',
          parents: [grandpaId],
          children: [centerId],
        ),
        grandpaId: Person(
          id: grandpaId,
          name: '祖父',
          relationship: '祖父',
          gender: '男',
          bio: '',
          parents: [],
          children: [fatherId, uncleId],
        ),
        uncleId: Person(
          id: uncleId,
          name: '叔叔',
          relationship: '叔叔',
          gender: '男',
          bio: '',
          parents: [grandpaId],
          children: [],
        ),
      };

      final exported = DfsExtractor.extract(
        people: people,
        centerId: centerId,
        maxGenerations: 2,
      );

      expect(
        exported,
        contains(uncleId),
        reason:
            'Bug 3：叔叔（父亲的兄弟）应被包含在导出集合中，'
            '但当前导出集合为：$exported',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 4 探索：addSpouse 后，calculateGenerations 应包含配偶节点
  //
  // 期望行为：
  //   1. addSpouse 后，root.spouseId 不为 null
  //   2. calculateGenerations 返回的代际 Map 中包含配偶节点
  //
  // 未修复代码上：calculateGenerations 使用 person.spouse 而非 spouseId，
  //   配偶节点不参与遍历，不出现在代际 Map 中，测试 FAIL
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 4 探索：addSpouse 后配偶节点应出现在 calculateGenerations 中', () {
    test('为 root 添加配偶后，root.spouseId 不为 null（前置条件）', () {
      final controller = _makeController();

      controller.addSpouse('root', '配偶', '配偶', '备注', '女');

      final root = controller.getPerson('root')!;
      expect(
        root.spouseId,
        isNotNull,
        reason: '前置条件：addSpouse 后 root.spouseId 应不为 null',
      );
    });

    test('为 root 添加配偶后，calculateGenerations 应包含配偶节点（期望行为）', () {
      final controller = _makeController();

      controller.addSpouse('root', '配偶', '配偶', '备注', '女');

      final root = controller.getPerson('root')!;
      final spouseId = root.spouseId;
      expect(
        spouseId,
        isNotNull,
        reason: '前置条件：addSpouse 后 root.spouseId 应不为 null',
      );

      final generations = controller.calculateGenerations();

      // 收集所有代际 Map 中的人员 ID
      final allPersonIds = generations.values
          .expand((people) => people)
          .map((p) => p.id)
          .toSet();

      expect(
        allPersonIds,
        contains(spouseId),
        reason:
            'Bug 4：calculateGenerations 应包含配偶节点 $spouseId，'
            '但当前代际 Map 中的人员为：$allPersonIds',
      );
    });
  });
}
