import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/election.dart';
import '../../models/candidate.dart';
import '../../models/vote.dart';

class VotingScreen extends StatefulWidget {
  final String electionId;

  const VotingScreen({
    super.key,
    required this.electionId,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  String? selectedCandidateId;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast Your Vote'),
      ),
      body: FutureBuilder<Election?>(
        future: Provider.of<FirestoreService>(context, listen: false)
            .getElection(widget.electionId),
        builder: (context, electionSnapshot) {
          if (electionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (electionSnapshot.hasError || !electionSnapshot.hasData) {
            return const Center(
              child: Text('Error loading election'),
            );
          }

          final election = electionSnapshot.data!;

          if (!election.isActive) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Voting is not active for this election',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/election/${widget.electionId}'),
                    child: const Text('View Election Details'),
                  ),
                ],
              ),
            );
          }

          return Consumer<AuthService>(
            builder: (context, authService, child) {
              final user = authService.currentUser;
              if (user == null) {
                return const Center(
                  child: Text('Please login to vote'),
                );
              }

              return FutureBuilder<bool>(
                future: Provider.of<FirestoreService>(context, listen: false)
                    .hasUserVoted(user.id, widget.electionId),
                builder: (context, hasVotedSnapshot) {
                  if (hasVotedSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (hasVotedSnapshot.data == true) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'You have already voted in this election',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thank you for participating!',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.go('/election/${widget.electionId}'),
                            child: const Text('View Results'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildVotingInterface(context, election, user.id);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVotingInterface(BuildContext context, Election election, String userId) {
    return Column(
      children: [
        // Election Info Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withAlpha((0.1 * 255).round()),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                election.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select one candidate to cast your vote',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Candidates List
        Expanded(
          child: StreamBuilder<List<Candidate>>(
            stream: Provider.of<FirestoreService>(context)
                .getCandidatesStream(widget.electionId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final candidates = snapshot.data ?? [];

              if (candidates.isEmpty) {
                return const Center(
                  child: Text('No candidates available'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final candidate = candidates[index];
                  return _buildCandidateCard(candidate);
                },
              );
            },
          ),
        ),

        // Vote Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedCandidateId != null && !isLoading
                    ? () => _castVote(userId)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Cast Vote',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(Candidate candidate) {
    final isSelected = selectedCandidateId == candidate.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedCandidateId = candidate.id;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                    width: 2,
                  ),
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Profile image
              Builder(
                builder: (context) {
                  // Check if profile image URL is valid
                  final hasValidImageUrl = candidate.profileImageUrl != null &&
                      candidate.profileImageUrl!.isNotEmpty &&
                      candidate.profileImageUrl != 'none' &&
                      Uri.tryParse(candidate.profileImageUrl!)?.hasScheme == true;

                  return CircleAvatar(
                    radius: 30,
                    backgroundImage: hasValidImageUrl
                        ? NetworkImage(candidate.profileImageUrl!)
                        : null,
                    backgroundColor: hasValidImageUrl ? null : Colors.blue[300],
                    child: !hasValidImageUrl
                        ? Text(
                            candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(width: 16),

              // Candidate info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      candidate.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (candidate.manifesto.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        candidate.manifesto,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _castVote(String userId) async {
    if (selectedCandidateId == null) return;

    setState(() {
      isLoading = true;
    });

    final vote = Vote(
      id: '', // Will be set by Firestore
      userId: userId,
      electionId: widget.electionId,
      candidateId: selectedCandidateId!,
      timestamp: DateTime.now(),
    );

    final success = await Provider.of<FirestoreService>(context, listen: false)
        .castVote(vote);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (success) {
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Vote Cast Successfully!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              Text('Your vote has been recorded successfully. Thank you for participating!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Close dialog and navigate back to previous screen if possible.
                Navigator.of(context).pop();
                final router = GoRouter.of(context);
                if (router.canPop()) {
                  router.pop();
                } else {
                  // Fallback: go to student dashboard
                  router.go('/student-dashboard');
                }
              },
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/election/${widget.electionId}');
              },
              child: const Text('View Results'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cast vote. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}