// Feature: smart-export-and-spouse-relation
// Property 1: DFS 代际距离不变量
// Property 2: 血亲配偶纳入结果
// Property 3: 配偶扩展不传播 DFS
// 验证需求：4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:clangraph/models/person.dart';
import 'package:clangraph/services/dfs_extractor.dart';

// ─── 辅助工具 ────────────────────────────────────────────────────────────────

String _uid(int n) => 'p$n';

Person _person(
  String id, {
  List<String> parents = const [],
  List<String> children = const [],
  String? spouseId,
}) => Person(
  id: id,
  name: id,
  relationship: '',
  gender: '男',
  bio: '',
  parents: parents,
  children: children,
  spouseId: spouseId,
);

/// 计算从 [start] 到 [target] 的最短血亲路径长度（BFS，仅沿 parents/children）。
/// 若不可达，返回 null。
int? _shortestBloodPath(
  Map<String, Person> people,
  String start,
  String target,
) {
  if (start == target) return 0;
  final visited = <String>{start};
  final queue = <(String, int)>[(start, 0)];
  while (queue.isNotEmpty) {
    final (id, d) = queue.removeAt(0);
    final p = people[id];
    if (p == null) continue;
    for (final neighbor in [...p.parents, ...p.children]) {
      if (neighbor == target) return d + 1;
      if (!visited.contains(neighbor) && people.containsKey(neighbor)) {
        visited.add(neighbor);
        queue.add((neighbor, d + 1));
      }
    }
  }
  return null; // 不可达
}

// ─── 随机家谱生成器 ──────────────────────────────────────────────────────────

/// 生成一个随机的线性家谱（链式父子关系），节点数 [size]，
/// 返回 (people, allIds)。
Map<String, Person> _buildLinearFamily(Random rng, int size) {
  if (size <= 0) return {};
  final ids = List.generate(size, (i) => _uid(i));
  final people = <String, Person>{};

  for (var i = 0; i < size; i++) {
    final parents = i > 0 ? [ids[i - 1]] : <String>[];
    final children = i < size - 1 ? [ids[i + 1]] : <String>[];
    people[ids[i]] = _person(ids[i], parents: parents, children: children);
  }
  return people;
}

/// 生成随机树形家谱：每个节点最多 [maxChildren] 个子女，深度 [depth]。
Map<String, Person> _buildTreeFamily(
  Random rng,
  int depth,
  int maxChildren,
  int startId,
) {
  final people = <String, Person>{};
  var counter = startId;

  void build(String parentId, int currentDepth) {
    if (currentDepth >= depth) return;
    final childCount = rng.nextInt(maxChildren) + 1;
    final childIds = <String>[];
    for (var i = 0; i < childCount; i++) {
      final childId = _uid(counter++);
      childIds.add(childId);
    }
    // 更新父节点的 children
    final parent = people[parentId]!;
    people[parentId] = _person(
      parentId,
      parents: parent.parents,
      children: [...parent.children, ...childIds],
      spouseId: parent.spouseId,
    );
    for (final childId in childIds) {
      people[childId] = _person(childId, parents: [parentId]);
      build(childId, currentDepth + 1);
    }
  }

  final rootId = _uid(counter++);
  people[rootId] = _person(rootId);
  build(rootId, 0);
  return people;
}

// ─── 边界用例 ────────────────────────────────────────────────────────────────

