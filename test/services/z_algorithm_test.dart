import 'package:clangraph/models/person.dart';
import 'package:clangraph/services/z_algorithm.dart';
import 'package:flutter_test/flutter_test.dart';

Person _person({
  required String id,
  List<String> parents = const [],
  List<String> children = const [],
  String? spouse,
  String? spouseId,
}) {
  return Person(
    id: id,
    name: id,
    relationship: '',
    gender: '男',
    bio: '',
    parents: parents,
    children: children,
    spouse: spouse,
    spouseId: spouseId,
  );
}

void main() {
  group('TieredRippleLayout 重新选择中心人物', () {
    test('父亲为中心时，仅由女儿反向 parents 指向的关系仍属于 T1', () {
      final people = [
        _person(id: 'father', children: const ['me']),
        _person(id: 'me', parents: const ['father']),
        // 模拟旧数据不完全双向：father.children 尚未包含 daughter。
        _person(id: 'daughter', parents: const ['father']),
      ];

      final result = TieredRippleLayout(seed: 1).compute(
        allPeople: people,
        rootId: 'father',
        canvasCenter: const Offset(500, 500),
        generationMap: {
          0: [people[0]],
          1: [people[1], people[2]],
        },
      );

      final daughter = result.singleWhere(
        (node) => node.person.id == 'daughter',
      );
      expect(daughter.tier, 1);
      expect(daughter.radius, TierConfig.radiusT1);
      expect(daughter.orbitRadius, inInclusiveRange(100, 140));
    });

    test('spouseId 双向任一侧存在时，配偶仍属于 T1', () {
      final people = [
        _person(id: 'center'),
        _person(id: 'spouse', spouseId: 'center'),
      ];

      final result = TieredRippleLayout(seed: 2).compute(
        allPeople: people,
        rootId: 'center',
        canvasCenter: const Offset(500, 500),
        generationMap: {0: people},
      );

      expect(result.singleWhere((node) => node.person.id == 'spouse').tier, 1);
    });

    test('父亲为中心时，母亲名下的女儿按共同子女进入 T1', () {
      final people = [
        _person(id: 'father', children: const ['me'], spouse: 'mother'),
        _person(
          id: 'mother',
          children: const ['me', 'daughter'],
          spouse: 'father',
        ),
        _person(id: 'me', parents: const ['father', 'mother']),
        // 与真机数据一致：妹妹只记录母亲为 parent。
        _person(id: 'daughter', parents: const ['mother']),
      ];

      final result = TieredRippleLayout(seed: 3).compute(
        allPeople: people,
        rootId: 'father',
        canvasCenter: const Offset(500, 500),
        generationMap: {
          0: [people[0], people[1]],
          1: [people[2], people[3]],
        },
      );

      final daughter = result.singleWhere(
        (node) => node.person.id == 'daughter',
      );
      expect(daughter.tier, 1);
      expect(daughter.radius, TierConfig.radiusT1);
      expect(daughter.orbitRadius, inInclusiveRange(100, 140));
    });
  });
}
