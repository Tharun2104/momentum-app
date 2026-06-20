import 'package:flutter/material.dart';

import '../data/fitness_data_client.dart';
import '../models/fitness_summary.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key, this.fitnessDataClient});

  final FitnessDataClient? fitnessDataClient;

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  late final FitnessDataClient _fitnessDataClient =
      widget.fitnessDataClient ?? createFitnessDataClient();

  FitnessSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaySummary();
  }

  Future<void> _loadTodaySummary() async {
    setState(() {
      _isLoading = true;
    });

    final summary = await _fitnessDataClient.loadTodaySummary();

    if (!mounted) {
      return;
    }

    setState(() {
      _summary = summary;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Fitness')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Fitness',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Today's activity from Apple Health",
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _FitnessMetrics(summary: summary),
                    if (summary?.message != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        summary!.message!,
                        key: const Key('fitness-status-message'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _messageColor(context, summary),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadTodaySummary,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _messageColor(BuildContext context, FitnessSummary summary) {
    return switch (summary.status) {
      FitnessSummaryStatus.ready => null,
      FitnessSummaryStatus.unavailable ||
      FitnessSummaryStatus.permissionDenied ||
      FitnessSummaryStatus.error => Theme.of(context).colorScheme.error,
    };
  }
}

class _FitnessMetrics extends StatelessWidget {
  const _FitnessMetrics({required this.summary});

  final FitnessSummary? summary;

  @override
  Widget build(BuildContext context) {
    final currentSummary = summary;
    final steps = currentSummary?.steps ?? 0;
    final distanceMeters = currentSummary?.distanceMeters ?? 0;
    final activeCalories = currentSummary?.activeCalories ?? 0;

    return Column(
      children: [
        _FitnessMetricTile(
          icon: Icons.directions_walk,
          label: 'Steps',
          value: _formatWholeNumber(steps),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FitnessMetricTile(
                icon: Icons.straighten,
                label: 'Distance',
                value: _formatDistance(distanceMeters),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FitnessMetricTile(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: '${_formatWholeNumber(activeCalories.round())} kcal',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDistance(double meters) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  static String _formatWholeNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index += 1) {
      if (index > 0 && (text.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[index]);
    }
    return buffer.toString();
  }
}

class _FitnessMetricTile extends StatelessWidget {
  const _FitnessMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
