import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/run_api_service.dart';
import '../data/run_step_client.dart';
import '../models/create_run_request.dart';
import '../models/route_point_request.dart';
import '../models/run_response.dart';
import '../widgets/live_route_map_widget.dart';
import 'run_detail_screen.dart';
import 'run_formatters.dart';
import 'run_history_screen.dart';

enum GpsSignalStatus { dead, searching, weak, good }

enum RunTrackingState { idle, running, paused, saving, completed }

abstract class RunLocationClient {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position> getCurrentPosition({required LocationSettings settings});

  Stream<Position> getPositionStream({required LocationSettings settings});
}

class GeolocatorRunLocationClient implements RunLocationClient {
  const GeolocatorRunLocationClient();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<Position> getCurrentPosition({required LocationSettings settings}) {
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  @override
  Stream<Position> getPositionStream({required LocationSettings settings}) {
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

class RunScreen extends StatefulWidget {
  const RunScreen({
    super.key,
    this.runApiService,
    this.locationClient,
    this.stepClient,
    this.now,
  });

  final RunApiService? runApiService;
  final RunLocationClient? locationClient;
  final RunStepClient? stepClient;
  final DateTime Function()? now;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  static const double _maximumAcceptedAccuracyMeters = 20;
  static const double _minimumPointDistanceMeters = 3;
  static const double _maximumRunningSpeedMetersPerSecond = 8;
  static const int _minimumDurationSeconds = 5;

  late final RunApiService _runApiService =
      widget.runApiService ?? RunApiService();
  late final RunLocationClient _locationClient =
      widget.locationClient ?? const GeolocatorRunLocationClient();
  late final RunStepClient _stepClient =
      widget.stepClient ?? createPlatformRunStepClient();
  late final DateTime Function() _now =
      widget.now ?? () => DateTime.now().toUtc();

  final List<RoutePointRequest> _routePoints = [];

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _startTime;
  DateTime? _lastResumeTime;
  Duration _activeDuration = Duration.zero;
  int _elapsedSeconds = 0;
  int? _appStepCount;
  int? _healthKitStartStepCount;
  int _pausedAppStepCountOffset = 0;
  int? _pauseStartRawAppStepCount;
  bool _isRefreshingStepCount = false;
  double _distanceMeters = 0;
  double? _latestAccuracyMeters;
  RunTrackingState _trackingState = RunTrackingState.idle;
  bool _isWebTestMode = false;
  GpsSignalStatus _gpsSignalStatus = kIsWeb
      ? GpsSignalStatus.good
      : GpsSignalStatus.searching;
  int _rejectedPointCount = 0;
  bool _skipDistanceForNextAcceptedPoint = false;
  String? _gpsDetailMessage;
  String? _errorMessage;
  RunResponse? _savedRun;

  bool get _isRunning => _trackingState == RunTrackingState.running;

  bool get _isPaused => _trackingState == RunTrackingState.paused;

  bool get _isSaving => _trackingState == RunTrackingState.saving;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _gpsDetailMessage = 'Web test mode uses a sample route.';
      return;
    }

    unawaited(_refreshPreStartGpsStatus());
  }

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

    final now = _now();
    final stepStartSnapshot = await _stepClient.startRun(startTime: now);
    setState(() {
      _startTime = now;
      _lastResumeTime = now;
      _activeDuration = Duration.zero;
      _elapsedSeconds = 0;
      _appStepCount = null;
      _healthKitStartStepCount = stepStartSnapshot.healthKitStartStepCount;
      _pausedAppStepCountOffset = 0;
      _pauseStartRawAppStepCount = null;
      _distanceMeters = 0;
      _latestAccuracyMeters = null;
      _routePoints.clear();
      _rejectedPointCount = 0;
      _skipDistanceForNextAcceptedPoint = false;
      _trackingState = RunTrackingState.running;
      _isWebTestMode = kIsWeb;
      _gpsSignalStatus = kIsWeb
          ? GpsSignalStatus.good
          : GpsSignalStatus.searching;
      _gpsDetailMessage = kIsWeb
          ? 'Web test mode using sample route.'
          : 'Searching for GPS signal...';
      _errorMessage = null;
      _savedRun = null;
    });

    _startTimer();
    unawaited(_refreshAppStepCount());

    if (!kIsWeb) {
      _startPositionStream();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRunning) {
        return;
      }

      setState(() {
        _elapsedSeconds = _currentActiveDuration().inSeconds;
      });
      unawaited(_refreshAppStepCount());
    });
  }

  Duration _currentActiveDuration() {
    final lastResumeTime = _lastResumeTime;
    if (!_isRunning || lastResumeTime == null) {
      return _activeDuration;
    }

    return _activeDuration + _now().difference(lastResumeTime);
  }

  void _pauseRun() {
    if (!_isRunning) {
      return;
    }

    _finalizeActiveDurationSegment();
    _timer?.cancel();
    unawaited(_capturePauseStartStepCount());

    setState(() {
      _elapsedSeconds = _activeDuration.inSeconds;
      _trackingState = RunTrackingState.paused;
      _gpsDetailMessage = 'Paused - GPS points are not being counted.';
      _errorMessage = null;
    });
  }

  void _resumeRun() {
    if (!_isPaused) {
      return;
    }

    unawaited(_capturePausedStepOffset());
    setState(() {
      _lastResumeTime = _now();
      _skipDistanceForNextAcceptedPoint = true;
      _trackingState = RunTrackingState.running;
      _gpsDetailMessage = 'GPS ready';
      _errorMessage = null;
    });
    _startTimer();
  }

  Future<void> _refreshAppStepCount() async {
    final startTime = _startTime;
    if (startTime == null || !_isRunning || _isRefreshingStepCount) {
      return;
    }

    _isRefreshingStepCount = true;
    try {
      final rawStepCount = await _stepClient.currentAppStepCount(
        startTime: startTime,
      );
      if (!mounted || rawStepCount == null) {
        return;
      }

      setState(() {
        _appStepCount = _activeAppStepCount(rawStepCount);
      });
    } finally {
      _isRefreshingStepCount = false;
    }
  }

  Future<void> _capturePauseStartStepCount() async {
    final startTime = _startTime;
    if (startTime == null) {
      return;
    }

    final rawStepCount = await _stepClient.currentAppStepCount(
      startTime: startTime,
    );
    if (!mounted || rawStepCount == null || !_isPaused) {
      return;
    }

    setState(() {
      _pauseStartRawAppStepCount = rawStepCount;
      _appStepCount = _activeAppStepCount(rawStepCount);
    });
  }

  Future<void> _capturePausedStepOffset() async {
    final startTime = _startTime;
    final pauseStartRawAppStepCount = _pauseStartRawAppStepCount;
    if (startTime == null || pauseStartRawAppStepCount == null) {
      return;
    }

    final rawStepCount = await _stepClient.currentAppStepCount(
      startTime: startTime,
    );
    if (!mounted || rawStepCount == null) {
      return;
    }

    final pausedStepCount = max(0, rawStepCount - pauseStartRawAppStepCount);
    setState(() {
      _pausedAppStepCountOffset += pausedStepCount;
      _pauseStartRawAppStepCount = null;
      _appStepCount = _activeAppStepCount(rawStepCount);
    });
  }

  int _activeAppStepCount(int rawStepCount) {
    return max(0, rawStepCount - _pausedAppStepCountOffset);
  }

  void _finalizeActiveDurationSegment() {
    final lastResumeTime = _lastResumeTime;
    if (lastResumeTime == null) {
      return;
    }

    _activeDuration += _now().difference(lastResumeTime);
    _lastResumeTime = null;
  }

  Future<void> _refreshPreStartGpsStatus() async {
    try {
      final canTrackLocation = await _checkLocationReady(
        requestPermission: false,
      );
      if (!canTrackLocation ||
          !mounted ||
          _trackingState != RunTrackingState.idle) {
        return;
      }

      setState(() {
        _gpsSignalStatus = GpsSignalStatus.searching;
        _gpsDetailMessage = 'Searching for GPS signal...';
      });

      try {
        final position = await _locationClient.getCurrentPosition(
          settings: _buildCurrentPositionSettings(),
        );

        if (!mounted || _trackingState != RunTrackingState.idle) {
          return;
        }

        _updateGpsStatusFromPosition(position);
      } catch (_) {
        if (!mounted || _trackingState != RunTrackingState.idle) {
          return;
        }

        setState(() {
          _gpsSignalStatus = GpsSignalStatus.searching;
          _gpsDetailMessage = 'Searching for GPS signal...';
        });
      }
    } catch (error) {
      if (!mounted || _trackingState != RunTrackingState.idle) {
        return;
      }

      setState(() {
        _gpsSignalStatus = GpsSignalStatus.dead;
        _gpsDetailMessage =
            'Location unavailable. Enable location permission to start.';
        _errorMessage = 'Location status error: $error';
      });
    }
  }

  Future<bool> _ensureLocationReady() async {
    return _checkLocationReady(requestPermission: true);
  }

  Future<bool> _checkLocationReady({required bool requestPermission}) async {
    final serviceEnabled = await _locationClient.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _gpsSignalStatus = GpsSignalStatus.dead;
          _gpsDetailMessage = 'Location services are off.';
          _errorMessage = 'Turn on Location Services to start tracking a run.';
        });
      }
      return false;
    }

    var permission = await _locationClient.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await _locationClient.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _gpsSignalStatus = GpsSignalStatus.dead;
          _gpsDetailMessage = 'Location permission denied.';
          _errorMessage = 'Allow location access to track your run.';
        });
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _gpsSignalStatus = GpsSignalStatus.dead;
          _gpsDetailMessage = 'Location permission denied.';
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

    _positionSubscription = _locationClient
        .getPositionStream(settings: locationSettings)
        .listen(
          _handlePosition,
          onError: (Object error) {
            if (!mounted) {
              return;
            }

            setState(() {
              _gpsSignalStatus = GpsSignalStatus.dead;
              _gpsDetailMessage =
                  'Location unavailable. Enable location permission to start.';
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
      final position = await _locationClient.getCurrentPosition(
        settings: _buildCurrentPositionSettings(),
      );
      _handlePosition(position);
    } catch (_) {
      if (!mounted || !_isRunning) {
        return;
      }

      setState(() {
        _gpsSignalStatus = GpsSignalStatus.searching;
        _gpsDetailMessage = 'Searching for GPS signal...';
      });
    }
  }

  void _handlePosition(Position position) {
    _updateGpsStatusFromPosition(position);

    if (!_isRunning) {
      return;
    }

    if (!_isValidCoordinate(position)) {
      _updateRejectedPosition();
      return;
    }

    final accuracy = position.accuracy;
    if (!accuracy.isFinite || accuracy > _maximumAcceptedAccuracyMeters) {
      _updateRejectedPosition();
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

      if (!_skipDistanceForNextAcceptedPoint &&
          distanceFromPrevious < _minimumPointDistanceMeters) {
        _updateRejectedPosition();
        return;
      }

      if (_skipDistanceForNextAcceptedPoint) {
        distanceFromPrevious = 0;
      } else {
        final speedMetersPerSecond = _calculateSpeedMetersPerSecond(
          distanceMeters: distanceFromPrevious,
          previousRecordedAt: previousPoint.recordedAt,
          candidateRecordedAt: position.timestamp.toUtc(),
        );
        if (speedMetersPerSecond <= 0 ||
            speedMetersPerSecond > _maximumRunningSpeedMetersPerSecond) {
          _updateRejectedPosition();
          return;
        }
      }
    }

    final acceptedPoint = RoutePointRequest(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: position.timestamp.toUtc(),
      accuracyMeters: accuracy,
      sequenceNumber: _routePoints.length + 1,
    );

    setState(() {
      _routePoints.add(acceptedPoint);
      _distanceMeters += distanceFromPrevious;
      _latestAccuracyMeters = accuracy;
      _skipDistanceForNextAcceptedPoint = false;
      _gpsSignalStatus = GpsSignalStatus.good;
      _gpsDetailMessage = 'GPS ready';
    });
  }

  double _calculateSpeedMetersPerSecond({
    required double distanceMeters,
    required DateTime previousRecordedAt,
    required DateTime candidateRecordedAt,
  }) {
    final timeSeconds =
        candidateRecordedAt.difference(previousRecordedAt).inMilliseconds /
        1000;
    if (timeSeconds <= 0) {
      return 0;
    }

    return distanceMeters / timeSeconds;
  }

  void _updateGpsStatusFromPosition(Position position) {
    if (!mounted) {
      return;
    }

    final accuracy = position.accuracy;
    final hasUsableAccuracy = accuracy.isFinite;
    setState(() {
      _latestAccuracyMeters = hasUsableAccuracy ? accuracy : null;
      if (!hasUsableAccuracy) {
        _gpsSignalStatus = GpsSignalStatus.searching;
        _gpsDetailMessage = 'Searching for GPS signal...';
      } else if (accuracy > _maximumAcceptedAccuracyMeters) {
        _gpsSignalStatus = GpsSignalStatus.weak;
        _gpsDetailMessage =
            'Weak GPS signal. You can start, but tracking may improve outdoors.';
      } else {
        _gpsSignalStatus = GpsSignalStatus.good;
        _gpsDetailMessage = 'GPS ready';
      }
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

  void _updateRejectedPosition() {
    if (!mounted) {
      return;
    }

    setState(() {
      _rejectedPointCount += 1;
    });
  }

  Future<void> _stopRun() async {
    final startTime = _startTime;
    if (startTime == null || _isSaving || (!_isRunning && !_isPaused)) {
      return;
    }

    if (_isRunning) {
      _finalizeActiveDurationSegment();
    }

    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;

    var endTime = _now();
    var durationSeconds = max(1, _activeDuration.inSeconds);
    if (!endTime.isAfter(startTime)) {
      endTime = startTime.add(const Duration(seconds: 1));
    }

    if (_isWebTestMode) {
      _routePoints
        ..clear()
        ..addAll(_buildFakeRoutePoints(startTime: startTime, endTime: endTime));
      _distanceMeters = _calculateRouteDistance(_routePoints);
    }

    if (!_hasEnoughGpsData(durationSeconds)) {
      setState(() {
        _trackingState = RunTrackingState.idle;
        _elapsedSeconds = durationSeconds;
        _lastResumeTime = null;
        _gpsSignalStatus = GpsSignalStatus.searching;
        _gpsDetailMessage = 'Searching for GPS signal...';
        _errorMessage =
            'Not enough valid GPS data collected. Please try again outdoors.';
      });
      return;
    }

    final averagePaceSecondsPerKm = _calculateAveragePace(
      durationSeconds: durationSeconds,
      distanceMeters: _distanceMeters,
    );

    setState(() {
      _trackingState = RunTrackingState.saving;
      _elapsedSeconds = durationSeconds;
      _lastResumeTime = null;
      _gpsDetailMessage = 'Saving run...';
      _errorMessage = null;
    });

    try {
      final stepFinishSnapshot = await _stepClient.finishRun(
        startTime: startTime,
        endTime: endTime,
      );
      final appStepCount = _finalAppStepCount(stepFinishSnapshot);
      final savedRun = await _runApiService.createRun(
        CreateRunRequest(
          startTime: startTime,
          endTime: endTime,
          distanceMeters: _distanceMeters,
          durationSeconds: durationSeconds,
          averagePaceSecondsPerKm: averagePaceSecondsPerKm,
          appStepCount: appStepCount,
          healthKitStartStepCount: _healthKitStartStepCount,
          healthKitEndStepCount: stepFinishSnapshot.healthKitEndStepCount,
          healthKitUpdateLagSeconds:
              stepFinishSnapshot.healthKitUpdateLagSeconds,
          routePoints: List.unmodifiable(_routePoints),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _savedRun = savedRun;
        _distanceMeters = savedRun.distanceMeters;
        _appStepCount = savedRun.appStepCount;
        _trackingState = RunTrackingState.completed;
        _gpsDetailMessage = 'Run saved';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _trackingState = RunTrackingState.idle;
        _gpsDetailMessage = 'Save failed';
        _errorMessage = error.toString();
      });
    }
  }

  bool _hasEnoughGpsData(int durationSeconds) {
    return _routePoints.length >= 2 &&
        durationSeconds >= _minimumDurationSeconds &&
        _distanceMeters > 0;
  }

  int? _finalAppStepCount(RunStepFinishSnapshot stepFinishSnapshot) {
    final rawStepCount = stepFinishSnapshot.appStepCount;
    if (rawStepCount == null) {
      return _appStepCount;
    }

    return _activeAppStepCount(rawStepCount);
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
      durationSeconds: _currentDisplaySeconds(),
      distanceMeters: displayedDistanceMeters,
    );
    final paceText = displayedPace != null
        ? RunFormatters.pace(displayedPace)
        : displayedDistanceMeters <= 0
        ? '-- /km'
        : RunFormatters.pace(livePace);
    final canStart = kIsWeb || _gpsSignalStatus != GpsSignalStatus.dead;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run'),
        actions: [
          IconButton(
            tooltip: 'Run history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RunHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RunTimerDisplay(
                    durationText: RunFormatters.duration(
                      _currentDisplaySeconds(),
                    ),
                    statusText: _runStatusText(),
                    trackingState: _trackingState,
                  ),
                  const SizedBox(height: 24),
                  _RunMetrics(
                    distanceText: RunFormatters.distanceKm(
                      displayedDistanceMeters,
                    ),
                    paceText: paceText,
                    stepText: _formatStepCount(
                      _savedRun?.appStepCount ?? _appStepCount,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GpsStatus(
                    signalStatus: _gpsSignalStatus,
                    detailMessage: _gpsDetailMessage,
                    latestAccuracyMeters: _latestAccuracyMeters,
                    acceptedPointCount: _routePoints.length,
                    rejectedPointCount: _rejectedPointCount,
                  ),
                  const SizedBox(height: 24),
                  LiveRouteMapWidget(
                    routePoints: List.unmodifiable(_routePoints),
                    isRunning: _isRunning,
                  ),
                  const SizedBox(height: 24),
                  _RunControls(
                    trackingState: _trackingState,
                    canStart: canStart,
                    onStart: _startRun,
                    onPause: _pauseRun,
                    onResume: _resumeRun,
                    onStop: _stopRun,
                  ),
                  if (_startButtonHelperText() != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _startButtonHelperText()!,
                      key: const Key('run-start-helper'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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

  int _currentDisplaySeconds() {
    if (_isRunning) {
      return _currentActiveDuration().inSeconds;
    }

    return _elapsedSeconds;
  }

  String _runStatusText() {
    return switch (_trackingState) {
      RunTrackingState.idle => 'Status: Idle',
      RunTrackingState.running => 'Status: Running',
      RunTrackingState.paused => 'Status: Paused',
      RunTrackingState.saving => 'Status: Saving',
      RunTrackingState.completed => 'Status: Completed',
    };
  }

  String? _startButtonHelperText() {
    if (_isPaused) {
      return 'Paused - GPS points are not counted.';
    }

    return switch (_gpsSignalStatus) {
      GpsSignalStatus.dead => 'Enable location to start',
      GpsSignalStatus.weak => 'Weak signal, but you can start.',
      GpsSignalStatus.searching || GpsSignalStatus.good => null,
    };
  }

  String _formatStepCount(int? stepCount) {
    return stepCount?.toString() ?? '--';
  }
}

class _RunTimerDisplay extends StatelessWidget {
  const _RunTimerDisplay({
    required this.durationText,
    required this.statusText,
    required this.trackingState,
  });

  final String durationText;
  final String statusText;
  final RunTrackingState trackingState;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = switch (trackingState) {
      RunTrackingState.running => colorScheme.primary,
      RunTrackingState.paused => colorScheme.tertiary,
      RunTrackingState.saving => colorScheme.secondary,
      RunTrackingState.completed => colorScheme.primary,
      RunTrackingState.idle => colorScheme.outline,
    };

    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surface,
          border: Border.all(color: accentColor, width: 6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_statusIcon(), color: accentColor, size: 28),
            const SizedBox(height: 12),
            Text(
              durationText,
              key: const Key('run-timer'),
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              key: const Key('run-status'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon() {
    return switch (trackingState) {
      RunTrackingState.running => Icons.directions_run,
      RunTrackingState.paused => Icons.pause,
      RunTrackingState.saving => Icons.cloud_upload,
      RunTrackingState.completed => Icons.check,
      RunTrackingState.idle => Icons.play_arrow,
    };
  }
}

class _RunControls extends StatelessWidget {
  const _RunControls({
    required this.trackingState,
    required this.canStart,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final RunTrackingState trackingState;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return switch (trackingState) {
      RunTrackingState.idle || RunTrackingState.completed => FilledButton(
        key: const Key('run-action-button'),
        onPressed: canStart ? onStart : null,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.play_arrow), SizedBox(width: 8), Text('Start')],
        ),
      ),
      RunTrackingState.running => Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const Key('run-pause-button'),
              onPressed: onPause,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause),
                  SizedBox(width: 8),
                  Text('Pause'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonal(
              key: const Key('run-stop-button'),
              onPressed: onStop,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.stop), SizedBox(width: 8), Text('Stop')],
              ),
            ),
          ),
        ],
      ),
      RunTrackingState.paused => Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const Key('run-resume-button'),
              onPressed: onResume,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('Resume'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonal(
              key: const Key('run-stop-button'),
              onPressed: onStop,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.stop), SizedBox(width: 8), Text('Stop')],
              ),
            ),
          ),
        ],
      ),
      RunTrackingState.saving => const FilledButton(
        key: Key('run-action-button'),
        onPressed: null,
        child: Text('Saving...'),
      ),
    };
  }
}