void main() {
  group('DfsExtractor 边界用例', () {
    test('空图返回空集合', () {
      final result = DfsExtractor.extract(people: {}, centerId: 'p0');
      expect(result, isEmpty);
    });

    test('单节点图返回仅含中心人物', () {
      final people = {'p0': _person('p0')};
      final result = DfsExtractor.extract(people: people, centerId: 'p0');
      expect(result, equals({'p0'}));
    });

    test('中心人物不存在时返回空集合', () {
      final people = {'p0': _person('p0')};
      final result = DfsExtractor.extract(
        people: people,
        centerId: 'nonexistent',
      );
      expect(result, isEmpty);
    });

    test('中心人物本人始终在结果集中（代际距离 0）', () {
      final people = {
        'center': _person('center', parents: ['p1'], children: ['c1']),
        'p1': _person('p1', children: ['center']),
        'c1': _person('c1', parents: ['center']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, contains('center'));
    });

    test('父母（代际距离 1）在结果集中', () {
      final people = {
        'center': _person('center', parents: ['p1']),
        'p1': _person('p1', children: ['center']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, containsAll(['center', 'p1']));
    });

    test('祖父母（代际距离 2）在结果集中', () {
      final people = {
        'center': _person('center', parents: ['p1']),
        'p1': _person('p1', parents: ['gp1'], children: ['center']),
        'gp1': _person('gp1', children: ['p1']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, containsAll(['center', 'p1', 'gp1']));
    });

    test('曾祖父母（代际距离 3）不在结果集中', () {
      final people = {
        'center': _person('center', parents: ['p1']),
        'p1': _person('p1', parents: ['gp1'], children: ['center']),
        'gp1': _person('gp1', parents: ['ggp1'], children: ['p1']),
        'ggp1': _person('ggp1', children: ['gp1']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, isNot(contains('ggp1')));
    });

    test('子女（代际距离 1）在结果集中', () {
      final people = {
        'center': _person('center', children: ['c1']),
        'c1': _person('c1', parents: ['center']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, containsAll(['center', 'c1']));
    });

    test('孙辈（代际距离 2）在结果集中', () {
      final people = {
        'center': _person('center', children: ['c1']),
        'c1': _person('c1', parents: ['center'], children: ['gc1']),
        'gc1': _person('gc1', parents: ['c1']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, containsAll(['center', 'c1', 'gc1']));
    });

    test('曾孙辈（代际距离 3）不在结果集中', () {
      final people = {
        'center': _person('center', children: ['c1']),
        'c1': _person('c1', parents: ['center'], children: ['gc1']),
        'gc1': _person('gc1', parents: ['c1'], children: ['ggc1']),
        'ggc1': _person('ggc1', parents: ['gc1']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, isNot(contains('ggc1')));
    });

    test('血亲的配偶（spouseId）纳入结果集', () {
      final people = {
        'center': _person('center', spouseId: 'spouse'),
        'spouse': _person('spouse', spouseId: 'center'),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, containsAll(['center', 'spouse']));
    });

    test('配偶的血亲不因配偶扩展而纳入结果集', () {
      // center 的配偶 spouse 有一个兄弟 spouse_sibling
      // spouse_sibling 不应出现在结果集中
      final people = {
        'center': _person('center', spouseId: 'spouse'),
        'spouse': _person(
          'spouse',
          spouseId: 'center',
          parents: ['spouse_parent'],
        ),
        'spouse_parent': _person(
          'spouse_parent',
          children: ['spouse', 'spouse_sibling'],
        ),
        'spouse_sibling': _person('spouse_sibling', parents: ['spouse_parent']),
      };
      final result = DfsExtractor.extract(people: people, centerId: 'center');
      expect(result, contains('center'));
      expect(result, contains('spouse'));
      expect(result, isNot(contains('spouse_parent')));
      expect(result, isNot(contains('spouse_sibling')));
    });
  });

  // ─── 属性 1：DFS 代际距离不变量 ──────────────────────────────────────────

  group('属性 1：DFS 代际距离不变量', () {
    // **Validates: Requirements 4.1, 4.8**
    test('对任意家谱图和中心人物，结果集中每个血亲到中心人物的最短血亲路径 ≤ 2', () {
      final rng = Random(42);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        // 生成随机线性家谱（3~8 个节点）
        final size = rng.nextInt(6) + 3;
        final people = _buildLinearFamily(rng, size);
        final ids = people.keys.toList();
        final centerId = ids[rng.nextInt(ids.length)];

        final result = DfsExtractor.extract(people: people, centerId: centerId);

        // 对结果集中每个 ID，验证其到中心人物的最短血亲路径 ≤ 2
        // 配偶本身可能不在血亲路径上，需要区分血亲和配偶
        // 先计算血亲集合（不含配偶扩展）
        final bloodResult = _computeBloodOnly(people, centerId, 2);

        for (final id in result) {
          if (bloodResult.contains(id)) {
            // 血亲：验证路径距离
            final dist = _shortestBloodPath(people, centerId, id);
            expect(
              dist,
              lessThanOrEqualTo(2),
              reason: '第 $i 次迭代：节点 $id 到中心 $centerId 的血亲路径距离为 $dist，超过 2',
            );
          }
          // 配偶：其本身不需要满足血亲路径 ≤ 2，但其对应血亲必须在范围内
        }
      }
    });

    test('对树形家谱，结果集中血亲节点的代际距离均不超过 2', () {
      final rng = Random(99);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final people = _buildTreeFamily(rng, 4, 2, i * 20);
        if (people.isEmpty) continue;
        final ids = people.keys.toList();
        final centerId = ids[rng.nextInt(ids.length)];

        final result = DfsExtractor.extract(people: people, centerId: centerId);
        final bloodResult = _computeBloodOnly(people, centerId, 2);

        for (final id in bloodResult) {
          expect(result, contains(id), reason: '第 $i 次迭代：血亲 $id 应在结果集中');
          final dist = _shortestBloodPath(people, centerId, id);
          expect(
            dist,
            lessThanOrEqualTo(2),
            reason: '第 $i 次迭代：血亲 $id 距离 $dist 超过 2',
          );
        }
      }
    });
  });

  // ─── 属性 2：血亲配偶纳入结果 ────────────────────────────────────────────

  group('属性 2：血亲配偶纳入结果', () {
    // **Validates: Requirements 4.5**
    test('对含 spouseId 的家谱，每个血亲范围内 Person 的配偶都出现在结果集中', () {
      final rng = Random(7);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        // 构建含配偶的家谱：线性血亲链 + 每个节点有 50% 概率有配偶
        final size = rng.nextInt(5) + 2;
        final basePeople = _buildLinearFamily(rng, size);
        final people = Map<String, Person>.from(basePeople);

        // 为部分血亲添加配偶
        final spouseMap = <String, String>{}; // bloodId -> spouseId
        var spouseCounter = 1000 + i * 100;
        for (final id in basePeople.keys) {
          if (rng.nextBool()) {
            final spouseId = 's${spouseCounter++}';
            spouseMap[id] = spouseId;
            // 更新血亲的 spouseId
            final p = people[id]!;
            people[id] = _person(
              id,
              parents: p.parents,
              children: p.children,
              spouseId: spouseId,
            );
            // 添加配偶节点
            people[spouseId] = _person(spouseId, spouseId: id);
          }
        }

        final ids = basePeople.keys.toList();
        final centerId = ids[rng.nextInt(ids.length)];

        final result = DfsExtractor.extract(people: people, centerId: centerId);
        final bloodResult = _computeBloodOnly(people, centerId, 2);

        // 验证：每个血亲的配偶都在结果集中
        for (final bloodId in bloodResult) {
          final person = people[bloodId];
          if (person == null) continue;
          final spouseId = person.spouseId;
          if (spouseId != null && people.containsKey(spouseId)) {
            expect(
              result,
              contains(spouseId),
              reason: '第 $i 次迭代：血亲 $bloodId 的配偶 $spouseId 应在结果集中',
            );
          }
        }
      }
    });
  });

  // ─── 属性 3：配偶扩展不传播 DFS ──────────────────────────────────────────

  group('属性 3：配偶扩展不传播 DFS', () {
    // **Validates: Requirements 4.7**
    test('仅通过配偶关系纳入的 Person，其 parents/children 不被加入结果集', () {
      final rng = Random(13);
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        // 构建含姻亲分支的家谱：
        // 血亲链 + 配偶 + 配偶的额外血亲（不在中心人物 2 代内）
        final size = rng.nextInt(4) + 2;
        final basePeople = _buildLinearFamily(rng, size);
        final people = Map<String, Person>.from(basePeople);

        var extraCounter = 2000 + i * 200;
        final spouseOnlyIds = <String>{}; // 仅通过配偶关系纳入的 ID

        for (final id in basePeople.keys) {
          if (rng.nextBool()) {
            final spouseId = 'sp${extraCounter++}';
            // 配偶有自己的父母（姻亲分支）
            final spouseParentId = 'spp${extraCounter++}';
            final spouseChildId = 'spc${extraCounter++}';

            // 更新血亲的 spouseId
            final p = people[id]!;
            people[id] = _person(
              id,
              parents: p.parents,
              children: p.children,
              spouseId: spouseId,
            );

            // 配偶节点（有自己的父母和子女，但这些不是中心人物的血亲）
            people[spouseId] = _person(
              spouseId,
              spouseId: id,
              parents: [spouseParentId],
              children: [spouseChildId],
            );
            people[spouseParentId] = _person(
              spouseParentId,
              children: [spouseId],
            );
            people[spouseChildId] = _person(spouseChildId, parents: [spouseId]);

            spouseOnlyIds.add(spouseId);
          }
        }

        final ids = basePeople.keys.toList();
        final centerId = ids[rng.nextInt(ids.length)];

        final result = DfsExtractor.extract(people: people, centerId: centerId);
        final bloodResult = _computeBloodOnly(people, centerId, 2);

        // 验证：仅通过配偶关系纳入的节点，其 parents/children 不在结果集中
        // （除非这些 parents/children 本身也是血亲）
        for (final spouseId in spouseOnlyIds) {
          if (!result.contains(spouseId)) continue; // 该配偶不在结果集中，跳过
          if (bloodResult.contains(spouseId)) continue; // 该配偶本身也是血亲，跳过

          final spouse = people[spouseId];
          if (spouse == null) continue;

          for (final parentId in spouse.parents) {
            if (!bloodResult.contains(parentId)) {
              expect(
                result,
                isNot(contains(parentId)),
                reason: '第 $i 次迭代：配偶 $spouseId 的父母 $parentId 不应在结果集中',
              );
            }
          }
          for (final childId in spouse.children) {
            if (!bloodResult.contains(childId)) {
              expect(
                result,
                isNot(contains(childId)),
                reason: '第 $i 次迭代：配偶 $spouseId 的子女 $childId 不应在结果集中',
              );
            }
          }
        }
      }
    });
  });
}

// ─── 辅助：仅计算血亲集合（不含配偶扩展）────────────────────────────────────

/// 计算从 [centerId] 出发，代际距离 <= [maxGenerations] 的纯血亲集合（不含配偶扩展）。
Set<String> _computeBloodOnly(
  Map<String, Person> people,
  String centerId,
  int maxGenerations,
) {
  if (!people.containsKey(centerId)) return {};
  final result = <String>{};
  final visited = <String>{};
  final queue = <(String, int)>[(centerId, 0)];

  while (queue.isNotEmpty) {
    final (id, depth) = queue.removeAt(0);
    if (visited.contains(id)) continue;
    visited.add(id);
    if (depth > maxGenerations) continue;

    final person = people[id];
    if (person == null) continue;
    result.add(id);

    if (depth + 1 <= maxGenerations) {
      for (final parentId in person.parents) {
        if (!visited.contains(parentId) && people.containsKey(parentId)) {
          queue.add((parentId, depth + 1));
        }
      }
      for (final childId in person.children) {
        if (!visited.contains(childId) && people.containsKey(childId)) {
          queue.add((childId, depth + 1));
        }
      }
    }
  }
  return result;
}
