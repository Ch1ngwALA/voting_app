import 'package:cloud_firestore/cloud_firestore.dart';

enum ElectionStatus { pending, active, completed, cancelled }

class Election {
  final String id;
  final String name;
  final String description;
  final String university;
  final String department;
  final DateTime startDate;
  final DateTime endDate;
  final ElectionStatus status;
  final String createdBy;
  final DateTime createdAt;
  final List<String> candidateIds;
  final Map<String, int> votes; // candidateId -> vote count

  Election({
    required this.id,
    required this.name,
    required this.description,
    required this.university,
    required this.department,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.candidateIds = const [],
    this.votes = const {},
  });

  factory Election.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle both old format (electionName) and new format (name)
    final name = data['name'] ?? data['electionName'] ?? '';
    
    // Handle both old format (proposedStartDate) and new format (startDate)
    final startDateTimestamp = data['startDate'] ?? data['proposedStartDate'];
    final endDateTimestamp = data['endDate'] ?? data['proposedEndDate'];
    
    // Parse dates with null safety
    final startDate = startDateTimestamp != null 
        ? (startDateTimestamp as Timestamp).toDate()
        : DateTime.now();
    final endDate = endDateTimestamp != null
        ? (endDateTimestamp as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 7));
    
    // Handle both old format (approved/pending) and new format (ElectionStatus enum)
    ElectionStatus statusValue;
    final statusData = data['status'];
    if (statusData == 'approved') {
      statusValue = ElectionStatus.active;
    } else if (statusData == 'pending') {
      statusValue = ElectionStatus.pending;
    } else if (statusData == 'cancelled') {
      statusValue = ElectionStatus.cancelled;
    } else if (statusData == 'completed') {
      statusValue = ElectionStatus.completed;
    } else {
      // Try to parse as enum string
      statusValue = ElectionStatus.values.firstWhere(
        (status) => status.toString() == statusData,
        orElse: () => ElectionStatus.pending,
      );
    }
    
    // Handle both old format (requesterId) and new format (createdBy)
    final createdBy = data['createdBy'] ?? data['requesterId'] ?? '';
    
    return Election(
      id: doc.id,
      name: name,
      description: data['description'] ?? '',
      university: data['university'] ?? '',
      department: data['department'] ?? '',
      startDate: startDate,
      endDate: endDate,
      status: statusValue,
      createdBy: createdBy,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      candidateIds: List<String>.from(data['candidateIds'] ?? []),
      votes: Map<String, int>.from(data['votes'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'university': university,
      'department': department,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.toString(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'candidateIds': candidateIds,
      'votes': votes,
    };
  }

  bool get isActive {
    final now = DateTime.now();
    // If the election is configured to start and end on the same calendar
    // day, treat startDate/endDate as full timestamps (time-bound voting).
    // Otherwise, treat multi-day elections as active for entire calendar days
    // inclusive between start and end.
    final sameDay = startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    if (sameDay) {
      // Use precise timestamps (inclusive).
      return status == ElectionStatus.active &&
          !now.isBefore(startDate) &&
          !now.isAfter(endDate);
    }

    // Multi-day election: active from start of startDate to end of endDate.
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return status == ElectionStatus.active && !now.isBefore(start) && !now.isAfter(end);
  }

  bool get hasEnded {
    final now = DateTime.now();
    final sameDay = startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    if (sameDay) {
      // Ended once the precise end timestamp passes.
      return now.isAfter(endDate) || status == ElectionStatus.completed;
    }

    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return now.isAfter(end) || status == ElectionStatus.completed;
  }
}