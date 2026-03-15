// Feature: smart-export-and-spouse-relation
// Property 9: 配偶互指不变量
// Property 10: 子女继承属性
// 验证需求：8.1, 8.2, 8.3, 8.4, 8.6

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clangraph/controllers/family_controller.dart';
import 'package:clangraph/models/person.dart';

/// 随机字符串生成器
String _randomString(Random rng, {int maxLen = 8}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final len = rng.nextInt(maxLen) + 1;
  return List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// 随机性别
String _randomGender(Random rng) => rng.nextBool() ? '男' : '女';

/// 创建一个带有预置数据的 FamilyController（绕过 SharedPreferences 异步加载）
///
/// 直接操作内部 _people map 是不可行的（私有字段），
/// 所以我们通过公开 API 构建测试状态。
FamilyController _makeController() {
  SharedPreferences.setMockInitialValues({});
  return FamilyController();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 边界用例：无子女时添加配偶
  // ─────────────────────────────────────────────────────────────────────────
  group('边界用例：无子女时添加配偶', () {
    test('为无子女的 root 添加配偶，互指正确，子女列表为空', () {
      final controller = _makeController();

      // root 初始无子女
      expect(controller.centerPerson!.children, isEmpty);

      controller.addSpouse('root', '配偶', '配偶', '备注', '女');

      final personA = controller.getPerson('root')!;
      final spouseId = personA.spouseId;
      expect(spouseId, isNotNull, reason: 'A 的 spouseId 应指向 B');

      final personB = controller.getPerson(spouseId!)!;
      expect(personB.spouseId, equals('root'), reason: 'B 的 spouseId 应指向 A');
      expect(personB.children, isEmpty, reason: 'A 无子女，B 的 children 应为空');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 边界用例：替换已有配偶
  // ─────────────────────────────────────────────────────────────────────────
  group('边界用例：替换已有配偶', () {
    test('为已有配偶的 root 再次调用 addSpouse，新配偶互指正确', () async {
      final controller = _makeController();

      // 第一次添加配偶
      controller.addSpouse('root', '配偶一', '配偶', '备注', '女');
      final firstSpouseId = controller.getPerson('root')!.spouseId;
      expect(firstSpouseId, isNotNull);

      // 等待 2ms 确保时间戳 ID 不同
      await Future.delayed(const Duration(milliseconds: 2));

      // 第二次添加配偶（替换）
      controller.addSpouse('root', '配偶二', '配偶', '备注', '女');

      final personA = controller.getPerson('root')!;
      final newSpouseId = personA.spouseId;
      expect(newSpouseId, isNotNull, reason: '替换后 A 的 spouseId 应指向新配偶');

      final personB = controller.getPerson(newSpouseId!)!;
      expect(personB.spouseId, equals('root'), reason: '新配偶 B 的 spouseId 应指向 A');
      expect(personB.name, equals('配偶二'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 属性 9：配偶互指不变量（100 次迭代）
  // **Validates: Requirements 8.1, 8.3**
  // ─────────────────────────────────────────────────────────────────────────
  group('属性 9：配偶互指不变量', () {
    test('对任意 addSpouse 调用，A.spouseId == B.id 且 B.spouseId == A.id', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        SharedPreferences.setMockInitialValues({});
        final controller = _makeController();

        final spouseName = _randomString(rng);
        final spouseRelationship = _randomString(rng);
        final spouseBio = _randomString(rng);
        final spouseGender = _randomGender(rng);

        controller.addSpouse(
          'root',
          spouseName,
          spouseRelationship,
          spouseBio,
          spouseGender,
        );

        final personA = controller.getPerson('root')!;
        final spouseId = personA.spouseId;

        expect(spouseId, isNotNull, reason: '第 $i 次迭代：A.spouseId 不应为 null');

        final personB = controller.getPerson(spouseId!)!;

        // 属性 9 核心断言：互指
        expect(
          personA.spouseId,
          equals(personB.id),
          reason: '第 $i 次迭代：A.spouseId 应等于 B.id',
        );
        expect(
          personB.spouseId,
          equals(personA.id),
          reason: '第 $i 次迭代：B.spouseId 应等于 A.id',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 属性 10：子女继承属性（100 次迭代）
  // **Validates: Requirements 8.2, 8.4**
  // ─────────────────────────────────────────────────────────────────────────
  group('属性 10：子女继承属性', () {
    test('addSpouse 后，A 的每个子女 parents 含 B.id，且 B.children 含子女 id', () {
      final rng = Random(99);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        SharedPreferences.setMockInitialValues({});
        final controller = _makeController();

        // 先为 root 添加 0~3 个子女
        final childCount = rng.nextInt(4); // 0, 1, 2, 3
        final childIds = <String>[];

        for (var c = 0; c < childCount; c++) {
          controller.addChild(
            'root',
            _randomString(rng),
            _randomString(rng),
            _randomString(rng),
            _randomGender(rng),
          );
        }

        // 收集子女 ID
        final personABefore = controller.getPerson('root')!;
        childIds.addAll(personABefore.children);

        // 添加配偶
        controller.addSpouse(
          'root',
          _randomString(rng),
          _randomString(rng),
          _randomString(rng),
          _randomGender(rng),
        );

        final personA = controller.getPerson('root')!;
        final spouseId = personA.spouseId!;
        final personB = controller.getPerson(spouseId)!;

        // 属性 10 核心断言
        for (final childId in childIds) {
          final child = controller.getPerson(childId)!;
          expect(
            child.parents,
            contains(spouseId),
            reason: '第 $i 次迭代：子女 $childId 的 parents 应包含 B.id=$spouseId',
          );
          expect(
            personB.children,
            contains(childId),
            reason: '第 $i 次迭代：B.children 应包含子女 id=$childId',
          );
        }

        // 若无子女，B.children 应为空
        if (childIds.isEmpty) {
          expect(
            personB.children,
            isEmpty,
            reason: '第 $i 次迭代：A 无子女时 B.children 应为空',
          );
        }
      }
    });
  });
}
