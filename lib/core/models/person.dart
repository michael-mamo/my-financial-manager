class Person {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? note;

  const Person({this.id, required this.name, this.phone, this.email, this.note});

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'note': note,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      note: map['note'] as String?,
    );
  }
}
