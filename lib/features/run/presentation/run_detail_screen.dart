import 'package:flutter/material.dart';

import '../data/run_api_service.dart';
import '../models/run_response.dart';
import '../widgets/route_map_widget.dart';
import 'run_formatters.dart';

class RunDetailScreen extends StatefulWidget {
  const RunDetailScreen({super.key, required this.runId, this.runApiService});

  final int runId;
  final RunApiService? runApiService;

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  late final RunApiService _runApiService =
      widget.runApiService ?? RunApiService();

  late Future<RunResponse> _runFuture;

  @override
  void initState() {
    super.initState();
    _runFuture = _runApiService.getRunById(widget.runId);
  }

  void _reloadRun() {
    setState(() {
      _runFuture = _runApiService.getRunById(widget.runId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Detail')),
      body: SafeArea(
        child: FutureBuilder<RunResponse>(
          future: _runFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _DetailMessage(
                title: 'Could not load run',
                message: snapshot.error.toString(),
                actionLabel: 'Retry',
                onActionPressed: _reloadRun,
              );
            }

            final run = snapshot.data;
            if (run == null) {
              return const _DetailMessage(
                title: 'Run not found',
                message: 'This run could not be loaded.',
              );
            }

            return _RunDetailContent(run: run);
          },
        ),
      ),
    );
  }
}

class _RunDetailContent extends StatelessWidget {
  const _RunDetailContent({required this.run});

  final RunResponse run;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          RunFormatters.distanceKm(run.distanceMeters),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(RunFormatters.localDateTime(run.startTime)),
        const SizedBox(height: 24),
        RouteMapWidget(routePoints: run.routePoints),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Stats',
          children: [
            _DetailRow(label: 'Run ID', value: run.id.toString()),
            _DetailRow(
              label: 'Duration',
              value: RunFormatters.duration(run.durationSeconds),
            ),
            _DetailRow(
              label: 'Average pace',
              value: RunFormatters.pace(run.averagePaceSecondsPerKm),
            ),
            _DetailRow(
              label: 'Route points',
              value: run.routePoints.length.toString(),
            ),
            _DetailRow(
              label: 'Start time',
              value: RunFormatters.localDateTime(run.startTime),
            ),
            _DetailRow(
              label: 'End time',
              value: RunFormatters.localDateTime(run.endTime),
            ),
            _DetailRow(
              label: 'Created at',
              value: RunFormatters.localDateTime(run.createdAt),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({
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
