import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/network/dio_provider.dart';
import '../features/friends/presentation/friends_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _backendStatus;
  bool _isCheckingBackend = false;
  Timer? _requestBadgeTimer;

  @override
  void initState() {
    super.initState();
    _requestBadgeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.invalidate(incomingFriendRequestsProvider);
      }
    });
  }

  @override
  void dispose() {
    _requestBadgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    setState(() {
      _isCheckingBackend = true;
      _backendStatus = null;
    });

    try {
      final response = await ref.read(dioProvider).get<String>('/health');
      if (!mounted) return;
      setState(() {
        _backendStatus = response.statusCode == 200
            ? 'Backend up - green light'
            : 'Backend returned ${response.statusCode}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _backendStatus = 'Backend check failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingBackend = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomingCount = ref
        .watch(incomingFriendRequestsProvider)
        .maybeWhen(data: (requests) => requests.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Momentum'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.account_circle_rounded),
          ),
        ],
      ),
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
                  'Track your life with focus',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.push('/run'),
                  child: const Text('Run'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => context.push('/finance'),
                  child: const Text('Money'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => context.push('/fitness'),
                  child: const Text('Fitness'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await context.push('/friends');
                    if (mounted) {
                      ref.invalidate(incomingFriendRequestsProvider);
                    }
                  },
                  icon: incomingCount > 0
                      ? Badge.count(
                          count: incomingCount,
                          backgroundColor: Colors.red,
                          child: const Icon(Icons.people_alt_rounded),
                        )
                      : const Icon(Icons.people_alt_rounded),
                  label: const Text('Friends'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _isCheckingBackend ? null : _checkBackend,
                icon: const Icon(Icons.health_and_safety_rounded),
                label: Text(
                  _isCheckingBackend ? 'Checking backend...' : 'Test backend',
                ),
              ),
              if (_backendStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  _backendStatus!,
                  key: const Key('backend-health-status'),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
