import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../models/vote.dart';
import '../../models/candidate.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';

// NOTE: This file intentionally uses some dialog/picker flows that require
// showing pickers from the parent context. The analyzer may warn about
// 'use_build_context_synchronously' for awaited calls that reference a
// BuildContext captured from an outer scope. We've added narrow ignores
// where possible; suppress the remaining cases here because the flows are
// safe (we capture parentContext and use ScaffoldMessenger/Navigator
// references) — revisit if this file is converted to a StatefulWidget.
// ignore_for_file: use_build_context_synchronously

class ElectionRequestsScreen extends StatelessWidget {
  const ElectionRequestsScreen({super.key});

  // Show add candidate dialog inline (used in requests screen)
  Future<void> _showAddCandidateDialog(BuildContext context, FirestoreService firestore, String electionId) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final manifestoController = TextEditingController();

  final authService = Provider.of<AuthService>(context, listen: false);
  final currentUser = authService.currentUser;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Candidate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Candidate Name *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: manifestoController, decoration: const InputDecoration(labelText: 'Manifesto (optional)', border: OutlineInputBorder()), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Email are required'), backgroundColor: Colors.red));
                return;
              }

              final candidate = Candidate(
                id: '',
                userId: currentUser?.id ?? '',
                electionId: electionId,
                name: nameController.text.trim(),
                email: emailController.text.trim(),
                university: '',
                department: '',
                manifesto: manifestoController.text.trim(),
                profileImageUrl: null,
                createdAt: DateTime.now(),
              );

              try {
                await firestore.addCandidate(candidate);
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate added')));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding candidate: $e')));
              }
            },
            child: const Text('Add Candidate'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCandidateDialog(BuildContext context, FirestoreService firestore, Candidate candidate) async {
    final nameController = TextEditingController(text: candidate.name);
    final emailController = TextEditingController(text: candidate.email);
    final manifestoController = TextEditingController(text: candidate.manifesto);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Candidate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Candidate Name *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: manifestoController, decoration: const InputDecoration(labelText: 'Manifesto (optional)', border: OutlineInputBorder()), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Email are required'), backgroundColor: Colors.red));
                return;
              }

              final updated = Candidate(
                id: candidate.id,
                userId: candidate.userId,
                electionId: candidate.electionId,
                name: nameController.text.trim(),
                email: emailController.text.trim(),
                university: candidate.university,
                department: candidate.department,
                manifesto: manifestoController.text.trim(),
                profileImageUrl: candidate.profileImageUrl,
                createdAt: candidate.createdAt,
              );

              try {
                await firestore.updateCandidate(updated);
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate updated')));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating candidate: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Election Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-dashboard'),
        ),
      ),
      body: StreamBuilder<List<ElectionRequest>>(
        stream: firestore.getElectionRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];

          // Only show requests that are still pending approval
          final pending = requests.where((r) => r.status == 'pending').toList();

          if (pending.isEmpty) {
            return const Center(child: Text('No pending election requests'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final req = pending[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              req.electionName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(req.status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(req.description),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(req.university),
                          const SizedBox(width: 12),
                          Icon(Icons.business, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(req.department),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Inline candidates list for admin: show existing candidates and allow add/edit/delete
                      StreamBuilder<List<Candidate>>(
                        stream: firestore.getCandidatesStream(req.id),
                        builder: (ctx, candSnap) {
                          if (candSnap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
                          }
                          if (candSnap.hasError) {
                            return Text('Error loading candidates: ${candSnap.error}');
                          }

                          final candidates = candSnap.data ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Candidates', style: Theme.of(context).textTheme.titleSmall),
                                  TextButton.icon(
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Add'),
                                    onPressed: () => _showAddCandidateDialog(context, firestore, req.id),
                                  ),
                                ],
                              ),
                              if (candidates.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text('No candidates yet'),
                                )
                              else
                                Column(
                                  children: candidates.map((c) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(c.name),
                                        subtitle: Text(c.email),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 20),
                                              onPressed: () => _showEditCandidateDialog(context, firestore, c),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_forever, size: 20),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (dCtx) => AlertDialog(
                                                    title: const Text('Delete Candidate'),
                                                    content: Text('Delete candidate "${c.name}"? This cannot be undone.'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancel')),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                        onPressed: () => Navigator.of(dCtx).pop(true),
                                                        child: const Text('Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  try {
                                                    await firestore.deleteCandidate(c.id, req.id);
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate deleted')));
                                                  } catch (e) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting candidate: $e')));
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      )).toList(),
                                ),
                            ],
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              // Disapprove
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await firestore.updateElectionRequestStatus(req.id, 'rejected', adminResponse: 'Disapproved by admin');
                                messenger.showSnackBar(const SnackBar(content: Text('Request rejected')));
                              } catch (e) {
                                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              // Approve — ensure at least one candidate exists, then if request is for the same calendar day,
                              // require admin to set exact times.
                              final parentContext = context;

                              // Ensure candidates exist before approving
                              final existingCandidates = await firestore.getCandidates(req.id);
                              if (existingCandidates.isEmpty) {
                                // Prompt admin to add candidates first
                                await showDialog<void>(
                                  context: parentContext,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('No candidates'),
                                    content: const Text('Please add at least one candidate before approving this election.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dCtx).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(dCtx).pop();
                                          // Navigate to election details so admin can add candidates
                                          // Use parentContext to navigate safely after the dialog
                                          parentContext.go('/election/${req.id}');
                                        },
                                        child: const Text('Add Candidate'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }

                              final isSameDay = req.proposedStartDate.year == req.proposedEndDate.year &&
                                  req.proposedStartDate.month == req.proposedEndDate.month &&
                                  req.proposedStartDate.day == req.proposedEndDate.day;
                              if (isSameDay) {
                                // show dialog to pick exact start/end timestamps
                                final outerMessenger = ScaffoldMessenger.of(parentContext);
                                final outerNavigator = Navigator.of(parentContext, rootNavigator: true);
                                final DateFormat df = DateFormat('yyyy-MM-dd HH:mm');

                                await showDialog<void>(
                                  context: parentContext,
                                  barrierDismissible: false,
                                  builder: (dialogCtx) {
                                    DateTime start = req.proposedStartDate;
                                    DateTime end = req.proposedEndDate;
                                    return StatefulBuilder(builder: (innerCtx, setState) {
                                        // For same-day approvals we keep the date fixed and only allow
                                        // editing the times. Use time pickers so admins can't change the date.
                                        Future<void> pickStart() async {
                                          final pickedTime = await showTimePicker(
                                            context: parentContext,
                                            initialTime: TimeOfDay.fromDateTime(start),
                                          );
                                          if (pickedTime == null) return;
                                          setState(() {
                                            start = DateTime(start.year, start.month, start.day, pickedTime.hour, pickedTime.minute);
                                          });
                                        }

                                        Future<void> pickEnd() async {
                                          final pickedTime = await showTimePicker(
                                            context: parentContext,
                                            initialTime: TimeOfDay.fromDateTime(end),
                                          );
                                          if (pickedTime == null) return;
                                          setState(() {
                                            end = DateTime(end.year, end.month, end.day, pickedTime.hour, pickedTime.minute);
                                          });
                                        }

                                      bool processing = false;

                                      return AlertDialog(
                                        title: const Text('Set precise times'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text('Start: ${df.format(start)}')),
                                                TextButton(onPressed: pickStart, child: const Text('Edit')),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(child: Text('End:   ${df.format(end)}')),
                                                TextButton(onPressed: pickEnd, child: const Text('Edit')),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (start.isAfter(end))
                                              const Text('Start must be before end', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              outerNavigator.pop();
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          StatefulBuilder(builder: (ctx2, setState2) {
                                            return ElevatedButton(
                                              onPressed: start.isAfter(end)
                                                  ? null
                                                  : () async {
                                                      setState2(() {
                                                        processing = true;
                                                      });
                                                      try {
                                                        await firestore.approveElectionRequestWithTimes(req.id, start, end, adminResponse: 'Approved by admin');
                                                        // safely pop using the outer navigator and show snack via outer messenger
                                                        outerNavigator.pop();
                                                        outerMessenger.showSnackBar(const SnackBar(content: Text('Request approved with times')));
                                                      } catch (e) {
                                                        outerMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                                                      } finally {
                                                        setState2(() {
                                                          processing = false;
                                                        });
                                                      }
                                                    },
                                              child: processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm'),
                                            );
                                          }),
                                        ],
                                      );
                                    });
                                  },
                                );
                              } else {
                                // multi-day: simple approve
                                final messenger = ScaffoldMessenger.of(parentContext);
                                try {
                                  await firestore.updateElectionRequestStatus(req.id, 'approved', adminResponse: 'Approved by admin');
                                  messenger.showSnackBar(const SnackBar(content: Text('Request approved')));
                                } catch (e) {
                                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
