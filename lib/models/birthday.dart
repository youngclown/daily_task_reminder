class Birthday {
  final String? id;
  final String name;
  final DateTime date;
  final bool isLunar;
  final String? notes;
  final DateTime createdAt;

  Birthday({
    this.id,
    required this.name,
    required this.date,
    this.isLunar = false,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'isLunar': isLunar ? 1 : 0,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Birthday.fromMap(Map<String, dynamic> map) {
    return Birthday(
      id: map['id']?.toString(),
      name: map['name'],
      date: DateTime.parse(map['date']),
      isLunar: map['isLunar'] == 1,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Birthday copyWith({
    String? id,
    String? name,
    DateTime? date,
    bool? isLunar,
    String? notes,
    DateTime? createdAt,
  }) {
    return Birthday(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      isLunar: isLunar ?? this.isLunar,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
