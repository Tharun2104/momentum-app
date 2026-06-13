import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/run_api_service.dart';
import '../models/create_run_request.dart';
import '../models/route_point_request.dart';
import '../models/run_response.dart';
import '../widgets/live_route_map_widget.dart';
import 'run_detail_screen.dart';
import 'run_formatters.dart';
import 'run_history_screen.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, this.runApiService});

  final RunApiService? runApiService;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  static const double _maximumAcceptedAccuracyMeters = 20;
  static const double _minimumPointDistanceMeters = 3;
  static const int _minimumDurationSeconds = 5;

  late final RunApiService _runApiService =
      widget.runApiService ?? RunApiService();

  final List<RoutePointRequest> _routePoints = [];

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  double _distanceMeters = 0;
  double? _latestAccuracyMeters;
  bool _isRunning = false;
  bool _isSaving = false;
  bool _isWebTestMode = false;
  String _gpsStatus = 'GPS idle';
  String? _errorMessage;
  RunResponse? _savedRun;

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRun() async {
    if (_isSaving) {
      return;
    }

    _timer?.cancel();
    await _positionSubscription?.cancel();

    if (!kIsWeb) {
      final canTrackLocation = await _ensureLocationReady();
      if (!canTrackLocation) {
        return;
      }
    }

    setState(() {
      _startTime = DateTime.now().toUtc();
      _elapsedSeconds = 0;
      _distanceMeters = 0;
      _latestAccuracyMeters = null;
      _routePoints.clear();
      _isRunning = true;
      _isSaving = false;
      _isWebTestMode = kIsWeb;
      _gpsStatus = kIsWeb
          ? 'Web test mode using sample route'
          : 'GPS active. Acquiring signal.';
      _errorMessage = null;
      _savedRun = null;
    });

    _startTimer();

    if (!kIsWeb) {
      _startPositionStream();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startTime = _startTime;
      if (startTime == null || !mounted) {
        return;
      }

      setState(() {
        _elapsedSeconds = DateTime.now()
            .toUtc()
            .difference(startTime)
            .inSeconds;
      });
    });
  }

  Future<bool> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'Location services are disabled.';
          _errorMessage = 'Turn on Location Services to start tracking a run.';
        });
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'Location permission denied.';
          _errorMessage = 'Allow location access to track your run.';
        });
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'Location permission blocked.';
          _errorMessage =
              'Enable location access for Momentum in Settings to track your run.';
        });
      }
      return false;
    }

    return true;
  }

  void _startPositionStream() {
    final locationSettings = _buildStreamLocationSettings();

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _handlePosition,
          onError: (Object error) {
            if (!mounted) {
              return;
            }

            setState(() {
              _gpsStatus = 'GPS error.';
              _errorMessage = 'Location tracking error: $error';
            });
          },
        );

    unawaited(_seedInitialPosition());
  }

  LocationSettings _buildStreamLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  LocationSettings _buildCurrentPositionSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 15),
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      timeLimit: Duration(seconds: 15),
    );
  }

  Future<void> _seedInitialPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _buildCurrentPositionSettings(),
      );
      _handlePosition(position);
    } catch (_) {
      if (!mounted || !_isRunning) {
        return;
      }

      setState(() {
        _gpsStatus = 'GPS active. Waiting for location update.';
      });
    }
  }

  void _handlePosition(Position position) {
    if (!_isRunning || !_isValidCoordinate(position)) {
      return;
    }

    final accuracy = position.accuracy;
    if (!accuracy.isFinite || accuracy > _maximumAcceptedAccuracyMeters) {
      _updateRejectedAccuracy(accuracy);
      return;
    }

    final previousPoint = _routePoints.isEmpty ? null : _routePoints.last;
    var distanceFromPrevious = 0.0;
    if (previousPoint != null) {
      distanceFromPrevious = Geolocator.distanceBetween(
        previousPoint.latitude,
        previousPoint.longitude,
        position.latitude,
        position.longitude,
      );

      if (distanceFromPrevious < _minimumPointDistanceMeters) {
        _updateRejectedDuplicate(accuracy);
        return;
      }
    }

    final acceptedPoint = RoutePointRequest(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: DateTime.now().toUtc(),
      accuracyMeters: accuracy,
      sequenceNumber: _routePoints.length + 1,
    );

    setState(() {
      _routePoints.add(acceptedPoint);
      _distanceMeters += distanceFromPrevious;
      _latestAccuracyMeters = accuracy;
      _gpsStatus = 'GPS active';
    });
  }

  bool _isValidCoordinate(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  void _updateRejectedAccuracy(double accuracy) {
    if (!mounted) {
      return;
    }

    setState(() {
      _latestAccuracyMeters = accuracy.isFinite ? accuracy : null;
      _gpsStatus = 'GPS active. Waiting for better accuracy.';
    });
  }

  void _updateRejectedDuplicate(double accuracy) {
    if (!mounted) {
      return;
    }

    setState(() {
      _latestAccuracyMeters = accuracy;
      _gpsStatus = 'GPS active. Waiting for movement.';
    });
  }

  Future<void> _stopRun() async {
    final startTime = _startTime;
    if (startTime == null || _isSaving) {
      return;
    }

    _timer?.cancel();
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    var endTime = DateTime.now().toUtc();
    var durationSeconds = max(1, endTime.difference(startTime).inSeconds);
    if (!endTime.isAfter(startTime)) {
      endTime = startTime.add(const Duration(seconds: 1));
      durationSeconds = 1;
    }

    if (_isWebTestMode) {
      _routePoints
        ..clear()
        ..addAll(_buildFakeRoutePoints(startTime: startTime, endTime: endTime));
      _distanceMeters = _calculateRouteDistance(_routePoints);
    }

    if (!_hasEnoughGpsData(durationSeconds)) {
      setState(() {
        _isRunning = false;
        _isSaving = false;
        _elapsedSeconds = durationSeconds;
        _gpsStatus = 'GPS idle';
        _errorMessage =
            'Not enough GPS data collected. Please try again outdoors.';
      });
      return;
    }

    final averagePaceSecondsPerKm = _calculateAveragePace(
      durationSeconds: durationSeconds,
      distanceMeters: _distanceMeters,
    );

    setState(() {
      _isRunning = false;
      _isSaving = true;
      _elapsedSeconds = durationSeconds;
      _gpsStatus = 'Saving run';
      _errorMessage = null;
    });

    try {
      final savedRun = await _runApiService.createRun(
        CreateRunRequest(
          startTime: startTime,
          endTime: endTime,
          distanceMeters: _distanceMeters,
          durationSeconds: durationSeconds,
          averagePaceSecondsPerKm: averagePaceSecondsPerKm,
          routePoints: List.unmodifiable(_routePoints),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _savedRun = savedRun;
        _distanceMeters = savedRun.distanceMeters;
        _gpsStatus = 'Run saved';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _gpsStatus = 'Save failed';
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _hasEnoughGpsData(int durationSeconds) {
    return _routePoints.length >= 2 &&
        durationSeconds >= _minimumDurationSeconds &&
        _distanceMeters > 0;
  }

  List<RoutePointRequest> _buildFakeRoutePoints({
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final duration = max(1, endTime.difference(startTime).inSeconds);
    const coordinates = [
      (latitude: 35.2271, longitude: -80.8431),
      (latitude: 35.2275, longitude: -80.8428),
      (latitude: 35.2280, longitude: -80.8423),
      (latitude: 35.2286, longitude: -80.8418),
      (latitude: 35.2291, longitude: -80.8412),
    ];

    return List.generate(coordinates.length, (index) {
      final offsetSeconds = (duration * index / (coordinates.length - 1))
          .round();
      final coordinate = coordinates[index];

      return RoutePointRequest(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        recordedAt: startTime.add(Duration(seconds: offsetSeconds)).toUtc(),
        accuracyMeters: 8,
        sequenceNumber: index + 1,
      );
    });
  }

  double _calculateRouteDistance(List<RoutePointRequest> points) {
    var distanceMeters = 0.0;
    for (var index = 1; index < points.length; index += 1) {
      final previous = points[index - 1];
      final current = points[index];
      distanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }

    return distanceMeters;
  }

  double _calculateAveragePace({
    required int durationSeconds,
    required double distanceMeters,
  }) {
    final distanceKm = distanceMeters / 1000;
    if (distanceKm <= 0) {
      return 0;
    }

    return durationSeconds / distanceKm;
  }

  @override
  Widget build(BuildContext context) {
    final displayedDistanceMeters =
        _savedRun?.distanceMeters ?? _distanceMeters;
    final displayedPace = _savedRun?.averagePaceSecondsPerKm;
    final livePace = _calculateAveragePace(
      durationSeconds: _elapsedSeconds,
      distanceMeters: displayedDistanceMeters,
    );
    final paceText = displayedPace != null
        ? RunFormatters.pace(displayedPace)
        : displayedDistanceMeters <= 0
        ? '-- /km'
        : RunFormatters.pace(livePace);

    return Scaffold(
      appBar: AppBar(title: const Text('Run')),
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
                    RunFormatters.duration(_elapsedSeconds),
                    key: const Key('run-timer'),
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _RunMetrics(
                    distanceText: RunFormatters.distanceKm(
                      displayedDistanceMeters,
                    ),
                    paceText: paceText,
                  ),
                  const SizedBox(height: 24),
                  _GpsStatus(
                    status: _gpsStatus,
                    latestAccuracyMeters: _latestAccuracyMeters,
                    pointCount: _routePoints.length,
                  ),
                  const SizedBox(height: 24),
                  LiveRouteMapWidget(
                    routePoints: List.unmodifiable(_routePoints),
                    isRunning: _isRunning,
                  ),
                  const SizedBox(height: 24),
                  if (_isRunning)
                    Text(
                      'Run in progress',
                      key: const Key('run-status'),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  if (_isRunning) const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('run-action-button'),
                    onPressed: _isSaving
                        ? null
                        : _isRunning
                        ? _stopRun
                        : _startRun,
                    child: Text(_isRunning ? 'Stop' : 'Start'),
                  ),
                  if (_isSaving) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Text('Saving run...', textAlign: TextAlign.center),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _errorMessage!,
                      key: const Key('run-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_savedRun != null) ...[
                    const SizedBox(height: 24),
                    _RunSummary(run: _savedRun!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunMetrics extends StatelessWidget {
  const _RunMetrics({required this.distanceText, required this.paceText});

  final String distanceText;
  final String paceText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Distance',
            value: distanceText,
            valueKey: const Key('run-distance'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'Pace',
            value: paceText,
            valueKey: const Key('run-pace'),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

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
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              key: valueKey,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsStatus extends StatelessWidget {
  const _GpsStatus({
    required this.status,
    required this.latestAccuracyMeters,
    required this.pointCount,
  });

  final String status;
  final double? latestAccuracyMeters;
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final accuracyText = latestAccuracyMeters == null
        ? '--'
        : '${latestAccuracyMeters!.toStringAsFixed(1)} m';

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
            Text('GPS status', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(status, key: const Key('gps-status')),
            const SizedBox(height: 8),
            _SummaryRow(label: 'Latest accuracy', value: accuracyText),
            _SummaryRow(
              label: 'Valid route points',
              value: pointCount.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunSummary extends StatelessWidget {
  const _RunSummary({required this.run});

  final RunResponse run;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Run saved successfully',
              key: const Key('run-summary-title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Run ID', value: run.id.toString()),
            _SummaryRow(
              label: 'Distance',
              value: RunFormatters.distanceKm(run.distanceMeters),
            ),
            _SummaryRow(
              label: 'Duration',
              value: RunFormatters.duration(run.durationSeconds),
            ),
            _SummaryRow(
              label: 'Average pace',
              value: RunFormatters.pace(run.averagePaceSecondsPerKm),
            ),
            _SummaryRow(
              label: 'Route points',
              value: run.routePoints.length.toString(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RunDetailScreen(runId: run.id),
                        ),
                      );
                    },
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RunHistoryScreen(),
                        ),
                      );
                    },
                    child: const Text('View History'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
