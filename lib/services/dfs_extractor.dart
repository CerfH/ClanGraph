import 'package:clangraph/models/person.dart';

/// DFS 亲属范围提取算法
///
/// 以中心人物为起点，沿血亲关系（parents/children）执行 BFS，
/// 提取代际距离不超过 [maxGenerations] 的所有 Person，
/// 并将每位血亲的直接配偶（spouseId）一并纳入结果集。
/// 配偶不以起点继续 DFS（姻亲剪枝）。
class DfsExtractor {
  /// 以 [centerId] 为起点，沿血亲关系 BFS，
  /// 提取代际距离 <= [maxGenerations] 的所有 Person，
  /// 并将每位血亲的直接配偶一并纳入。
  ///
  /// 若 [centerId] 不存在于 [people] 中，返回空集合。
  static Set<String> extract({
    required Map<String, Person> people,
    required String centerId,
    int maxGenerations = 2,
  }) {
    if (!people.containsKey(centerId)) return {};

    final result = <String>{};
    final visited = <String>{};
    // 队列项：(id, depth)
    final queue = <(String, int)>[(centerId, 0)];

    while (queue.isNotEmpty) {
      final (id, depth) = queue.removeAt(0);

      if (visited.contains(id)) continue;
      visited.add(id);

      // 剪枝：超过最大代际距离
      if (depth > maxGenerations) continue;

      final person = people[id];
      if (person == null) continue;

      result.add(id);

      // 遍历血亲关系
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

    // 配偶扩展（姻亲剪枝）：
    // 对结果集中每个血亲，若 spouseId 非空且存在，加入结果集，但不继续 DFS
    final bloodRelatives = Set<String>.from(result);
    for (final id in bloodRelatives) {
      final person = people[id];
      if (person == null) continue;
      final spouseId = person.spouseId ?? person.spouse;
      if (spouseId != null && people.containsKey(spouseId)) {
        result.add(spouseId);
      }
    }

    // 叔伯扩展：
    // 对中心人的每个父母，找到其父母（祖父母），
    // 将祖父母的子女中不在结果集的兄弟姐妹（叔伯舅姑）加入结果集，
    // 并对新加入的叔伯执行配偶扩展。
    final centerPerson = people[centerId]!;
    for (final parentId in centerPerson.parents) {
      final parent = people[parentId];
      if (parent == null) continue;
      for (final grandpaId in parent.parents) {
        final grandpa = people[grandpaId];
        if (grandpa == null) continue;
        for (final siblingId in grandpa.children) {
          if (!result.contains(siblingId) && people.containsKey(siblingId)) {
            result.add(siblingId);
            // 对新加入的叔伯执行配偶扩展
            final sibling = people[siblingId];
            if (sibling != null) {
              final siblingSpouseId = sibling.spouseId ?? sibling.spouse;
              if (siblingSpouseId != null &&
                  people.containsKey(siblingSpouseId)) {
                result.add(siblingSpouseId);
              }
            }
          }
        }
      }
    }

    return result;
  }
}
