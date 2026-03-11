import 'package:flutter/material.dart';
import 'package:clangraph/models/person.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyController extends ChangeNotifier {
  // Using a Map for O(1) access by ID
  final Map<String, Person> _people = {};
  final String _centerPersonId = 'root';
  String? _selectedPersonId;

  // --- 插入开始：持久化核心逻辑 ---
  static const String _storageKey = 'family_data_v1';
  static const String _aiSystemPrompt =
      '你现在是一位拥有顶尖商业洞察力的家族关系专家。我为你提供了一份结构化的家族图谱 JSON。你的任务是根据 ID 链路进行深层逻辑推理（例如：识别出 A 的父亲的母亲是 A 的奶奶）。在回答时，请基于这些底层关联，提供人性化且深刻的洞见。';

  // 1. 从硬盘读取数据
  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storageKey);

    if (encodedData != null) {
      final dynamic decodedData = json.decode(encodedData);
      final importedPeople = _decodePeople(decodedData);
      _people
        ..clear()
        ..addAll(importedPeople);
      _ensureRootPerson();
      notifyListeners(); // 数据加载完，通知界面刷新
    }
  }

  // 2. 将数据保存到硬盘
  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      // 这里依赖你 person.dart 里写好的 toMap 方法
      _people.map((key, value) => MapEntry(key, value.toMap())),
    );
    await prefs.setString(_storageKey, encodedData);
  }
  // --- 插入结束 ---

  FamilyController() {
    _initData();
    loadFromDisk();
  }

  // Getters
  Person? get centerPerson => _people[_centerPersonId];
  Person? get selectedPerson =>
      _selectedPersonId != null ? _people[_selectedPersonId] : null;
  List<Person> get allPeople => _people.values.toList();

  List<String> get dynamicEventHistory {
    // 1. 收集所有人的所有礼金记录
    final allRecords = _people.values.expand((p) => p.giftHistory).toList();

    // 2. 按日期倒序排序（最新的在前面）
    allRecords.sort((a, b) => b.date.compareTo(a.date));

    // 3. 去重并取前10个
    final uniqueEvents = <String>{};
    final result = <String>[];

    for (var record in allRecords) {
      if (uniqueEvents.add(record.event)) {
        result.add(record.event);
        if (result.length >= 10) break;
      }
    }
    return result;
  }

  // AI Context Summary
  String get aiContextSummary {
    final members = _people.values.map((p) {
      final parentRefs = p.parents
          .map(
            (parentId) => {
              'id': parentId,
              'name': _people[parentId]?.name ?? '',
            },
          )
          .toList();
      final childRefs = p.children
          .map(
            (childId) => {'id': childId, 'name': _people[childId]?.name ?? ''},
          )
          .toList();
      final spouseRef = p.spouse == null
          ? null
          : {'id': p.spouse!, 'name': _people[p.spouse!]?.name ?? ''};

      return {
        'id': p.id,
        'name': p.name,
        'relations': {
          'parents': parentRefs,
          'spouse': spouseRef,
          'children': childRefs,
        },
        'details': {
          'relationship': p.relationship,
          'gender': p.gender,
          'bio': p.bio,
          'giftHistory': p.giftHistory
              .map(
                (g) => {
                  'id': g.id,
                  'event': g.event,
                  'amount': g.amount,
                  'date': g.date.toIso8601String(),
                },
              )
              .toList(),
        },
      };
    }).toList();

    final graphPayload = {'members': members};
    return '$_aiSystemPrompt\n${json.encode(graphPayload)}';
  }

  String exportToJSON() {
    final payload = {
      'members': _people.values.map((person) => person.toMap()).toList(),
    };
    return json.encode(payload);
  }

  Future<void> importFromJSON(String jsonString) async {
    final dynamic decoded = json.decode(jsonString);
    final importedPeople = _decodePeople(decoded);
    if (importedPeople.isEmpty) {
      throw const FormatException('导入数据为空或格式不正确');
    }

    _people
      ..clear()
      ..addAll(importedPeople);
    _ensureRootPerson();
    _selectedPersonId = null;
    notifyListeners();
    await saveToDisk();
  }

  // Actions
  void selectPerson(String id) {
    _selectedPersonId = id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPersonId = null;
    notifyListeners();
  }

  // Helper to get person by ID
  Person? getPerson(String id) => _people[id];

  // Helper to get parents of a person
  List<Person> getParents(String id) {
    final person = _people[id];
    if (person == null) return [];
    return person.parents
        .map((pid) => _people[pid])
        .whereType<Person>()
        .toList();
  }

  // Helper to get children of a person
  List<Person> getChildren(String id) {
    final person = _people[id];
    if (person == null) return [];
    return person.children
        .map((cid) => _people[cid])
        .whereType<Person>()
        .toList();
  }

  // Helper to get siblings of a person
  List<Person> getSiblings(String id) {
    final person = _people[id];
    if (person == null || person.parents.isEmpty) return [];

    final Set<String> siblingIds = {};
    for (var parentId in person.parents) {
      final parent = _people[parentId];
      if (parent != null) {
        siblingIds.addAll(parent.children);
      }
    }

    // Remove self
    siblingIds.remove(id);

    return siblingIds.map((sid) => _people[sid]).whereType<Person>().toList();
  }

  // Calculate generations relative to root
  // Returns a map where key is generation (0 for root, -1 for parents, etc)
  // and value is list of people in that generation
  Map<int, List<Person>> calculateGenerations() {
    final Map<int, List<Person>> generations = {};
    final Set<String> visited = {};
    final List<_QueueItem> queue = [];

    final root = _people[_centerPersonId];
    if (root == null) return {};

    queue.add(_QueueItem(root, 0));
    visited.add(root.id);

    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      final person = item.person;
      final gen = item.generation;

      generations.putIfAbsent(gen, () => []).add(person);

      // Traverse Parents (gen - 1)
      for (var parentId in person.parents) {
        if (!visited.contains(parentId)) {
          final parent = _people[parentId];
          if (parent != null) {
            visited.add(parentId);
            queue.add(_QueueItem(parent, gen - 1));
          }
        }
      }

      // Traverse Children (gen + 1)
      for (var childId in person.children) {
        if (!visited.contains(childId)) {
          final child = _people[childId];
          if (child != null) {
            visited.add(childId);
            queue.add(_QueueItem(child, gen + 1));
          }
        }
      }

      // Traverse Spouse (same gen)
      if (person.spouse != null && !visited.contains(person.spouse)) {
        final spouse = _people[person.spouse];
        if (spouse != null) {
          visited.add(person.spouse!);
          queue.add(_QueueItem(spouse, gen));
        }
      }
    }

    return generations;
  }

  void _initData() {
    final root = Person(
      id: 'root',
      name: '我',
      relationship: '本人',
      gender: '男', // 默认性别
      bio: '这是本人',
      parents: [],
      children: [],
      giftHistory: [],
    );
    _people['root'] = root;
  }

  Map<String, Person> _decodePeople(dynamic decoded) {
    final result = <String, Person>{};

    if (decoded is Map<String, dynamic>) {
      final members = decoded['members'];

      // 兼容导出格式: {"members":[...]}
      if (members is List) {
        for (final item in members.whereType<Map>()) {
          final person = Person.fromMap(Map<String, dynamic>.from(item));
          if (person.id.isNotEmpty) {
            result[person.id] = person;
          }
        }
        return result;
      }

      // 兼容本地存储格式: {"id": {...person...}}
      decoded.forEach((key, value) {
        if (value is Map) {
          final person = Person.fromMap(Map<String, dynamic>.from(value));
          final resolvedId = person.id.isNotEmpty ? person.id : key.toString();
          result[resolvedId] = person.id == resolvedId
              ? person
              : Person(
                  id: resolvedId,
                  name: person.name,
                  relationship: person.relationship,
                  gender: person.gender,
                  bio: person.bio,
                  parents: person.parents,
                  children: person.children,
                  spouse: person.spouse,
                  giftHistory: person.giftHistory,
                );
        }
      });
      return result;
    }

    // 兼容纯数组格式: [{...person...}]
    if (decoded is List) {
      for (final item in decoded.whereType<Map>()) {
        final person = Person.fromMap(Map<String, dynamic>.from(item));
        if (person.id.isNotEmpty) {
          result[person.id] = person;
        }
      }
    }

    return result;
  }

  void _ensureRootPerson() {
    if (_people.containsKey(_centerPersonId)) {
      return;
    }
    _initData();
  }

  // 替换 addParent 方法：实现自动配偶识别
  void addParent(
    String childId,
    String name,
    String relationship,
    String bio,
    String gender,
  ) {
    final child = _people[childId];
    if (child == null) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();

    // --- 自动配偶探测逻辑 ---
    String? existingParentId;
    if (child.parents.isNotEmpty) {
      existingParentId = child.parents.first; // 已经有一个家长了
    }

    // 1. 创建新家长
    final parent = Person(
      id: newId,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      children: [childId],
      spouse: existingParentId, // 如果有旧家长，直接指向
    );
    _people[newId] = parent;

    // 2. 如果存在旧家长，给旧家长也补上配偶指针
    if (existingParentId != null) {
      final oldParent = _people[existingParentId]!;
      _people[existingParentId] = Person(
        id: oldParent.id,
        name: oldParent.name,
        relationship: oldParent.relationship,
        gender: oldParent.gender,
        bio: oldParent.bio,
        parents: oldParent.parents,
        children: oldParent.children,
        spouse: newId, // 指向新来的
        giftHistory: oldParent.giftHistory,
      );
    }

    // 3. 更新孩子
    _people[childId] = Person(
      id: child.id,
      name: child.name,
      relationship: child.relationship,
      gender: child.gender,
      bio: child.bio,
      parents: [...child.parents, newId],
      children: child.children,
      spouse: child.spouse,
      giftHistory: child.giftHistory,
    );

    notifyListeners();
    saveToDisk();
  }

  // Add Child
  void addChild(
    String parentId,
    String name,
    String relationship,
    String bio,
    String gender,
  ) {
    final parent = _people[parentId];
    if (parent == null) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final child = Person(
      id: newId,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      parents: [parentId],
    );

    _people[newId] = child;

    // Update parent's children list
    final updatedParent = Person(
      id: parent.id,
      name: parent.name,
      relationship: parent.relationship,
      gender: parent.gender,
      bio: parent.bio,
      parents: parent.parents,
      children: [...parent.children, newId],
      spouse: parent.spouse,
      giftHistory: parent.giftHistory,
    );
    _people[parentId] = updatedParent;

    notifyListeners();
    saveToDisk(); // <--- 每次数据变化后，同步保存到硬盘
  }

  // Add Gift Record
  void addGiftRecord(
    String personId,
    double amount,
    String event,
    DateTime date,
  ) {
    final person = _people[personId];
    if (person == null) return;

    final newGift = GiftRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      event: event,
      date: date,
    );

    final updatedPerson = Person(
      id: person.id,
      name: person.name,
      relationship: person.relationship,
      gender: person.gender,
      bio: person.bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      giftHistory: [...person.giftHistory, newGift],
    );

    _people[personId] = updatedPerson;
    notifyListeners();
    saveToDisk();
  }

  // Update Gift Record
  void updateGiftRecord(String personId, GiftRecord record) {
    final person = _people[personId];
    if (person == null) return;

    final updatedHistory = person.giftHistory.map((r) {
      return r.id == record.id ? record : r;
    }).toList();

    final updatedPerson = Person(
      id: person.id,
      name: person.name,
      relationship: person.relationship,
      gender: person.gender,
      bio: person.bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      giftHistory: updatedHistory,
    );

    _people[personId] = updatedPerson;
    notifyListeners();
    saveToDisk();
  }

  // Delete Gift Record
  void deleteGiftRecord(String personId, String recordId) {
    final person = _people[personId];
    if (person == null) return;

    final updatedHistory = person.giftHistory
        .where((r) => r.id != recordId)
        .toList();

    final updatedPerson = Person(
      id: person.id,
      name: person.name,
      relationship: person.relationship,
      gender: person.gender,
      bio: person.bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      giftHistory: updatedHistory,
    );

    _people[personId] = updatedPerson;
    notifyListeners();
    saveToDisk();
  }

  // Get Default Date for Event
  DateTime? getEventDefaultDate(String eventName) {
    final allRecords = _people.values
        .expand((p) => p.giftHistory)
        .where((r) => r.event == eventName)
        .toList();

    if (allRecords.isEmpty) return null;

    // Sort by date descending to find the latest
    allRecords.sort((a, b) => b.date.compareTo(a.date));
    return allRecords.first.date;
  }

  // Update Person
  void updatePerson(
    String id,
    String name,
    String relationship,
    String bio,
    String gender,
  ) {
    final person = _people[id];
    if (person == null) return;

    final updatedPerson = Person(
      id: person.id,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      giftHistory: person.giftHistory,
    );
    _people[id] = updatedPerson;
    notifyListeners();
    saveToDisk(); // <--- 每次数据变化后，同步保存到硬盘
  }

  // Delete Person (Only leaves)
  void deletePerson(String id) {
    if (id == 'root') return; // Cannot delete root

    final person = _people[id];
    if (person == null) return;

    // Remove from parents' children lists
    for (var parentId in person.parents) {
      final parent = _people[parentId];
      if (parent != null) {
        final updatedParent = Person(
          id: parent.id,
          name: parent.name,
          relationship: parent.relationship,
          gender: parent.gender,
          bio: parent.bio,
          parents: parent.parents,
          children: parent.children.where((cid) => cid != id).toList(),
          spouse: parent.spouse,
          giftHistory: parent.giftHistory,
        );
        _people[parentId] = updatedParent;
      }
    }

    // Remove from children's parents lists
    for (var childId in person.children) {
      final child = _people[childId];
      if (child != null) {
        final updatedChild = Person(
          id: child.id,
          name: child.name,
          relationship: child.relationship,
          gender: child.gender,
          bio: child.bio,
          parents: child.parents.where((pid) => pid != id).toList(),
          children: child.children,
          spouse: child.spouse,
          giftHistory: child.giftHistory,
        );
        _people[childId] = updatedChild;
      }
    }

    // Remove from map
    _people.remove(id);
    if (_selectedPersonId == id) {
      _selectedPersonId = null;
    }
    notifyListeners();
    saveToDisk();
  }
}

class _QueueItem {
  final Person person;
  final int generation;

  _QueueItem(this.person, this.generation);
}
