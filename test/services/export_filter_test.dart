// Feature: smart-export-and-spouse-relation
// Property 4: ExportFilter 字段清洗正确性
// Property 5: ExportFilter 输出合法 JSON
// Property 6: ExportFilter 幂等性
// Property 7: ExportFilter 范围隔离
// 验证需求：5.1, 5.2, 5.3, 5.4

import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:clangraph/models/export_config.dart';
import 'package:clangraph/models/person.dart';
import 'package:clangraph/services/dfs_extractor.dart';
import 'package:clangraph/services/export_filter.dart';

// ─── 辅助工具 ────────────────────────────────────────────────────────────────

String _uid(int n) => 'p$n';

Person _person(
  String id, {
  String name = '',
  String relationship = '',
  String gender = '男',
  String bio = '',
  List<String> parents = const [],
  List<String> children = const [],
  String? spouseId,
  List<GiftRecord> giftHistory = const [],
}) => Person(
  id: id,
  name: name,
  relationship: relationship,
  gender: gender,
  bio: bio,
  parents: parents,
  children: children,
  spouseId: spouseId,
  giftHistory: giftHistory,
);

/// 生成随机 ExportConfig（随机勾选维度组合）
ExportConfig _randomConfig(Random rng, String centerId) {
  final allDims = ExportDimension.values;
  final enabled = <ExportDimension>{};
  for (final dim in allDims) {
    if (rng.nextBool()) enabled.add(dim);
  }
  return ExportConfig(enabledDimensions: enabled, centerId: centerId);
}

/// 生成随机 Person（含随机字段值）
Person _randomPerson(Random rng, String id) {
  final giftCount = rng.nextInt(3);
  final gifts = List.generate(giftCount, (i) {
    return GiftRecord(
      id: 'g${id}_$i',
      amount: rng.nextDouble() * 1000,
      event: '事件$i',
      date: DateTime(
        2020 + rng.nextInt(5),
        rng.nextInt(12) + 1,
        rng.nextInt(28) + 1,
      ),
    );
  });
  return _person(
    id,
    name: '姓名$id',
    relationship: '关系$id',
    gender: rng.nextBool() ? '男' : '女',
    bio: '备注$id',
    giftHistory: gifts,
  );
}

/// 生成线性家谱（链式父子关系）
Map<String, Person> _buildLinearFamily(Random rng, int size) {
  if (size <= 0) return {};
  final ids = List.generate(size, (i) => _uid(i));
  final people = <String, Person>{};
  for (var i = 0; i < size; i++) {
    final parents = i > 0 ? [ids[i - 1]] : <String>[];
    final children = i < size - 1 ? [ids[i + 1]] : <String>[];
    people[ids[i]] = _randomPerson(
      rng,
      ids[i],
    ).copyWithRelations(parents: parents, children: children);
  }
  return people;
}

extension _PersonCopy on Person {
  Person copyWithRelations({
    List<String>? parents,
    List<String>? children,
    String? spouseId,
  }) => Person(
    id: id,
    name: name,
    relationship: relationship,
    gender: gender,
    bio: bio,
    parents: parents ?? this.parents,
    children: children ?? this.children,
    spouseId: spouseId ?? this.spouseId,
    giftHistory: giftHistory,
  );
}

// ─── 边界用例 ────────────────────────────────────────────────────────────────

