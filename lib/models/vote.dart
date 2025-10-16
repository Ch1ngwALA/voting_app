import 'package:cloud_firestore/cloud_firestore.dart';

class Vote {
  final String id;
  final String userId;
  final String electionId;
  final String candidateId;
  final DateTime timestamp;

  Vote({
    required this.id,
    required this.userId,
    required this.electionId,
    required this.candidateId,
    required this.timestamp,
  });

  factory Vote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vote(
      id: doc.id,
      userId: data['userId'] ?? '',
      electionId: data['electionId'] ?? '',
      candidateId: data['candidateId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'electionId': electionId,
      'candidateId': candidateId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class ElectionRequest {
  final String id;
  final String requesterId;
  final String electionName;
  final String description;
  final String university;
  final String department;
  final DateTime proposedStartDate;
  final DateTime proposedEndDate;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final String? adminResponse;

  ElectionRequest({
    required this.id,
    required this.requesterId,
    required this.electionName,
    required this.description,
    required this.university,
    required this.department,
    required this.proposedStartDate,
    required this.proposedEndDate,
    this.status = 'pending',
    required this.createdAt,
    this.adminResponse,
  });

  factory ElectionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ElectionRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      electionName: data['electionName'] ?? '',
      description: data['description'] ?? '',
      university: data['university'] ?? '',
      department: data['department'] ?? '',
      proposedStartDate: (data['proposedStartDate'] as Timestamp).toDate(),
      proposedEndDate: (data['proposedEndDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      adminResponse: data['adminResponse'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'electionName': electionName,
      'description': description,
      'university': university,
      'department': department,
      'proposedStartDate': Timestamp.fromDate(proposedStartDate),
      'proposedEndDate': Timestamp.fromDate(proposedEndDate),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'adminResponse': adminResponse,
    };
  }
}