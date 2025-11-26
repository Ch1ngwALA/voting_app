import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../models/election.dart';
import '../../models/candidate.dart';

class ResultsOverviewScreen extends StatelessWidget {
  const ResultsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              // Fallback: ensure we return to the student dashboard
              router.go('/student-dashboard');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Live Results'),
      ),
      body: StreamBuilder<List<Election>>(
        stream: firestore.getElectionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final elections = snapshot.data ?? [];
          if (elections.isEmpty) {
            return const Center(child: Text('No elections found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: elections.length,
            itemBuilder: (context, index) {
              final election = elections[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(election.name)),
                      _buildStatusChip(election),
                    ],
                  ),
                  subtitle: Text(election.description.isNotEmpty ? election.description : ''),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<Map<String, int>>(
                            stream: firestore.getVoteCountsStream(election.id),
                            builder: (context, voteSnapshot) {
                              if (!voteSnapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final voteCounts = voteSnapshot.data!;
                              final totalVotes = voteCounts.values.fold<int>(0, (s, v) => s + v);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total votes: $totalVotes', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 8),
                                  StreamBuilder<List<Candidate>>(
                                    stream: firestore.getCandidatesStream(election.id),
                                    builder: (context, candSnapshot) {
                                      if (!candSnapshot.hasData) {
                                        return const Center(child: CircularProgressIndicator());
                                      }

                                      final candidates = candSnapshot.data!;
                                      if (candidates.isEmpty) {
                                        return const Text('No candidates');
                                      }

                                      return Column(
                                        children: candidates.map((c) {
                                          final votes = voteCounts[c.id] ?? 0;
                                          final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(c.name, style: Theme.of(context).textTheme.bodyLarge),
                                                      const SizedBox(height: 6),
                                                      LinearProgressIndicator(
                                                        value: percent,
                                                        backgroundColor: Colors.grey[300],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                SizedBox(
                                                  width: 64,
                                                  child: Text('$votes', textAlign: TextAlign.right),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/election/${election.id}'),
                              child: const Text('View Election'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(Election election) {
    Color color;
    String text;

    if (election.hasEnded) {
      color = Colors.grey;
      text = 'Completed';
    } else if (election.isActive) {
      color = Colors.green;
      text = 'Active';
    } else {
      color = Colors.orange;
      text = 'Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // withOpacity is deprecated; use withAlpha to avoid precision loss warnings
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

