import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/election.dart';
import '../models/candidate.dart';
import '../models/vote.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User operations
  Future<void> createUser(User user) async {
    await _db.collection('users').doc(user.id).set(user.toFirestore());
  }

  Future<User?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      return User.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateUser(User user) async {
    await _db.collection('users').doc(user.id).update(user.toFirestore());
  }

  // Election operations
  Future<String> createElection(Election election) async {
    final docRef = await _db.collection('election_requests').add(election.toFirestore());
    return docRef.id;
  }

  Future<Election?> getElection(String electionId) async {
    final doc = await _db.collection('election_requests').doc(electionId).get();
    if (doc.exists) {
      return Election.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<Election>> getElectionsStream({
    String? university,
    String? department,
    // When true, include pending election requests (for admin review).
    bool adminView = false,
  }) {
  debugPrint('Getting elections stream for university: $university, department: $department, adminView: $adminView');
    
    try {
      // If no filters, just get all elections (simplest query)
      if (university == null && department == null) {
  debugPrint('Fetching ALL elections (no filters)');
        final coll = _db.collection('election_requests');
        // If not admin view, only return approved/active elections.
        final Query baseQuery = adminView
            ? coll
            : coll.where('status', whereIn: [
                'approved',
                'active',
                ElectionStatus.active.toString(),
              ]);

        return baseQuery.snapshots().map((snapshot) {
          debugPrint('All elections snapshot received: ${snapshot.docs.length} documents');
          if (snapshot.docs.isEmpty) {
            debugPrint('WARNING: No election documents found in Firestore!');
          }
          final elections = snapshot.docs.map((doc) {
            try {
              debugPrint('Election doc: ${doc.id}');
              final data = doc.data() as Map<String, dynamic>?;
              debugPrint('  Title: ${data?['title'] ?? ''}');
              debugPrint('  University: ${data?['university'] ?? ''}');
              debugPrint('  Department: ${data?['department'] ?? ''}');
              return Election.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing election ${doc.id}: $e');
              rethrow;
            }
          }).toList();
          debugPrint('Successfully parsed ${elections.length} elections');
          return elections;
        });
      }
      
  // With filters - build query
  Query query = _db.collection('election_requests');
      
      // Add filters first
      if (university != null) {
        query = query.where('university', isEqualTo: university);
      }
      
      if (department != null) {
        query = query.where('department', isEqualTo: department);
      }
      
      // Then add ordering - this might require a composite index
      query = query.orderBy('createdAt', descending: true);

      // If not admin view, apply status filter to the query
      if (!adminView) {
        query = query.where('status', whereIn: [
          'approved',
          'active',
          ElectionStatus.active.toString(),
        ]);
      }

      return query.snapshots().map((snapshot) {
  debugPrint('Elections snapshot received: ${snapshot.docs.length} documents');
        final elections = snapshot.docs.map((doc) {
          try {
            debugPrint('Election doc: ${doc.id}, data: ${doc.data()}');
            return Election.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing election ${doc.id}: $e');
            rethrow;
          }
        }).toList();
  debugPrint('Parsed ${elections.length} elections');
        return elections;
      }).handleError((error) {
  debugPrint('Stream error: $error');
        // If it's an index error, try without ordering
        if (error.toString().contains('index')) {
          debugPrint('Composite index required. Fetching without ordering...');
          return getElectionsStreamWithoutOrdering(
            university: university,
            department: department,
          );
        }
        throw error;
      });
    } catch (e) {
  debugPrint('Error setting up elections stream: $e');
      rethrow;
    }
  }
  
  Stream<List<Election>> getElectionsStreamWithoutOrdering({
    String? university,
    String? department,
  }) {
  debugPrint('Getting elections stream WITHOUT ordering');
    
    Query query = _db.collection('election_requests');
    
    if (university != null) {
      query = query.where('university', isEqualTo: university);
    }
    
    if (department != null) {
      query = query.where('department', isEqualTo: department);
    }

    return query.snapshots().map((snapshot) {
  debugPrint('Elections snapshot (no order) received: ${snapshot.docs.length} documents');
      final elections = snapshot.docs.map((doc) => Election.fromFirestore(doc)).toList();
      // Sort in memory by createdAt
      elections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  debugPrint('Parsed and sorted ${elections.length} elections');
      return elections;
    });
  }

  Future<void> updateElection(Election election) async {
    await _db.collection('election_requests').doc(election.id).update(election.toFirestore());
  }

  Future<void> deleteElection(String electionId) async {
    await _db.collection('election_requests').doc(electionId).delete();
  }

  // Candidate operations
  Future<String> addCandidate(Candidate candidate) async {
    final docRef = await _db.collection('candidates').add(candidate.toFirestore());
    
    // Add candidate ID to election
    await _db.collection('election_requests').doc(candidate.electionId).update({
      'candidateIds': FieldValue.arrayUnion([docRef.id])
    });
    
    return docRef.id;
  }

  Future<List<Candidate>> getCandidates(String electionId) async {
    final snapshot = await _db
        .collection('candidates')
        .where('electionId', isEqualTo: electionId)
        .get();
    
    return snapshot.docs.map((doc) => Candidate.fromFirestore(doc)).toList();
  }

  Stream<List<Candidate>> getCandidatesStream(String electionId) {
    return _db
        .collection('candidates')
        .where('electionId', isEqualTo: electionId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Candidate.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateCandidate(Candidate candidate) async {
    await _db.collection('candidates').doc(candidate.id).update(candidate.toFirestore());
  }

  Future<void> deleteCandidate(String candidateId, String electionId) async {
    await _db.collection('candidates').doc(candidateId).delete();
    
    // Remove candidate ID from election
    await _db.collection('election_requests').doc(electionId).update({
      'candidateIds': FieldValue.arrayRemove([candidateId])
    });
  }

  // Voting operations
  Future<bool> castVote(Vote vote) async {
    try {
      // Check if user has already voted in this election
      final existingVote = await _db
          .collection('votes')
          .where('userId', isEqualTo: vote.userId)
          .where('electionId', isEqualTo: vote.electionId)
          .get();

      if (existingVote.docs.isNotEmpty) {
        return false; // User has already voted
      }

      // Use batch to ensure atomicity
      final batch = _db.batch();

      // Add the vote
      final voteRef = _db.collection('votes').doc();
      batch.set(voteRef, vote.toFirestore());

      // Update election vote count
      final electionRef = _db.collection('election_requests').doc(vote.electionId);
      batch.update(electionRef, {
        'votes.${vote.candidateId}': FieldValue.increment(1)
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error casting vote: $e');
      return false;
    }
  }

  Future<bool> hasUserVoted(String userId, String electionId) async {
    final snapshot = await _db
        .collection('votes')
        .where('userId', isEqualTo: userId)
        .where('electionId', isEqualTo: electionId)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }

  Stream<List<Vote>> getUserVotesStream(String userId) {
    return _db
        .collection('votes')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Vote.fromFirestore(doc)).toList();
    });
  }

  Stream<Map<String, int>> getVoteCountsStream(String electionId) {
    return _db
        .collection('election_requests')
        .doc(electionId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return Map<String, int>.from(data['votes'] ?? {});
      }
      return <String, int>{};
    });
  }

  /// Stream that returns a list of elections with basic metadata and their
  /// current vote counts. Each map contains { 'id', 'name', 'votes' }.
  Stream<List<Map<String, dynamic>>> getAllElectionsWithVotesStream() {
    return _db.collection('election_requests').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['title'] ?? data['name'] ?? 'Unnamed Election',
          'votes': Map<String, int>.from(data['votes'] ?? {}),
        };
      }).toList();
    });
  }

  // Election request operations
  Future<String> createElectionRequest(ElectionRequest request) async {
    final docRef = await _db.collection('election_requests').add(request.toFirestore());
    return docRef.id;
  }

  Stream<List<ElectionRequest>> getElectionRequestsStream() {
    return _db
        .collection('election_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ElectionRequest.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateElectionRequestStatus(
    String requestId,
    String status, {
    String? adminResponse,
  }) async {
    final updateData = {
      'status': status,
      if (adminResponse != null) 'adminResponse': adminResponse,
    };
    
    await _db.collection('election_requests').doc(requestId).update(updateData);
  }

  // Analytics and reporting
  Future<Map<String, dynamic>> getElectionStats(String electionId) async {
    final election = await getElection(electionId);
    if (election == null) return {};

    final candidates = await getCandidates(electionId);
  final totalVotes = election.votes.values.fold(0, (acc, votes) => acc + votes);

    return {
      'totalVotes': totalVotes,
      'candidateCount': candidates.length,
      'voteCounts': election.votes,
      'winnerCandidateId': election.votes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key,
    };
  }
}