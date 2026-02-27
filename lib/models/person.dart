class Person {
  final String id;
  final String name;
  final String relationship; // 称呼
  final String gender;
  final String bio; // 简介
  final List<String> parents;
  final List<String> children;
  final String? spouse;

  Person({
    required this.id,
    required this.name,
    required this.relationship,
    required this.gender,
    required this.bio,
    this.parents = const [],
    this.children = const [],
    this.spouse,
  });

  // Adding a method to help with debugging/display
  @override
  String toString() {
    return 'Person(id: $id, name: $name, relationship: $relationship)';
  }
}
