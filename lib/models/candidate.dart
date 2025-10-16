import 'package:cloud_firestore/cloud_firestore.dart';

class Candidate {
  final String id;
  final String userId;
  final String electionId;
  final String name;
  final String email;
  final String university;
  final String department;
  final String manifesto;
  final String? profileImageUrl;
  final DateTime createdAt;

  Candidate({
    required this.id,
    required this.userId,
    required this.electionId,
    required this.name,
    required this.email,
    required this.university,
    required this.department,
    this.manifesto = '',
    this.profileImageUrl,
    required this.createdAt,
  });

  factory Candidate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Candidate(
      id: doc.id,
      userId: data['userId'] ?? '',
      electionId: data['electionId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      university: data['university'] ?? '',
      department: data['department'] ?? '',
      manifesto: data['manifesto'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'electionId': electionId,
      'name': name,
      'email': email,
      'university': university,
      'department': department,
      'manifesto': manifesto,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}