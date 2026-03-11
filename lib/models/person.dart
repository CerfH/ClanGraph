class GiftRecord {
  final String id;
  final double amount;
  final String event;
  final DateTime date;

  GiftRecord({
    required this.id,
    required this.amount,
    required this.event,
    required this.date,
  });

  factory GiftRecord.fromMap(Map<String, dynamic> map) {
    final amountValue = map['amount'];
    return GiftRecord(
      id: map['id']?.toString() ?? '',
      amount: amountValue is num
          ? amountValue.toDouble()
          : double.tryParse(amountValue?.toString() ?? '') ?? 0.0,
      event: map['event']?.toString() ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'event': event,
      'date': date.toIso8601String(),
    };
  }
}

class Person {
  final String id;
  final String name;
  final String relationship;
  final String gender;
  final String bio;
  final List<String> parents;
  final List<String> children;
  final String? spouse;
  final List<GiftRecord> giftHistory;

  Person({
    required this.id,
    required this.name,
    required this.relationship,
    required this.gender,
    required this.bio,
    this.parents = const [],
    this.children = const [],
    this.spouse,
    this.giftHistory = const [],
  });

  // 必须叫这个名字，且必须是 factory
  factory Person.fromMap(Map<String, dynamic> map) {
    final rawParents = map['parents'];
    final rawChildren = map['children'];
    final rawGiftHistory = map['giftHistory'];
    final spouseRaw = map['spouse'];

    return Person(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      relationship: map['relationship']?.toString() ?? '',
      gender: map['gender']?.toString() ?? '男',
      bio: map['bio']?.toString() ?? '',
      parents: rawParents is List
          ? rawParents.map((e) => e.toString()).toList()
          : const [],
      children: rawChildren is List
          ? rawChildren.map((e) => e.toString()).toList()
          : const [],
      spouse: spouseRaw == null || spouseRaw.toString().isEmpty
          ? null
          : spouseRaw.toString(),
      giftHistory: rawGiftHistory is List
          ? rawGiftHistory
                .whereType<Map>()
                .map((e) => GiftRecord.fromMap(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
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
      'giftHistory': giftHistory.map((e) => e.toMap()).toList(),
    };
  }
}
