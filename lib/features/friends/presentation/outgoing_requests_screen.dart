import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'friends_providers.dart';
import 'friends_widgets.dart';

class OutgoingRequestsScreen extends ConsumerWidget {
  const OutgoingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsState = ref.watch(outgoingFriendRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Outgoing Requests')),
      body: SafeArea(
        child: requestsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FriendsEmptyState(
            title: 'Could not load sent requests',
            message: error.toString(),
            action: FilledButton(
              onPressed: () => ref.invalidate(outgoingFriendRequestsProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return const FriendsEmptyState(
                title: 'No outgoing requests',
                message: 'Pending requests you send will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) => FriendUserCard(
                user: requests[index].receiver,
                trailing: const Chip(label: Text('Pending')),
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: requests.length,
            );
          },
        ),
      ),
    );
  }
}