class _RunMetrics extends StatelessWidget {
  const _RunMetrics({
    required this.distanceText,
    required this.paceText,
    required this.stepText,
  });

  final String distanceText;
  final String paceText;
  final String stepText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FractionallySizedBox(
          widthFactor: 0.47,
          child: _MetricTile(
            label: 'Distance',
            value: distanceText,
            valueKey: const Key('run-distance'),
          ),
        ),
        FractionallySizedBox(
          widthFactor: 0.47,
          child: _MetricTile(
            label: 'Pace',
            value: paceText,
            valueKey: const Key('run-pace'),
          ),
        ),
        FractionallySizedBox(
          widthFactor: 0.47,
          child: _MetricTile(
            label: 'Momentum steps',
            value: stepText,
            valueKey: const Key('run-app-steps'),
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
    required this.signalStatus,
    required this.detailMessage,
    required this.latestAccuracyMeters,
    required this.acceptedPointCount,
    required this.rejectedPointCount,
  });

  final GpsSignalStatus signalStatus;
  final String? detailMessage;
  final double? latestAccuracyMeters;
  final int acceptedPointCount;
  final int rejectedPointCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accuracyText = latestAccuracyMeters == null
        ? '--'
        : '${latestAccuracyMeters!.toStringAsFixed(1)} m';
    final signalColor = _signalColor(colorScheme);
    final label = _gpsStatusLabel();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SignalDot(color: signalColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'GPS: $label',
                    key: const Key('gps-status'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  accuracyText,
                  key: const Key('gps-accuracy'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (detailMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _compactDetailMessage(),
                key: const Key('gps-detail-message'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _GpsStatChip(
                  label: 'Accuracy',
                  value: accuracyText,
                  icon: Icons.my_location,
                ),
                _GpsStatChip(
                  label: 'Accepted',
                  value: acceptedPointCount.toString(),
                  icon: Icons.check_circle_outline,
                  valueKey: const Key('gps-accepted-points'),
                ),
                _GpsStatChip(
                  label: 'Rejected',
                  value: rejectedPointCount.toString(),
                  icon: Icons.filter_alt_outlined,
                  valueKey: const Key('gps-rejected-points'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _gpsStatusLabel() {
    return switch (signalStatus) {
      GpsSignalStatus.dead => 'Unavailable',
      GpsSignalStatus.searching => 'Searching',
      GpsSignalStatus.weak => 'Weak',
      GpsSignalStatus.good => 'Good',
    };
  }

  Color _signalColor(ColorScheme colorScheme) {
    return switch (signalStatus) {
      GpsSignalStatus.dead => colorScheme.error,
      GpsSignalStatus.searching => colorScheme.outline,
      GpsSignalStatus.weak => colorScheme.tertiary,
      GpsSignalStatus.good => colorScheme.primary,
    };
  }

  String _compactDetailMessage() {
    return switch (signalStatus) {
      GpsSignalStatus.good => 'Ready',
      GpsSignalStatus.weak => 'Weak signal - tracking may improve outdoors.',
      GpsSignalStatus.searching => 'Searching for signal...',
      GpsSignalStatus.dead => detailMessage ?? 'Unavailable',
    };
  }
}

class _SignalDot extends StatelessWidget {
  const _SignalDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 12, height: 12),
        ),
      ),
    );
  }
}

class _GpsStatChip extends StatelessWidget {
  const _GpsStatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.valueKey,
  });

  final String label;
  final String value;
  final IconData icon;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              key: valueKey,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
            if (run.appStepCount != null)
              _SummaryRow(
                label: 'Momentum steps',
                value: run.appStepCount.toString(),
              ),
            if (run.healthKitStepCount != null)
              _SummaryRow(
                label: 'Apple tracked',
                value: run.healthKitStepCount.toString(),
              ),
            if (run.healthKitUpdateLagSeconds != null)
              _SummaryRow(
                label: 'Health update',
                value:
                    'Apple Health checked again after ${run.healthKitUpdateLagSeconds} sec.',
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
