import '../controllers/family_controller.dart';
import '../models/person.dart';

class FamilyAgentTools {
  final FamilyController controller;

  FamilyAgentTools(this.controller);

  static const definitions = <Map<String, dynamic>>[
    {
      'type': 'function',
      'function': {
        'name': 'search_family_members',
        'description': '按姓名或用户录入的称呼搜索家族成员，返回可用于后续工具的成员 ID。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '姓名或称呼，例如爸爸、黄伟'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_member_details',
        'description': '读取指定成员的父母、配偶、子女、兄弟姐妹、备注和礼金记录。',
        'parameters': {
          'type': 'object',
          'properties': {
            'member': {'type': 'string', 'description': '成员 ID、姓名或称呼'},
          },
          'required': ['member'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_gift_summary',
        'description': '统计指定成员或全家族的礼金笔数、总金额及最近记录。',
        'parameters': {
          'type': 'object',
          'properties': {
            'member': {
              'type': 'string',
              'description': '可选；成员 ID、姓名或称呼。不传表示统计全家族',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_family_branch',
        'description': '读取某位成员这一支的后代、后代配偶及层级，适合回答“某某那边有哪些亲戚”。',
        'parameters': {
          'type': 'object',
          'properties': {
            'member': {'type': 'string', 'description': '成员 ID、姓名或称呼'},
          },
          'required': ['member'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_graph_center',
        'description': '当用户明确要求以某人为中心查看家谱时，切换图谱中心。',
        'parameters': {
          'type': 'object',
          'properties': {
            'member': {'type': 'string', 'description': '成员 ID、姓名或称呼'},
          },
          'required': ['member'],
        },
      },
    },
  ];

  static String displayName(String toolName) {
    return switch (toolName) {
      'search_family_members' => '搜索家族成员',
      'get_member_details' => '读取人物关系',
      'get_family_branch' => '读取家族分支',
      'get_gift_summary' => '统计礼金往来',
      'set_graph_center' => '切换图谱中心',
      _ => toolName,
    };
  }

  Map<String, dynamic> execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    return switch (toolName) {
      'search_family_members' => _search(arguments['query']?.toString() ?? ''),
      'get_member_details' => _memberDetails(
        arguments['member']?.toString() ?? '',
      ),
      'get_family_branch' => _familyBranch(
        arguments['member']?.toString() ?? '',
      ),
      'get_gift_summary' => _giftSummary(arguments['member']?.toString()),
      'set_graph_center' => _setCenter(arguments['member']?.toString() ?? ''),
      _ => {'ok': false, 'error': '未知工具: $toolName'},
    };
  }

  Map<String, dynamic> _search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return {'ok': false, 'error': '搜索词不能为空'};
    }
    final matches = controller.allPeople
        .where(
          (person) =>
              person.name.toLowerCase().contains(normalized) ||
              person.relationship.toLowerCase().contains(normalized),
        )
        .take(10)
        .map(_basicMember)
        .toList();
    return {'ok': true, 'count': matches.length, 'members': matches};
  }

  Map<String, dynamic> _memberDetails(String value) {
    final person = _resolve(value);
    if (person == null) return {'ok': false, 'error': '未找到成员：$value'};

    return {
      'ok': true,
      'member': _basicMember(person),
      'bio': person.bio,
      'parents': _parents(person).map(_basicMember).toList(),
      'spouses': _spouses(person).map(_basicMember).toList(),
      'children': _children(person).map(_basicMember).toList(),
      'siblings': _siblings(person).map(_basicMember).toList(),
      'giftHistory': person.giftHistory
          .map(
            (record) => {
              'event': record.event,
              'amount': record.amount,
              'date': record.date.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _familyBranch(String value) {
    final root = _resolve(value);
    if (root == null) return {'ok': false, 'error': '未找到成员：$value'};

    final branch = <Map<String, dynamic>>[];
    final visited = <String>{root.id};
    var frontier = <Person>[root];
    for (var depth = 1; depth <= 3 && frontier.isNotEmpty; depth++) {
      final next = <Person>[];
      for (final current in frontier) {
        for (final child in _children(current)) {
          if (!visited.add(child.id)) continue;
          branch.add({
            ..._basicMember(child),
            'depth': depth,
            'via': current.name,
          });
          next.add(child);
          for (final spouse in _spouses(child)) {
            if (!visited.add(spouse.id)) continue;
            branch.add({
              ..._basicMember(spouse),
              'depth': depth,
              'via': '${child.name}的配偶',
            });
          }
        }
      }
      frontier = next;
    }

    return {
      'ok': true,
      'root': _basicMember(root),
      'count': branch.length,
      'members': branch,
    };
  }

  Map<String, dynamic> _giftSummary(String? value) {
    final trimmed = value?.trim() ?? '';
    final person = trimmed.isEmpty ? null : _resolve(trimmed);
    if (trimmed.isNotEmpty && person == null) {
      return {'ok': false, 'error': '未找到成员：$trimmed'};
    }

    final records = person == null
        ? controller.allPeople.expand((p) => p.giftHistory).toList()
        : person.giftHistory.toList();
    records.sort((a, b) => b.date.compareTo(a.date));

    return {
      'ok': true,
      'scope': person == null ? '全家族' : person.name,
      'count': records.length,
      'totalAmount': records.fold<double>(0, (sum, item) => sum + item.amount),
      'recent': records
          .take(5)
          .map(
            (record) => {
              'event': record.event,
              'amount': record.amount,
              'date': record.date.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _setCenter(String value) {
    final person = _resolve(value);
    if (person == null) return {'ok': false, 'error': '未找到成员：$value'};
    controller.setMainPerson(person.id);
    return {
      'ok': true,
      'message': '已将图谱中心切换为 ${person.name}',
      'member': _basicMember(person),
    };
  }

  Person? _resolve(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final byId = controller.getPerson(value.trim());
    if (byId != null) return byId;

    for (final person in controller.allPeople) {
      if (person.name.toLowerCase() == normalized ||
          person.relationship.toLowerCase() == normalized) {
        return person;
      }
    }
    for (final person in controller.allPeople) {
      if (person.name.toLowerCase().contains(normalized) ||
          person.relationship.toLowerCase().contains(normalized)) {
        return person;
      }
    }
    return null;
  }

  Iterable<Person> _spouses(Person person) {
    final ids = <String>{};
    if (person.spouse != null) ids.add(person.spouse!);
    if (person.spouseId != null) ids.add(person.spouseId!);
    for (final candidate in controller.allPeople) {
      if (candidate.spouse == person.id || candidate.spouseId == person.id) {
        ids.add(candidate.id);
      }
    }
    return ids.map(controller.getPerson).whereType<Person>();
  }

  Iterable<Person> _parents(Person person) {
    final ids = <String>{...person.parents};
    for (final candidate in controller.allPeople) {
      if (candidate.children.contains(person.id)) ids.add(candidate.id);
    }
    for (final parentId in ids.toList()) {
      final parent = controller.getPerson(parentId);
      if (parent != null) ids.addAll(_spouses(parent).map((p) => p.id));
    }
    return ids.map(controller.getPerson).whereType<Person>();
  }

  Iterable<Person> _children(Person person) {
    final ids = <String>{...person.children};
    for (final candidate in controller.allPeople) {
      if (candidate.parents.contains(person.id)) ids.add(candidate.id);
    }
    for (final spouse in _spouses(person)) {
      ids.addAll(spouse.children);
      for (final candidate in controller.allPeople) {
        if (candidate.parents.contains(spouse.id)) ids.add(candidate.id);
      }
    }
    return ids.map(controller.getPerson).whereType<Person>();
  }

  Iterable<Person> _siblings(Person person) {
    final parentIds = _parents(person).map((p) => p.id).toSet();
    final siblingIds = <String>{};
    for (final candidate in controller.allPeople) {
      if (candidate.id == person.id) continue;
      final candidateParents = _parents(candidate).map((p) => p.id).toSet();
      if (parentIds.intersection(candidateParents).isNotEmpty) {
        siblingIds.add(candidate.id);
      }
    }
    return siblingIds.map(controller.getPerson).whereType<Person>();
  }

  Map<String, dynamic> _basicMember(Person person) => {
    'id': person.id,
    'name': person.name,
    'relationship': person.relationship,
    'gender': person.gender,
  };
}
