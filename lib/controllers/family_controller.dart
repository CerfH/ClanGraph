import 'package:flutter/material.dart';
import '../models/person.dart';

class FamilyController extends ChangeNotifier {
  // Using a Map for O(1) access by ID
  final Map<String, Person> _people = {};
  final String _centerPersonId = 'root';
  String? _selectedPersonId;

  FamilyController() {
    _initData();
  }

  // Getters
  Person? get centerPerson => _people[_centerPersonId];
  Person? get selectedPerson => _selectedPersonId != null ? _people[_selectedPersonId] : null;
  List<Person> get allPeople => _people.values.toList();

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
    return person.parents.map((pid) => _people[pid]).whereType<Person>().toList();
  }

  // Helper to get children of a person
  List<Person> getChildren(String id) {
    final person = _people[id];
    if (person == null) return [];
    return person.children.map((cid) => _people[cid]).whereType<Person>().toList();
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
      bio: '这是我，家族图谱的中心。',
      parents: [],
      children: [],
    );
    _people['root'] = root;
  }

  // Add Parent
  void addParent(String childId, String name, String relationship, String bio, String gender) {
    final child = _people[childId];
    if (child == null) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final parent = Person(
      id: newId,
      name: name,
      relationship: relationship,
      gender: gender,
      bio: bio,
      children: [childId],
    );

    _people[newId] = parent;

    // Update child's parents list
    // We need to create a new Person object because fields are final
    final updatedChild = Person(
      id: child.id,
      name: child.name,
      relationship: child.relationship,
      gender: child.gender,
      bio: child.bio,
      parents: [...child.parents, newId],
      children: child.children,
      spouse: child.spouse,
    );
    _people[childId] = updatedChild;

    notifyListeners();
  }

  // Add Child
  void addChild(String parentId, String name, String relationship, String bio, String gender) {
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
    );
    _people[parentId] = updatedParent;

    notifyListeners();
  }

  // Update Person
  void updatePerson(String id, String name, String relationship, String bio, String gender) {
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
    );
    _people[id] = updatedPerson;
    notifyListeners();
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
  }
}

class _QueueItem {
  final Person person;
  final int generation;

  _QueueItem(this.person, this.generation);
}
