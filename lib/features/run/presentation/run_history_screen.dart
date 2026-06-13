import 'package:flutter/material.dart';

import '../data/run_api_service.dart';
import '../models/run_response.dart';
import 'run_detail_screen.dart';
import 'run_formatters.dart';

class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key, this.runApiService});

  final RunApiService? runApiService;

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  late final RunApiService _runApiService =
      widget.runApiService ?? RunApiService();

  late Future<List<RunResponse>> _runsFuture;
  final Set<int> _deletingRunIds = {};

  @override
  void initState() {
    super.initState();
    _runsFuture = _runApiService.getRuns();
  }

  void _reloadRuns() {
    setState(() {
      _runsFuture = _runApiService.getRuns();
    });
  }

  void _openRunDetail(int runId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RunDetailScreen(runId: runId, runApiService: _runApiService),
      ),
    );
  }

  Future<void> _confirmDeleteRun(RunResponse run) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete run?'),
        content: Text(
          'This will permanently remove the ${RunFormatters.distanceKm(run.distanceMeters)} run from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteRun(run.id);
  }

  Future<void> _deleteRun(int runId) async {
    setState(() {
      _deletingRunIds.add(runId);
    });

    try {
      await _runApiService.deleteRun(runId);

      if (!mounted) {
        return;
      }

      setState(() {
        _runsFuture = _runApiService.getRuns();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Run deleted')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete run: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _deletingRunIds.remove(runId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run History')),
      body: SafeArea(
        child: FutureBuilder<List<RunResponse>>(
          future: _runsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _HistoryMessage(
                title: 'Could not load runs',
                message: snapshot.error.toString(),
                actionLabel: 'Retry',
                onActionPressed: _reloadRuns,
              );
            }

            final runs = snapshot.data ?? [];
            if (runs.isEmpty) {
              return const _HistoryMessage(
                title: 'No runs yet',
                message: 'Save a run and it will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final run = runs[index];
                return _RunHistoryCard(
                  run: run,
                  isDeleting: _deletingRunIds.contains(run.id),
                  onTap: () => _openRunDetail(run.id),
                  onDeletePressed: () => _confirmDeleteRun(run),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: runs.length,
            );
          },
        ),
      ),
    );
  }
}

class _RunHistoryCard extends StatelessWidget {
  const _RunHistoryCard({
    required this.run,
    required this.isDeleting,
    required this.onTap,
    required this.onDeletePressed,
  });

  final RunResponse run;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      RunFormatters.distanceKm(run.distanceMeters),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (isDeleting)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Delete run',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDeletePressed,
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    semanticLabel: 'Open run detail',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(RunFormatters.localDateTime(run.startTime)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _InlineMetric(
                    label: 'Duration',
                    value: RunFormatters.duration(run.durationSeconds),
                  ),
                  _InlineMetric(
                    label: 'Pace',
                    value: RunFormatters.pace(run.averagePaceSecondsPerKm),
                  ),
                  _InlineMetric(
                    label: 'Route points',
                    value: run.routePoints.length.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onActionPressed,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
