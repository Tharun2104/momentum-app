import 'package:flutter/material.dart';

import '../features/run/presentation/run_history_screen.dart';
import '../features/run/presentation/run_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Momentum')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Momentum',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your run with focus',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RunScreen(),
                      ),
                    );
                  },
                  child: const Text('Run'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RunHistoryScreen(),
                      ),
                    );
                  },
                  child: const Text('History'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
