import 'package:flutter/material.dart';
import 'package:clangraph/models/person.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FamilyController extends ChangeNotifier {
  final Map<String, Person> _people = {};
  String _mainPersonId = 'root';
  String? _selectedPersonId;

  static const String _storageKey = 'family_data_v1';
  static const String _aiSystemPrompt =
      '你现在是一位拥有顶尖商业洞察力的家族关系专家。我为你提供了一份结构化的家族图谱 JSON。你的任务是根据 ID 链路进行深层逻辑推理（例如：识别出 A 的父亲的母亲是 A 的奶奶）。在回答时，请基于这些底层关联，提供人性化且深刻的洞见。';

  String get mainPersonId => _mainPersonId;

  void setMainPerson(String id) {
    if (!_people.containsKey(id)) return;
    _mainPersonId = id;
    notifyListeners();
  }

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
      notifyListeners();
    } else {
      _initData();
    }
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      _people.map((key, value) => MapEntry(key, value.toMap())),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  FamilyController() {
    _initData();
    loadFromDisk();
  }

  Person? get centerPerson => _people[_mainPersonId];
  Person? get selectedPerson =>
      _selectedPersonId != null ? _people[_selectedPersonId] : null;
  List<Person> get allPeople => _people.values.toList();

  List<String> get dynamicEventHistory {
    final allRecords = _people.values.expand((p) => p.giftHistory).toList();
    allRecords.sort((a, b) => b.date.compareTo(a.date));
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
      final spouseRef = p.spouseId == null
          ? null
          : {'id': p.spouseId!, 'name': _people[p.spouseId!]?.name ?? ''};
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

  void selectPerson(String id) {
    _selectedPersonId = id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPersonId = null;
    notifyListeners();
  }

  Person? getPerson(String id) => _people[id];

  List<Person> getParents(String id) {
    final person = _people[id];
    if (person == null) return [];
    return person.parents
        .map((pid) => _people[pid])
        .whereType<Person>()
        .toList();
  }

  List<Person> getChildren(String id) {
    final person = _people[id];
    if (person == null) return [];
    return person.children
        .map((cid) => _people[cid])
        .whereType<Person>()
        .toList();
  }

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
    siblingIds.remove(id);
    return siblingIds.map((sid) => _people[sid]).whereType<Person>().toList();
  }

  Map<int, List<Person>> calculateGenerations() {
    final Map<int, List<Person>> generations = {};
    final Set<String> visited = {};
    final List<_QueueItem> queue = [];

    final root = _people[_mainPersonId];
    if (root == null) return {};

    queue.add(_QueueItem(root, 0));
    visited.add(root.id);

    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      final person = item.person;
      final gen = item.generation;

      generations.putIfAbsent(gen, () => []).add(person);

      for (var parentId in person.parents) {
        if (!visited.contains(parentId)) {
          final parent = _people[parentId];
          if (parent != null) {
            visited.add(parentId);
            queue.add(_QueueItem(parent, gen - 1));
          }
        }
      }

      for (var childId in person.children) {
        if (!visited.contains(childId)) {
          final child = _people[childId];
          if (child != null) {
            visited.add(childId);
            queue.add(_QueueItem(child, gen + 1));
          }
        }
      }

      if (person.spouseId != null && !visited.contains(person.spouseId)) {
        final spouse = _people[person.spouseId];
        if (spouse != null) {
          visited.add(person.spouseId!);
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
      gender: '男',
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

      if (members is List) {
        for (final item in members.whereType<Map>()) {
          final person = Person.fromMap(Map<String, dynamic>.from(item));
          if (person.id.isNotEmpty) {
            result[person.id] = person;
          }
        }
        return result;
      }

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
                  spouseId: person.spouseId,
                  giftHistory: person.giftHistory,
                );
        }
      });
      return result;
    }

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
    if (_people.containsKey('root')) return;
    _initData();
  }

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

    String? existingParentId;
    if (child.parents.isNotEmpty) {
      existingParentId = child.parents.first;
    }

    final parent = Person(
      id: newId,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      children: [childId],
      spouseId: existingParentId,
    );
    _people[newId] = parent;

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
        spouse: oldParent.spouse,
        spouseId: newId,
        giftHistory: oldParent.giftHistory,
      );
    }

    _people[childId] = Person(
      id: child.id,
      name: child.name,
      relationship: child.relationship,
      gender: child.gender,
      bio: child.bio,
      parents: [...child.parents, newId],
      children: child.children,
      spouse: child.spouse,
      spouseId: child.spouseId,
      giftHistory: child.giftHistory,
    );

    notifyListeners();
    saveToDisk();
  }

  void addSpouse(
    String personId,
    String name,
    String relationship,
    String bio,
    String gender,
  ) {
    final personA = _people[personId];
    if (personA == null) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();

    final personB = Person(
      id: newId,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      spouseId: personId,
      children: List<String>.from(personA.children),
    );
    _people[newId] = personB;

    _people[personId] = Person(
      id: personA.id,
      name: personA.name,
      relationship: personA.relationship,
      gender: personA.gender,
      bio: personA.bio,
      parents: personA.parents,
      children: personA.children,
      spouse: personA.spouse,
      spouseId: newId,
      giftHistory: personA.giftHistory,
    );

    for (final childId in personA.children) {
      final child = _people[childId];
      if (child != null) {
        _people[childId] = Person(
          id: child.id,
          name: child.name,
          relationship: child.relationship,
          gender: child.gender,
          bio: child.bio,
          parents: [...child.parents, newId],
          children: child.children,
          spouse: child.spouse,
          spouseId: child.spouseId,
          giftHistory: child.giftHistory,
        );
      }
    }

    notifyListeners();
    saveToDisk();
  }

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

    _people[parentId] = Person(
      id: parent.id,
      name: parent.name,
      relationship: parent.relationship,
      gender: parent.gender,
      bio: parent.bio,
      parents: parent.parents,
      children: [...parent.children, newId],
      spouse: parent.spouse,
      spouseId: parent.spouseId,
      giftHistory: parent.giftHistory,
    );

    notifyListeners();
    saveToDisk();
  }

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

    _people[personId] = Person(
      id: person.id,
      name: person.name,
      relationship: person.relationship,
      gender: person.gender,
      bio: person.bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      spouseId: person.spouseId,
      giftHistory: [...person.giftHistory, newGift],
    );

    notifyListeners();
    saveToDisk();
  }

  void updateGiftRecord(String personId, GiftRecord record) {
    final person = _people[personId];
    if (person == null) return;

    final updatedHistory = person.giftHistory.map((r) {
      return r.id == record.id ? record : r;
    }).toList();

    _people[personId] = Person(
      id: person.id,
      name: person.name,
      relationship: person.relationship,
      gender: person.gender,
      bio: person.bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      spouseId: person.spouseId,
      giftHistory: updatedHistory,
    );

    notifyListeners();
    saveToDisk();
  }

  void deleteGiftRecord(String personId, String recordId) {
    final person = _people[personId];
    if (person == null) return;

    _people[personId] = Person(
      id: person.id,
      name: person.name,
      relationship: person.relationship,
      gender: person.gender,
      bio: person.bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      spouseId: person.spouseId,
      giftHistory: person.giftHistory.where((r) => r.id != recordId).toList(),
    );

    notifyListeners();
    saveToDisk();
  }

  DateTime? getEventDefaultDate(String eventName) {
    final allRecords = _people.values
        .expand((p) => p.giftHistory)
        .where((r) => r.event == eventName)
        .toList();

    if (allRecords.isEmpty) return null;

    allRecords.sort((a, b) => b.date.compareTo(a.date));
    return allRecords.first.date;
  }

  void updatePerson(
    String id,
    String name,
    String relationship,
    String bio,
    String gender,
  ) {
    final person = _people[id];
    if (person == null) return;

    _people[id] = Person(
      id: person.id,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      parents: person.parents,
      children: person.children,
      spouse: person.spouse,
      spouseId: person.spouseId,
      giftHistory: person.giftHistory,
    );
    notifyListeners();
    saveToDisk();
  }

  void deletePerson(String id) {
    if (id == 'root') return;

    final person = _people[id];
    if (person == null) return;

    for (var parentId in person.parents) {
      final parent = _people[parentId];
      if (parent != null) {
        _people[parentId] = Person(
          id: parent.id,
          name: parent.name,
          relationship: parent.relationship,
          gender: parent.gender,
          bio: parent.bio,
          parents: parent.parents,
          children: parent.children.where((cid) => cid != id).toList(),
          spouse: parent.spouse,
          spouseId: parent.spouseId,
          giftHistory: parent.giftHistory,
        );
      }
    }

    for (var childId in person.children) {
      final child = _people[childId];
      if (child != null) {
        _people[childId] = Person(
          id: child.id,
          name: child.name,
          relationship: child.relationship,
          gender: child.gender,
          bio: child.bio,
          parents: child.parents.where((pid) => pid != id).toList(),
          children: child.children,
          spouse: child.spouse,
          spouseId: child.spouseId,
          giftHistory: child.giftHistory,
        );
      }
    }

    for (var entry in _people.entries.toList()) {
      final p = entry.value;
      if (p.spouseId == id || p.spouse == id) {
        _people[entry.key] = Person(
          id: p.id,
          name: p.name,
          relationship: p.relationship,
          gender: p.gender,
          bio: p.bio,
          parents: p.parents,
          children: p.children,
          spouse: p.spouse == id ? null : p.spouse,
          spouseId: p.spouseId == id ? null : p.spouseId,
          giftHistory: p.giftHistory,
        );
      }
    }

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
