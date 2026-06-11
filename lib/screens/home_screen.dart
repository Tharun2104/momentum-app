import 'package:flutter/material.dart';

import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  bool _isLoading = false;
  String? _message;
  String? _error;

  Future<void> _checkBackend() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _error = null;
    });

    try {
      final message = await _apiService.checkHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
                  'Backend Health',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _checkBackend,
                  child: const Text('Check Backend'),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_message != null)
                  Text(_message!, key: const Key('health-message'))
                else if (_error != null)
                  Text(
                    _error!,
                    key: const Key('health-error'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else
                  const Text('No backend check has run yet.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
