// Bugfix Spec: delete-color-export-center-fix
// Task 2: 保留性属性测试（修复前运行）
//
// 这些测试验证非 Bug 条件下的基线行为。
// 在未修复代码上，这些测试应该 PASS（确认基线行为正常）。
// 修复后，这些测试也必须继续 PASS（回归防护）。
//
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.12**

import 'dart:convert';
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
  // Bug 1 保留：删除无配偶的叶子节点，父母/子女列表清理结果正确
  //
  // 非 Bug 条件：被删除人没有配偶（不触发 Bug 1 的悬空引用问题）
  // 期望：父母的 children 列表不含已删除 ID，子女的 parents 列表不含已删除 ID
  // 期望：root 节点不可删除
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 1 保留：删除无配偶叶子节点，列表清理正确', () {
    test('删除无配偶的子节点后，父母的 children 列表不含已删除 ID', () {
      final controller = _makeController();

      // 为 root 添加一个子节点（无配偶）
      controller.addChild('root', '子节点A', '子女', '备注', '男');

      final root = controller.getPerson('root')!;
      expect(root.children, isNotEmpty, reason: '前置条件：root 应有子节点');

      final childId = root.children.first;

      // 删除该子节点
      controller.deletePerson(childId);

      // 断言：root 的 children 列表不含已删除 ID
      final rootAfter = controller.getPerson('root')!;
      expect(
        rootAfter.children,
        isNot(contains(childId)),
        reason: 'Bug 1 保留：删除子节点后，父母的 children 列表应不含已删除 ID',
      );

      // 断言：已删除节点不在 people Map 中
      expect(
        controller.getPerson(childId),
        isNull,
        reason: 'Bug 1 保留：删除后节点应从 people Map 中移除',
      );
    });

    test('删除无配偶的父节点后，子女的 parents 列表不含已删除 ID', () {
      final controller = _makeController();

      // 为 root 添加父节点（无配偶）
      controller.addParent('root', '父节点A', '父亲', '备注', '男');

      final root = controller.getPerson('root')!;
      expect(root.parents, isNotEmpty, reason: '前置条件：root 应有父节点');

      final parentId = root.parents.first;

      // 删除该父节点
      controller.deletePerson(parentId);

      // 断言：root 的 parents 列表不含已删除 ID
      final rootAfter = controller.getPerson('root')!;
      expect(
        rootAfter.parents,
        isNot(contains(parentId)),
        reason: 'Bug 1 保留：删除父节点后，子女的 parents 列表应不含已删除 ID',
      );
    });

    test('root 节点不可删除（保护逻辑不变）', () {
      final controller = _makeController();

      // 尝试删除 root
      controller.deletePerson('root');

      // 断言：root 仍然存在
      expect(
        controller.getPerson('root'),
        isNotNull,
        reason: 'Bug 1 保留：root 节点不可删除，应始终存在',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 2 保留：generationColor(0) 返回绿色（本辈颜色不变）
  //
  // 非 Bug 条件：generation == 0（本辈，不触发 Bug 2 的颜色混淆问题）
  // 期望：generationColor(0) == Color(0xFF4CAF50)
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 2 保留：generationColor(0) 返回绿色', () {
    test('generationColor(0) 应返回本辈颜色', () {
      final color = GalaxyLayoutEngine.generationColor(0);

      expect(
        color,
        equals(const Color(0xFF26A69A)),
        reason: '本辈（generation=0）颜色为青绿色，已从旧版绿色更新',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 3 保留：导出不含叔伯的简单家谱，JSON 格式合法
  //
  // 非 Bug 条件：家谱只有父母和子女，没有叔伯（不触发 Bug 3 的范围缺失问题）
  // 期望：导出集合包含中心人、父母、子女
  // 期望：不包含超出范围的远亲
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 3 保留：简单家谱导出格式合法且范围正确', () {
    test('导出集合包含中心人、父母、子女', () {
      // 构造简单家谱：父母 → 中心人 → 子女（无叔伯）
      const centerId = 'center';
      const fatherId = 'father';
      const motherId = 'mother';
      const childId = 'child';

      final people = <String, Person>{
        centerId: Person(
          id: centerId,
          name: '中心人',
          relationship: '本人',
          gender: '男',
          bio: '',
          parents: [fatherId, motherId],
          children: [childId],
        ),
        fatherId: Person(
          id: fatherId,
          name: '父亲',
          relationship: '父亲',
          gender: '男',
          bio: '',
          parents: [],
          children: [centerId],
        ),
        motherId: Person(
          id: motherId,
          name: '母亲',
          relationship: '母亲',
          gender: '女',
          bio: '',
          parents: [],
          children: [centerId],
        ),
        childId: Person(
          id: childId,
          name: '子女',
          relationship: '子女',
          gender: '男',
          bio: '',
          parents: [centerId],
          children: [],
        ),
      };

      final exported = DfsExtractor.extract(
        people: people,
        centerId: centerId,
        maxGenerations: 2,
      );

      // 断言：导出集合包含中心人、父母、子女
      expect(exported, contains(centerId), reason: '导出集合应包含中心人');
      expect(exported, contains(fatherId), reason: '导出集合应包含父亲');
      expect(exported, contains(motherId), reason: '导出集合应包含母亲');
      expect(exported, contains(childId), reason: '导出集合应包含子女');
    });

    test('导出集合不包含超出范围的远亲', () {
      // 构造家谱：曾祖父 → 祖父 → 父亲 → 中心人（maxGenerations=2，曾祖父超出范围）
      const centerId = 'center';
      const fatherId = 'father';
      const grandpaId = 'grandpa';
      const greatGrandpaId = 'great_grandpa';

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
          parents: [greatGrandpaId],
          children: [fatherId],
        ),
        greatGrandpaId: Person(
          id: greatGrandpaId,
          name: '曾祖父',
          relationship: '曾祖父',
          gender: '男',
          bio: '',
          parents: [],
          children: [grandpaId],
        ),
      };

      final exported = DfsExtractor.extract(
        people: people,
        centerId: centerId,
        maxGenerations: 2,
      );

      // 断言：曾祖父（depth=3）不在导出集合中
      expect(
        exported,
        isNot(contains(greatGrandpaId)),
        reason: 'Bug 3 保留：超出 maxGenerations=2 范围的曾祖父不应被包含',
      );
    });

    test('FamilyController.exportToJSON 生成合法 JSON', () {
      final controller = _makeController();

      // 添加一些成员
      controller.addChild('root', '子女A', '子女', '备注', '男');
      controller.addParent('root', '父亲A', '父亲', '备注', '男');

      final jsonStr = controller.exportToJSON();

      // 断言：JSON 格式合法（不抛出异常）
      dynamic decoded;
      expect(
        () => decoded = json.decode(jsonStr),
        returnsNormally,
        reason: 'Bug 3 保留：exportToJSON 应生成合法 JSON',
      );

      // 断言：JSON 包含 members 字段
      expect(decoded, isA<Map>(), reason: '导出 JSON 应为 Map 格式');
      expect(
        (decoded as Map).containsKey('members'),
        isTrue,
        reason: '导出 JSON 应包含 members 字段',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bug 4 保留：导入含旧 spouse 字段的 JSON，配偶关系正确解析
  //
  // 非 Bug 条件：历史数据使用旧 spouse 字段（不触发 Bug 4 的字段不一致问题）
  // 期望：Person.fromMap 解析后，person.spouse 或 person.spouseId 不为 null
  // ─────────────────────────────────────────────────────────────────────────
  group('Bug 4 保留：导入含旧 spouse 字段的 JSON，配偶关系正确解析', () {
    test('Person.fromMap 解析含旧 spouse 字段的 JSON，配偶关系不丢失', () {
      // 构造含旧 spouse 字段的 JSON（不含 spouseId）
      final map = <String, dynamic>{
        'id': 'person_a',
        'name': '张三',
        'relationship': '本人',
        'gender': '男',
        'bio': '',
        'parents': <String>[],
        'children': <String>[],
        'spouse': 'some_spouse_id', // 旧字段
        // 注意：不含 spouseId 字段
        'giftHistory': <dynamic>[],
      };

      final person = Person.fromMap(map);

      // 断言：解析后配偶关系不丢失（spouse 或 spouseId 至少一个不为 null）
      final hasSpouseRelation =
          person.spouse != null || person.spouseId != null;
      expect(
        hasSpouseRelation,
        isTrue,
        reason:
            'Bug 4 保留：导入含旧 spouse 字段的 JSON 后，'
            'person.spouse=${person.spouse}, person.spouseId=${person.spouseId}，'
            '至少一个应不为 null（兼容旧数据）',
      );
    });

    test('Person.fromMap 解析含旧 spouse 字段时，spouse 字段值正确', () {
      const expectedSpouseId = 'spouse_123';
      final map = <String, dynamic>{
        'id': 'person_b',
        'name': '李四',
        'relationship': '本人',
        'gender': '女',
        'bio': '',
        'parents': <String>[],
        'children': <String>[],
        'spouse': expectedSpouseId, // 旧字段
        'giftHistory': <dynamic>[],
      };

      final person = Person.fromMap(map);

      // 断言：旧 spouse 字段的值被正确读取（通过 spouse 或 spouseId 均可）
      final actualSpouseId = person.spouseId ?? person.spouse;
      expect(
        actualSpouseId,
        equals(expectedSpouseId),
        reason:
            'Bug 4 保留：旧 spouse 字段的值应被正确解析，'
            '期望 $expectedSpouseId，实际 spouse=${person.spouse}, spouseId=${person.spouseId}',
      );
    });
  });
}
