import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, student }

class User {
  final String id;
  final String email;
  final String name;
  final String university;
  final String department;
  final UserRole role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.university,
    required this.department,
    required this.role,
    required this.createdAt,
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      university: data['university'] ?? '',
      department: data['department'] ?? '',
      role: UserRole.values.firstWhere(
        (role) => role.toString() == data['role'],
        orElse: () => UserRole.student,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'university': university,
      'department': department,
      'role': role.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}