void main() {
  group('ExportFilter 边界用例', () {
    test('空集合返回 {"members":[]}', () {
      final config = ExportConfig(
        enabledDimensions: ExportDimension.values.toSet(),
        centerId: 'c0',
      );
      final result = ExportFilter.filter(people: [], config: config);
      expect(result, equals('{"members":[]}'));
    });

    test('所有维度勾选时，字段值与原始数据一致', () {
      final gift = GiftRecord(
        id: 'g1',
        amount: 100.0,
        event: '婚礼',
        date: DateTime(2023, 1, 1),
      );
      final p = _person(
        'p1',
        name: '张三',
        relationship: '父亲',
        gender: '男',
        bio: '备注',
        parents: ['p0'],
        children: ['p2'],
        spouseId: 'sp1',
        giftHistory: [gift],
      );
      final config = ExportConfig(
        enabledDimensions: ExportDimension.values.toSet(),
        centerId: 'p1',
      );
      final result = ExportFilter.filter(people: [p], config: config);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final member = (decoded['members'] as List).first as Map<String, dynamic>;

      expect(member['name'], equals('张三'));
      expect(member['relationship'], equals('父亲'));
      expect(member['gender'], equals('男'));
      expect(member['bio'], equals('备注'));
      expect(member['parents'], equals(['p0']));
      expect(member['children'], equals(['p2']));
      expect(member['spouseId'], equals('sp1'));
      expect((member['giftHistory'] as List).length, equals(1));
    });

    test('所有维度不勾选时，id 保留，其余字段为空值', () {
      final p = _person(
        'p1',
        name: '张三',
        relationship: '父亲',
        gender: '男',
        bio: '备注',
        parents: ['p0'],
        children: ['p2'],
        spouseId: 'sp1',
      );
      final config = ExportConfig(enabledDimensions: const {}, centerId: 'p1');
      final result = ExportFilter.filter(people: [p], config: config);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final member = (decoded['members'] as List).first as Map<String, dynamic>;

      expect(member['id'], equals('p1')); // id 始终保留
      expect(member['name'], equals(''));
      expect(member['relationship'], equals(''));
      expect(member['gender'], equals(''));
      expect(member['bio'], equals(''));
      expect(member['parents'], equals([]));
      expect(member['children'], equals([]));
      expect(member['spouseId'], isNull);
      expect(member['giftHistory'], equals([]));
    });
  });

  // ─── 属性 4：ExportFilter 字段清洗正确性 ─────────────────────────────────

  group('属性 4：ExportFilter 字段清洗正确性', () {
    // **Validates: Requirements 2.2, 2.3, 5.2**
    test('未勾选维度字段为空值，已勾选维度字段与原始数据一致', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final size = rng.nextInt(5) + 1;
        final people = List.generate(
          size,
          (j) => _randomPerson(rng, _uid(i * 10 + j)),
        );
        final config = _randomConfig(rng, people.first.id);
        final dims = config.enabledDimensions;

        final result = ExportFilter.filter(people: people, config: config);
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final members = decoded['members'] as List;

        expect(
          members.length,
          equals(people.length),
          reason: '第 $i 次迭代：members 数量应与输入一致',
        );

        for (var k = 0; k < people.length; k++) {
          final original = people[k];
          final member = members[k] as Map<String, dynamic>;

          // id 始终保留
          expect(
            member['id'],
            equals(original.id),
            reason: '第 $i 次迭代：id 应始终保留',
          );

          // basicInfo 维度
          if (dims.contains(ExportDimension.basicInfo)) {
            expect(
              member['name'],
              equals(original.name),
              reason: '第 $i 次迭代：basicInfo 勾选时 name 应保留',
            );
            expect(
              member['relationship'],
              equals(original.relationship),
              reason: '第 $i 次迭代：basicInfo 勾选时 relationship 应保留',
            );
            expect(
              member['gender'],
              equals(original.gender),
              reason: '第 $i 次迭代：basicInfo 勾选时 gender 应保留',
            );
          } else {
            expect(
              member['name'],
              equals(''),
              reason: '第 $i 次迭代：basicInfo 未勾选时 name 应为空',
            );
            expect(
              member['relationship'],
              equals(''),
              reason: '第 $i 次迭代：basicInfo 未勾选时 relationship 应为空',
            );
            expect(
              member['gender'],
              equals(''),
              reason: '第 $i 次迭代：basicInfo 未勾选时 gender 应为空',
            );
          }

          // giftHistory 维度
          if (dims.contains(ExportDimension.giftHistory)) {
            expect(
              (member['giftHistory'] as List).length,
              equals(original.giftHistory.length),
              reason: '第 $i 次迭代：giftHistory 勾选时应保留礼金记录',
            );
          } else {
            expect(
              member['giftHistory'],
              equals([]),
              reason: '第 $i 次迭代：giftHistory 未勾选时应为空列表',
            );
          }

          // relations 维度
          if (dims.contains(ExportDimension.relations)) {
            expect(
              member['parents'],
              equals(original.parents),
              reason: '第 $i 次迭代：relations 勾选时 parents 应保留',
            );
            expect(
              member['children'],
              equals(original.children),
              reason: '第 $i 次迭代：relations 勾选时 children 应保留',
            );
            expect(
              member['spouseId'],
              equals(original.spouseId),
              reason: '第 $i 次迭代：relations 勾选时 spouseId 应保留',
            );
          } else {
            expect(
              member['parents'],
              equals([]),
              reason: '第 $i 次迭代：relations 未勾选时 parents 应为空列表',
            );
            expect(
              member['children'],
              equals([]),
              reason: '第 $i 次迭代：relations 未勾选时 children 应为空列表',
            );
            expect(
              member['spouseId'],
              isNull,
              reason: '第 $i 次迭代：relations 未勾选时 spouseId 应为 null',
            );
          }

          // bio 维度
          if (dims.contains(ExportDimension.bio)) {
            expect(
              member['bio'],
              equals(original.bio),
              reason: '第 $i 次迭代：bio 勾选时应保留',
            );
          } else {
            expect(
              member['bio'],
              equals(''),
              reason: '第 $i 次迭代：bio 未勾选时应为空字符串',
            );
          }
        }
      }
    });
  });

  // ─── 属性 5：ExportFilter 输出合法 JSON ───────────────────────────────────

  group('属性 5：ExportFilter 输出合法 JSON', () {
    // **Validates: Requirements 2.5, 5.3**
    test('对任意 ExportConfig 组合，输出均可被 json.decode 解析且含 members 数组', () {
      final rng = Random(7);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final size = rng.nextInt(5) + 1;
        final people = List.generate(
          size,
          (j) => _randomPerson(rng, _uid(i * 10 + j)),
        );
        final config = _randomConfig(rng, people.first.id);

        final result = ExportFilter.filter(people: people, config: config);

        // 验证可被 json.decode 解析
        dynamic decoded;
        expect(
          () {
            decoded = jsonDecode(result);
          },
          returnsNormally,
          reason: '第 $i 次迭代：输出应为合法 JSON',
        );

        // 验证顶层结构含 members 数组
        expect(
          decoded,
          isA<Map<String, dynamic>>(),
          reason: '第 $i 次迭代：顶层应为 Map',
        );
        expect(
          (decoded as Map<String, dynamic>).containsKey('members'),
          isTrue,
          reason: '第 $i 次迭代：顶层应含 members 键',
        );
        expect(
          decoded['members'],
          isA<List>(),
          reason: '第 $i 次迭代：members 应为数组',
        );
      }
    });
  });

  // ─── 属性 6：ExportFilter 幂等性 ─────────────────────────────────────────

  group('属性 6：ExportFilter 幂等性', () {
    // **Validates: Requirements 5.4**
    test('对同一 Person 集合执行两次 filter，结果完全相同', () {
      final rng = Random(13);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final size = rng.nextInt(5) + 1;
        final people = List.generate(
          size,
          (j) => _randomPerson(rng, _uid(i * 10 + j)),
        );
        final config = _randomConfig(rng, people.first.id);

        final result1 = ExportFilter.filter(people: people, config: config);
        final result2 = ExportFilter.filter(people: people, config: config);

        expect(result1, equals(result2), reason: '第 $i 次迭代：两次 filter 结果应完全相同');
      }
    });
  });

  // ─── 属性 7：ExportFilter 范围隔离 ───────────────────────────────────────

  group('属性 7：ExportFilter 范围隔离', () {
    // **Validates: Requirements 5.1**
    test('DfsExtractor 提取后过滤，输出 members 中不含提取范围外的 Person', () {
      final rng = Random(99);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final size = rng.nextInt(8) + 3;
        final allPeople = _buildLinearFamily(rng, size);
        if (allPeople.isEmpty) continue;

        final ids = allPeople.keys.toList();
        final centerId = ids[rng.nextInt(ids.length)];
        final config = _randomConfig(rng, centerId);

        // DFS 提取范围
        final extractedIds = DfsExtractor.extract(
          people: allPeople,
          centerId: centerId,
        );

        // 仅对提取范围内的 Person 执行过滤
        final extractedPeople = extractedIds
            .map((id) => allPeople[id])
            .whereType<Person>()
            .toList();

        final result = ExportFilter.filter(
          people: extractedPeople,
          config: config,
        );
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        final members = decoded['members'] as List;

        // 验证输出中的每个 member 的 id 都在提取范围内
        for (final member in members) {
          final memberId = (member as Map<String, dynamic>)['id'] as String;
          expect(
            extractedIds,
            contains(memberId),
            reason: '第 $i 次迭代：member $memberId 不在 DFS 提取范围内',
          );
        }

        // 验证提取范围外的 Person 不在输出中
        final outputIds = members
            .map((m) => (m as Map<String, dynamic>)['id'] as String)
            .toSet();
        final outsideIds = allPeople.keys.toSet().difference(extractedIds);
        for (final outsideId in outsideIds) {
          expect(
            outputIds,
            isNot(contains(outsideId)),
            reason: '第 $i 次迭代：范围外的 $outsideId 不应出现在输出中',
          );
        }
      }
    });
  });
}
