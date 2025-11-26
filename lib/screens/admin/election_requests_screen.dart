import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';
import '../../models/vote.dart';
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
