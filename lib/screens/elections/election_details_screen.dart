import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/election.dart';
import '../../models/candidate.dart';
import '../../models/user.dart';

class ElectionDetailsScreen extends StatelessWidget {
  final String electionId;

  const ElectionDetailsScreen({
    super.key,
    required this.electionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Election Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to elections list
            context.go('/elections');
          },
        ),
        actions: [
          // Show an "Activate" button for admins when the election is not active and not ended
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return FutureBuilder<Election?>(
                future: Provider.of<FirestoreService>(context, listen: false)
                    .getElection(electionId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || authService.currentUser == null) {
                    return const SizedBox.shrink();
                  }

                  final election = snapshot.data!;
                  final user = authService.currentUser!;

                  // If admin, show Activate (when appropriate) and Delete buttons
                  if (user.role == UserRole.admin) {
                    final List<Widget> actions = [];

                    if (!election.isActive && !election.hasEnded) {
                      actions.add(IconButton(
                        tooltip: 'Activate Election',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _confirmActivate(context, election),
                      ));
                    }

                    // Delete button always available to admins
                    actions.add(IconButton(
                      tooltip: 'Delete Election',
                      icon: const Icon(Icons.delete_forever),
                      onPressed: () => _confirmDelete(context, election),
                    ));

                    return Row(mainAxisSize: MainAxisSize.min, children: actions);
                  }

                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Election?>(
        future: Provider.of<FirestoreService>(context, listen: false)
            .getElection(electionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Error loading election details'),
            );
          }

          final election = snapshot.data!;
          return _buildElectionDetails(context, election);
        },
      ),
      floatingActionButton: Consumer<AuthService>(
        builder: (context, authService, child) {
          return FutureBuilder<Election?>(
            future: Provider.of<FirestoreService>(context, listen: false)
                .getElection(electionId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || authService.currentUser == null) {
                return const SizedBox.shrink();
              }

              final election = snapshot.data!;
              final user = authService.currentUser!;

              // Show "Vote Now" button for students during active elections
              if (election.isActive && user.role == UserRole.student) {
                return FloatingActionButton.extended(
                  onPressed: () => context.go('/vote/$electionId'),
                  icon: const Icon(Icons.how_to_vote),
                  label: const Text('Vote Now'),
                );
              }

              // Show "Add Candidate" button for admins, but only if election hasn't ended
              if (user.role == UserRole.admin) {
                if (election.hasEnded) {
                  // Return a disabled FAB with tooltip explaining why
                  return const Tooltip(
                    message: 'Cannot add candidates after the election has ended',
                    child: FloatingActionButton.extended(
                      onPressed: null,
                      icon: Icon(Icons.person_add),
                      label: Text('Add Candidate'),
                      backgroundColor: Colors.grey,
                    ),
                  );
                }

                return FloatingActionButton.extended(
                  onPressed: () => _showAddCandidateDialog(context, electionId),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Candidate'),
                  backgroundColor: Colors.green,
                );
              }

              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Widget _buildElectionDetails(BuildContext context, Election election) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Election Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    election.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (election.description.isNotEmpty) ...[
                    Text(
                      election.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Status indicator
                  _buildStatusChip(context, election),
                  const SizedBox(height: 16),

                  // Election details
                  _buildDetailRow(
                    context,
                    'University',
                    election.university,
                    Icons.school,
                  ),
                  _buildDetailRow(
                    context,
                    'Department',
                    election.department,
                    Icons.business,
                  ),
                  _buildDetailRow(
                    context,
                    'Start Date',
                    '${election.startDate.day}/${election.startDate.month}/${election.startDate.year}',
                    Icons.calendar_today,
                  ),
                  _buildDetailRow(
                    context,
                    'End Date',
                    '${election.endDate.day}/${election.endDate.month}/${election.endDate.year}',
                    Icons.event,
                  ),
                  _buildDetailRow(
                    context,
                    'Total Votes',
                    '${election.votes.values.fold(0, (acc, votes) => acc + votes)}',
                    Icons.how_to_vote,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Candidates Section
          Text(
            'Candidates',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<Candidate>>(
            stream: Provider.of<FirestoreService>(context)
                .getCandidatesStream(electionId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              final candidates = snapshot.data ?? [];

              if (candidates.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No candidates yet'),
                    ),
                  ),
                );
              }

              return Column(
                children: candidates
                    .map((candidate) => _buildCandidateCard(
                          context,
                          candidate,
                          election.votes[candidate.id] ?? 0,
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          // Real-time Results
          if (election.isActive || election.hasEnded) ...[
            Text(
              'Live Results',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<Map<String, int>>(
              stream: Provider.of<FirestoreService>(context)
                  .getVoteCountsStream(electionId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final voteCounts = snapshot.data!;
                final totalVotes = voteCounts.values.fold(0, (acc, votes) => acc + votes);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Total Votes: $totalVotes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        if (totalVotes > 0) ...[
                          ...voteCounts.entries.map((entry) {
                            final percentage = (entry.value / totalVotes * 100);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text('${entry.value} votes'),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[300],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, Election election) {
    Color color;
    String text;
    IconData icon;

    if (election.hasEnded) {
      color = Colors.grey;
      text = 'Completed';
      icon = Icons.done;
    } else if (election.isActive) {
      color = Colors.green;
      text = 'Active - Voting Open';
      icon = Icons.circle;
    } else {
      color = Colors.orange;
      text = 'Upcoming';
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
  color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(
    BuildContext context,
    Candidate candidate,
    int voteCount,
  ) {
    // Check if profile image URL is valid
    final hasValidImageUrl = candidate.profileImageUrl != null &&
        candidate.profileImageUrl!.isNotEmpty &&
        candidate.profileImageUrl != 'none' &&
        Uri.tryParse(candidate.profileImageUrl!)?.hasScheme == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: hasValidImageUrl
              ? NetworkImage(candidate.profileImageUrl!)
              : null,
          backgroundColor: hasValidImageUrl ? null : Colors.blue[300],
          child: !hasValidImageUrl
              ? Text(
                  candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          candidate.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.email),
            if (candidate.manifesto.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                candidate.manifesto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          '$voteCount votes',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        isThreeLine: candidate.manifesto.isNotEmpty,
      ),
    );
  }

  void _showAddCandidateDialog(BuildContext context, String electionId) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final manifestoController = TextEditingController();

    // Get election details
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final election = await firestoreService.getElection(electionId);
    final currentUser = authService.currentUser;

    if (election == null || currentUser == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not load election or user data'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Candidate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Candidate Name *',
                  hintText: 'Enter full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'candidate@example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: manifestoController,
                decoration: const InputDecoration(
                  labelText: 'Manifesto/Bio (Optional)',
                  hintText: 'Brief description of candidate',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name and Email are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final candidate = Candidate(
                  id: '', // Will be set by Firestore
                  userId: currentUser.id, // Admin who added the candidate
                  electionId: electionId,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  university: election.university,
                  department: election.department,
                  manifesto: manifestoController.text.trim(),
                  profileImageUrl: null, // No profile image by default
                  createdAt: DateTime.now(),
                );

                await firestoreService.addCandidate(candidate);

                if (!context.mounted) return;
                
                // Close the dialog
                Navigator.of(dialogContext).pop();
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Candidate added successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );

                // No need to navigate - the StreamBuilder will automatically refresh
              } catch (e) {
                if (!context.mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding candidate: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text('Add Candidate'),
          ),
        ],
      ),
    );
  }

  void _confirmActivate(BuildContext context, Election election) async {
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Activate Election'),
        content: Text('Are you sure you want to activate "${election.name}"? This will open voting for students.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // The called method checks context.mounted before using the context after awaits.
      // Analyzer flags passing BuildContext across async gaps here; it's safe because
      // we validate mounted inside `_activateElection` before any context use.
      // ignore: use_build_context_synchronously
      await _activateElection(context, election);
    }
  }

  Future<void> _activateElection(BuildContext context, Election election) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    try {
      // Create a new Election object with status active and ensure startDate is now if it was in the future
      final now = DateTime.now();
      final updatedElection = Election(
        id: election.id,
        name: election.name,
        description: election.description,
        university: election.university,
        department: election.department,
        startDate: election.startDate.isAfter(now) ? now : election.startDate,
        endDate: election.endDate,
        status: ElectionStatus.active,
        createdBy: election.createdBy,
        createdAt: election.createdAt,
        candidateIds: election.candidateIds,
        votes: election.votes,
      );

      await firestoreService.updateElection(updatedElection);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Election activated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error activating election: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, Election election) async {
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Election'),
        content: Text('Are you sure you want to delete the election "${election.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // `_deleteElection` validates context.mounted before any context-based calls.
      // ignore: use_build_context_synchronously
      await _deleteElection(context, election.id);
    }
  }

  Future<void> _deleteElection(BuildContext context, String electionId) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    try {
      await firestoreService.deleteElection(electionId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Election deleted'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to elections list
      context.go('/elections');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting election: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}