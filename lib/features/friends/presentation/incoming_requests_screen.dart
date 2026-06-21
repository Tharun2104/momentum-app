import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../domain/friend_request.dart';
import 'friends_providers.dart';
import 'friends_widgets.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    FriendRequest request, {
    required bool accept,
  }) async {
    try {
      final repository = ref.read(friendsRepositoryProvider);
      if (accept) {
        await repository.acceptRequest(request.id);
      } else {
        await repository.rejectRequest(request.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Friend request accepted.' : 'Friend request rejected.',
          ),
        ),
      );
      refreshFriends(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(error, fallback: 'Could not update request.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsState = ref.watch(incomingFriendRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Requests')),
      body: SafeArea(
        child: requestsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FriendsEmptyState(
            title: 'Could not load requests',
            message: error.toString(),
            action: FilledButton(
              onPressed: () => ref.invalidate(incomingFriendRequestsProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return const FriendsEmptyState(
                title: 'No incoming requests',
                message: 'Friend requests sent to you will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final request = requests[index];
                return FriendUserCard(
                  user: request.sender,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () =>
                            _respond(context, ref, request, accept: true),
                        child: const Text('Accept'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _respond(context, ref, request, accept: false),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: requests.length,
            );
          },
        ),
      ),
    );
  }
}
