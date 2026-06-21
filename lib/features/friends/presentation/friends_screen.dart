import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import 'friends_providers.dart';
import 'friends_widgets.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        refreshFriends(ref);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) {
      refreshFriends(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsProvider);
    final incomingCount = ref
        .watch(incomingFriendRequestsProvider)
        .maybeWhen(data: (requests) => requests.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Incoming requests',
            onPressed: () => _open('/friends/incoming'),
            icon: incomingCount > 0
                ? Badge.count(
                    count: incomingCount,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.move_to_inbox_rounded),
                  )
                : const Icon(Icons.move_to_inbox_rounded),
          ),
          IconButton(
            tooltip: 'Outgoing requests',
            onPressed: () => _open('/friends/outgoing'),
            icon: const Icon(Icons.outbox_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('/friends/search'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add friend'),
      ),
      body: SafeArea(
        child: friendsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => FriendsEmptyState(
            title: 'Could not load friends',
            message: apiErrorMessage(error),
            action: FilledButton(
              onPressed: () => ref.invalidate(friendsProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (friends) {
            if (friends.isEmpty) {
              return FriendsEmptyState(
                title: 'No friends yet',
                message: 'Search by email to connect with someone on Momentum.',
                action: FilledButton.icon(
                  onPressed: () => _open('/friends/search'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search users'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) =>
                  FriendUserCard(user: friends[index]),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: friends.length,
            );
          },
        ),
      ),
    );
  }
}
