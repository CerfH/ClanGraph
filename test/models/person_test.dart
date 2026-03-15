// Feature: smart-export-and-spouse-relation
// Property 8: Person 序列化往返
// 验证需求：6.4

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:clangraph/models/person.dart';

/// 随机字符串生成器
String _randomString(Random rng, {int maxLen = 10}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final len = rng.nextInt(maxLen) + 1;
  return List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// 随机 Person 生成器（含任意 spouseId，包括 null）
Person _randomPerson(Random rng, {String? id}) {
  final personId = id ?? _randomString(rng);
  // spouseId 有 1/3 概率为 null，2/3 概率为随机字符串
  final spouseId = rng.nextInt(3) == 0 ? null : _randomString(rng);
  final spouse = rng.nextInt(3) == 0 ? null : _randomString(rng);

  final parentCount = rng.nextInt(3);
  final childCount = rng.nextInt(4);

  return Person(
    id: personId,
    name: _randomString(rng),
    relationship: _randomString(rng),
    gender: rng.nextBool() ? '男' : '女',
    bio: _randomString(rng, maxLen: 20),
    parents: List.generate(parentCount, (_) => _randomString(rng)),
    children: List.generate(childCount, (_) => _randomString(rng)),
    spouse: spouse,
    spouseId: spouseId,
    giftHistory: const [],
  );
}

void main() {
  group('Person 模型单元测试', () {
    test('spouseId 字段存在且默认为 null', () {
      final p = Person(
        id: '1',
        name: '张三',
        relationship: '本人',
        gender: '男',
        bio: '',
      );
      expect(p.spouseId, isNull);
    });

    test('toMap 包含 spouseId 键', () {
      final p = Person(
        id: '1',
        name: '张三',
        relationship: '本人',
        gender: '男',
        bio: '',
        spouseId: 'spouse-001',
      );
      final map = p.toMap();
      expect(map.containsKey('spouseId'), isTrue);
      expect(map['spouseId'], equals('spouse-001'));
    });

    test('toMap 中 spouseId 为 null 时键值为 null', () {
      final p = Person(
        id: '1',
        name: '张三',
        relationship: '本人',
        gender: '男',
        bio: '',
        spouseId: null,
      );
      final map = p.toMap();
      expect(map.containsKey('spouseId'), isTrue);
      expect(map['spouseId'], isNull);
    });

    test('fromMap 正确读取 spouseId', () {
      final map = {
        'id': '1',
        'name': '张三',
        'relationship': '本人',
        'gender': '男',
        'bio': '',
        'spouseId': 'spouse-001',
      };
      final p = Person.fromMap(map);
      expect(p.spouseId, equals('spouse-001'));
    });

    test('fromMap 中 spouseId 键不存在时赋 null', () {
      final map = {
        'id': '1',
        'name': '张三',
        'relationship': '本人',
        'gender': '男',
        'bio': '',
        // 无 spouseId 键（旧格式数据）
      };
      final p = Person.fromMap(map);
      expect(p.spouseId, isNull);
    });

    test('fromMap 中 spouseId 为空字符串时赋 null', () {
      final map = {
        'id': '1',
        'name': '张三',
        'relationship': '本人',
        'gender': '男',
        'bio': '',
        'spouseId': '',
      };
      final p = Person.fromMap(map);
      expect(p.spouseId, isNull);
    });

    test('旧格式数据（无 spouseId 键）加载后 spouse 字段正常读取', () {
      final map = {
        'id': '1',
        'name': '张三',
        'relationship': '本人',
        'gender': '男',
        'bio': '',
        'spouse': 'old-spouse-id',
        // 无 spouseId 键
      };
      final p = Person.fromMap(map);
      expect(p.spouse, equals('old-spouse-id'));
      expect(p.spouseId, isNull);
    });

    test('序列化往返：非空 spouseId 保持不变', () {
      final p = Person(
        id: '1',
        name: '张三',
        relationship: '本人',
        gender: '男',
        bio: '',
        spouseId: 'spouse-001',
      );
      final roundTripped = Person.fromMap(p.toMap());
      expect(roundTripped.spouseId, equals(p.spouseId));
    });

    test('序列化往返：null spouseId 保持 null', () {
      final p = Person(
        id: '1',
        name: '张三',
        relationship: '本人',
        gender: '男',
        bio: '',
        spouseId: null,
      );
      final roundTripped = Person.fromMap(p.toMap());
      expect(roundTripped.spouseId, isNull);
    });
  });

  group('属性 8：Person 序列化往返（属性测试）', () {
    // **Validates: Requirements 6.4**
    test('对任意 Person 对象，fromMap(toMap()) 后 spouseId 等于原始值', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final original = _randomPerson(rng);
        final roundTripped = Person.fromMap(original.toMap());

        expect(
          roundTripped.spouseId,
          equals(original.spouseId),
          reason:
              '第 $i 次迭代失败：原始 spouseId=${original.spouseId}，往返后=${roundTripped.spouseId}',
        );
      }
    });

    test('对任意 Person 对象，fromMap(toMap()) 后所有字段均与原始对象等价', () {
      final rng = Random(123);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final original = _randomPerson(rng);
        final roundTripped = Person.fromMap(original.toMap());

        expect(roundTripped.id, equals(original.id), reason: '第 $i 次迭代 id 不匹配');
        expect(
          roundTripped.name,
          equals(original.name),
          reason: '第 $i 次迭代 name 不匹配',
        );
        expect(
          roundTripped.relationship,
          equals(original.relationship),
          reason: '第 $i 次迭代 relationship 不匹配',
        );
        expect(
          roundTripped.gender,
          equals(original.gender),
          reason: '第 $i 次迭代 gender 不匹配',
        );
        expect(
          roundTripped.bio,
          equals(original.bio),
          reason: '第 $i 次迭代 bio 不匹配',
        );
        expect(
          roundTripped.parents,
          equals(original.parents),
          reason: '第 $i 次迭代 parents 不匹配',
        );
        expect(
          roundTripped.children,
          equals(original.children),
          reason: '第 $i 次迭代 children 不匹配',
        );
        expect(
          roundTripped.spouse,
          equals(original.spouse),
          reason: '第 $i 次迭代 spouse 不匹配',
        );
        expect(
          roundTripped.spouseId,
          equals(original.spouseId),
          reason: '第 $i 次迭代 spouseId 不匹配',
        );
      }
    });

    test('旧格式数据（无 spouseId 键）加载后 spouseId 为 null（向后兼容）', () {
      final rng = Random(999);
      const iterations = 50;

      for (var i = 0; i < iterations; i++) {
        // 构造不含 spouseId 键的旧格式 map
        final map = <String, dynamic>{
          'id': _randomString(rng),
          'name': _randomString(rng),
          'relationship': _randomString(rng),
          'gender': rng.nextBool() ? '男' : '女',
          'bio': _randomString(rng),
          'parents': <String>[],
          'children': <String>[],
          'spouse': rng.nextInt(3) == 0 ? null : _randomString(rng),
          'giftHistory': <dynamic>[],
          // 故意不包含 spouseId 键
        };

        final p = Person.fromMap(map);
        expect(
          p.spouseId,
          isNull,
          reason: '第 $i 次迭代：旧格式数据加载后 spouseId 应为 null',
        );
      }
    });
  });
}
