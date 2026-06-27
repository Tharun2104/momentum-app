import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/friend_user.dart';
import 'friends_providers.dart';
import 'friends_widgets.dart';

class SearchUserScreen extends ConsumerStatefulWidget {
  const SearchUserScreen({super.key});

  @override
  ConsumerState<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends ConsumerState<SearchUserScreen> {
  final _queryController = TextEditingController();
  FriendUser? _result;
  String? _message;
  bool _isSearching = false;
  bool _isSending = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _message = 'Enter a friend id or email.';
        _result = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _message = null;
      _result = null;
    });

    try {
      final user = await ref.read(friendsRepositoryProvider).searchUser(query);
      if (!mounted) return;
      setState(() {
        _result = user;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'No user found for $query.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendRequest(FriendUser user) async {
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      await ref.read(friendsRepositoryProvider).sendRequest(user.id);
      if (!mounted) return;
      refreshFriends(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${user.name}.')),
      );
      setState(() {
        _message = 'Friend request sent to ${user.name}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = apiErrorMessage(error, fallback: 'Could not send request.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;
    final result = _result;
    final isSelf = result != null && result.id == currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Friend')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _queryController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search by friend id or email',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _isSearching ? null : _search,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSearching ? null : _search,
              child: Text(_isSearching ? 'Searching...' : 'Search'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center),
            ],
            if (result != null) ...[
              const SizedBox(height: 20),
              FriendUserCard(
                user: result,
                trailing: FilledButton(
                  onPressed: isSelf || _isSending
                      ? null
                      : () => _sendRequest(result),
                  child: Text(
                    isSelf
                        ? 'You'
                        : _isSending
                        ? 'Sending...'
                        : 'Send',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
