class Person {
  final String id;
  final String name;
  final String relationship;
  final String gender;
  final String bio;
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

  // 必须叫这个名字，且必须是 factory
  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      relationship: map['relationship']?.toString() ?? '',
      gender: map['gender']?.toString() ?? '男',
      bio: map['bio']?.toString() ?? '',
      parents: List<String>.from(map['parents'] ?? []),
      children: List<String>.from(map['children'] ?? []),
      spouse: map['spouse']?.toString(),
    );
  }

  // 必须叫这个名字
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'gender': gender,
      'bio': bio,
      'parents': parents,
      'children': children,
      'spouse': spouse,
    };
  }
}