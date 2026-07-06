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
    {
      'type': 'function',
      'function': {
        'name': 'recommend_gift_amount',
        'description':
            '根据历史礼金记录和亲疏关系，为指定成员和事件类型推荐合适的礼金金额范围。调用时机：用户询问"该给多少钱"、"随多少礼"、"礼金建议"等。',
        'parameters': {
          'type': 'object',
          'properties': {
            'member': {'type': 'string', 'description': '送礼对象的姓名或称呼，例如 表哥、叔叔'},
            'event': {
              'type': 'string',
              'description': '事件类型，例如 结婚、生日、满月、春节、乔迁',
            },
          },
          'required': ['member', 'event'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_family_member',
        'description':
            '通过对话创建新的家族成员并自动建立关系。当用户说"加个人"、"添加"、"录入"、"我有个XX叫YY"时调用。先调用 search_family_members 确认不重复，再调用本工具。',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': '新成员姓名'},
            'gender': {
              'type': 'string',
              'enum': ['男', '女'],
              'description': '性别',
            },
            'relation_to': {
              'type': 'string',
              'description': '关联到的已有成员 ID、姓名或称呼，例如 爸爸、root',
            },
            'relation_type': {
              'type': 'string',
              'enum': ['parent', 'child', 'spouse'],
              'description':
                  '关系类型：parent=新成员是 relation_to 的父母，child=新成员是 relation_to 的子女，spouse=新成员是 relation_to 的配偶',
            },
            'bio': {
              'type': 'string',
              'description': '备注信息，可选',
            },
          },
          'required': ['name', 'gender', 'relation_to', 'relation_type'],
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
      'recommend_gift_amount' => '推荐礼金',
      'add_family_member' => '添加成员',
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
      'recommend_gift_amount' => _recommendGift(
        arguments['member']?.toString() ?? '',
        arguments['event']?.toString() ?? '',
      ),
      'add_family_member' => _addMember(arguments),
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

  // ─── 礼金推荐 ─────────────────────────────────────────

  Map<String, dynamic> _recommendGift(String member, String event) {
    final person = _resolve(member);
    if (person == null) return {'ok': false, 'error': '未找到成员：$member'};
    if (event.isEmpty) return {'ok': false, 'error': '请提供事件类型'};

    // 收集全家族礼金记录，事件名模糊匹配
    final allGifts = controller.allPeople
        .expand((p) => p.giftHistory.map((r) => (person: p, record: r)))
        .toList();

    // 模糊匹配：包含关系即命中（"喜事" ↔ "结婚喜事"）
    bool eventMatch(String recordEvent) {
      final a = recordEvent.toLowerCase();
      final b = event.toLowerCase();
      return a.contains(b) || b.contains(a);
    }

    final matchedRecords = allGifts
        .where((g) => eventMatch(g.record.event))
        .toList();

    // 如果没有匹配的记录，用全部记录做参考（至少给个全局参考值）
    final useGeneric = matchedRecords.isEmpty;
    final records = useGeneric ? allGifts : matchedRecords;

    if (records.isEmpty) {
      return {
        'ok': true,
        'member': _basicMember(person),
        'event': event,
        'recommendation': '暂无任何礼金记录，建议参考当地习俗或询问长辈。',
        'range_min': null,
        'range_max': null,
        'average': null,
        'sample_count': 0,
      };
    }

    final amounts = records.map((g) => g.record.amount).toList()..sort();
    final avg = amounts.fold<double>(0, (s, a) => s + a) / amounts.length;

    // 判断亲疏：BFS 计算路径距离
    final distance = _pedigreeDistance(controller.mainPersonId, person.id);
    final isClose = distance != null && distance <= 2; // 1-2步为近亲

    // 相近关系层记录
    final closeAmounts = records
        .where((g) {
          final d = _pedigreeDistance(controller.mainPersonId, g.person.id);
          return d != null && d <= 2;
        })
        .map((g) => g.record.amount)
        .toList();
    final closeAvg = closeAmounts.isEmpty
        ? avg
        : closeAmounts.fold<double>(0, (s, a) => s + a) / closeAmounts.length;

    final suggestionMin = (closeAvg * 0.8).roundToDouble();
    final suggestionMax = (closeAvg * 1.3).roundToDouble();

    return {
      'ok': true,
      'member': _basicMember(person),
      'event': event,
      'match_mode': useGeneric ? '无同类事件，展示全局参考' : '精确匹配',
      'relationship_closeness': isClose ? '近亲（1-2步）' : '远亲（3步以上）',
      'recommended_range': '$suggestionMin - $suggestionMax 元',
      'historical_average': avg.roundToDouble(),
      'close_relation_average': closeAvg.roundToDouble(),
      'sample_count': records.length,
      'matched_count': matchedRecords.length,
      'historical_min': amounts.first,
      'historical_max': amounts.last,
      'recent_examples': records
          .take(5)
          .map((g) => {
                'name': g.person.name,
                'amount': g.record.amount,
                'event': g.record.event,
                'date': g.record.date.toIso8601String(),
              })
          .toList(),
    };
  }

  /// BFS 计算两人之间的谱系距离（步数），用于判断亲疏。
  int? _pedigreeDistance(String from, String to) {
    if (from == to) return 0;
    final visited = <String>{from};
    final queue = <_QueueEntry>[_QueueEntry(from, 0)];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final neighbors = _neighborIds(cur.id);
      for (final nid in neighbors) {
        if (nid == to) return cur.distance + 1;
        if (visited.add(nid)) {
          queue.add(_QueueEntry(nid, cur.distance + 1));
        }
      }
    }
    return null;
  }

  Set<String> _neighborIds(String personId) {
    final person = controller.getPerson(personId);
    if (person == null) return {};
    final ids = <String>{...person.parents, ...person.children};
    if (person.spouseId != null) ids.add(person.spouseId!);
    // 反向配偶
    for (final p in controller.allPeople) {
      if (p.spouseId == personId) ids.add(p.id);
    }
    return ids;
  }

  // ─── 对话式添加成员 ────────────────────────────────────

  Map<String, dynamic> _addMember(Map<String, dynamic> args) {
    final name = args['name']?.toString().trim() ?? '';
    final gender = args['gender']?.toString() ?? '男';
    final relationTo = args['relation_to']?.toString().trim() ?? '';
    final relationType = args['relation_type']?.toString() ?? '';
    final bio = args['bio']?.toString() ?? '';

    if (name.isEmpty) return {'ok': false, 'error': '姓名不能为空'};
    if (relationTo.isEmpty) return {'ok': false, 'error': '请指定关联到哪位已有成员'};

    final existing = _resolve(relationTo);
    if (existing == null) {
      return {'ok': false, 'error': '未找到关联成员：$relationTo，请先用 search_family_members 查找'};
    }

    // 检查重名
    final dupCheck = controller.allPeople.where(
      (p) => p.name == name,
    );
    if (dupCheck.isNotEmpty) {
      return {
        'ok': false,
        'error': '已存在名为"$name"的成员（ID: ${dupCheck.first.id}），请确认是否重复',
      };
    }

    try {
      switch (relationType) {
        case 'parent':
          controller.addParent(
            existing.id,
            name,
            relationType == 'parent' && gender == '男' ? '爸爸' : '妈妈',
            bio,
            gender,
          );
          break;
        case 'child':
          controller.addChild(existing.id, name, '', bio, gender);
          break;
        case 'spouse':
          controller.addSpouse(existing.id, name, '', bio, gender);
          break;
        default:
          return {'ok': false, 'error': '不支持的关系类型：$relationType，可选 parent/child/spouse'};
      }

      // 找到刚创建的新成员
      final created = controller.allPeople.firstWhere(
        (p) => p.name == name,
        orElse: () => existing,
      );

      return {
        'ok': true,
        'message': '已添加：$name（${gender}），作为 ${existing.name} 的 ${relationType == 'parent' ? '父母' : relationType == 'child' ? '子女' : '配偶'}',
        'created_member': _basicMember(created),
        'related_to': _basicMember(existing),
        'relation_type': relationType,
      };
    } catch (e) {
      return {'ok': false, 'error': '添加失败：$e'};
    }
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

class _QueueEntry {
  final String id;
  final int distance;
  const _QueueEntry(this.id, this.distance);
}
