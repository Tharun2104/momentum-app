import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../friends/presentation/friends_providers.dart';
import 'auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final incomingCount = ref
        .watch(incomingFriendRequestsProvider)
        .maybeWhen(data: (requests) => requests.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    (user?.name ?? 'M').characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  user?.name ?? 'Momentum user',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (user != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: InputChip(
                      avatar: const Icon(Icons.tag_rounded, size: 18),
                      label: Text('Friend ID ${user.id}'),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await context.push('/friends');
                    ref.invalidate(incomingFriendRequestsProvider);
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
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ],
            ),
    );
  }
}
