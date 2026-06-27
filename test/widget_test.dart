import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:momentum_app/core/navigation/app_router.dart';
import 'package:momentum_app/features/fitness/data/fitness_data_client.dart';
import 'package:momentum_app/features/fitness/models/fitness_summary.dart';
import 'package:momentum_app/features/fitness/presentation/fitness_screen.dart';
import 'package:momentum_app/features/friends/data/friends_repository.dart';
import 'package:momentum_app/features/friends/domain/friend_request.dart';
import 'package:momentum_app/features/friends/domain/friend_user.dart';
import 'package:momentum_app/features/friends/presentation/friends_providers.dart';
import 'package:momentum_app/features/run/data/run_api_service.dart';
import 'package:momentum_app/features/run/models/create_run_request.dart';
import 'package:momentum_app/features/run/models/route_point_response.dart';
import 'package:momentum_app/features/run/models/run_response.dart';
import 'package:momentum_app/features/run/presentation/run_detail_screen.dart';
import 'package:momentum_app/features/run/presentation/run_history_screen.dart';
import 'package:momentum_app/features/run/data/run_step_client.dart';
import 'package:momentum_app/features/run/presentation/run_screen.dart';
import 'package:momentum_app/main.dart';

void main() {
  testWidgets('shows login before app content', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MomentumApp()));
    await tester.pumpAndSettle();

    expect(find.text('Momentum'), findsWidgets);
    expect(find.text('Track your life with focus'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('opens fitness from home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(_FakeFriendsRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: createAppRouter(
            isAuthenticated: true,
            isCheckingAuth: false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fitness'));
    await tester.pumpAndSettle();

    expect(find.text('Fitness'), findsWidgets);
    expect(find.text("Today's activity from Apple Health"), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
  });

  testWidgets('fitness screen displays today health totals', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FitnessScreen(
          fitnessDataClient: _FakeFitnessDataClient(
            const FitnessSummary(
              status: FitnessSummaryStatus.ready,
              steps: 12482,
              distanceMeters: 7420,
              activeCalories: 531,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12,482'), findsOneWidget);
    expect(find.text('7.42 km'), findsOneWidget);
    expect(find.text('531 kcal'), findsOneWidget);
  });

  testWidgets('fitness screen handles permission denial', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FitnessScreen(
          fitnessDataClient: _FakeFitnessDataClient(
            const FitnessSummary(
              status: FitnessSummaryStatus.permissionDenied,
              message: 'Allow Health access to show today\'s fitness data.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Allow Health access to show today\'s fitness data.'),
      findsOneWidget,
    );
  });

  testWidgets('disables start when GPS is unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RunScreen(
          locationClient: _FakeLocationClient(serviceEnabled: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS: Unavailable'), findsOneWidget);
    expect(find.text('Location services are off.'), findsOneWidget);
    expect(find.text('Enable location to start'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('run-action-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('disables start when location permission is denied', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RunScreen(
          locationClient: _FakeLocationClient(
            permission: LocationPermission.denied,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS: Unavailable'), findsOneWidget);
    expect(find.text('Location permission denied.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('run-action-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('keeps start enabled when GPS is weak', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RunScreen(
          locationClient: _FakeLocationClient(
            currentPosition: _position(accuracy: 35),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS: Weak'), findsOneWidget);
    expect(find.text('Weak signal, but you can start.'), findsOneWidget);
    expect(_textValue(tester, const Key('gps-accuracy')), '35.0 m');

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('run-action-button')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('pauses and resumes without saving or counting paused GPS', (
    tester,
  ) async {
    final locationClient = _FakeLocationClient(
      currentPosition: _position(
        latitude: 35.22710,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:00Z'),
      ),
    );
    final runApiService = _FakeRunApiService([]);
    final clock = _FakeClock(DateTime.parse('2026-06-13T10:00:00Z'));

    await tester.pumpWidget(
      MaterialApp(
        home: RunScreen(
          runApiService: runApiService,
          locationClient: locationClient,
          now: clock.now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('run-action-button')));
    await tester.tap(find.byKey(const Key('run-action-button')));
    await tester.pump();
    clock.advance(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    locationClient.addPosition(
      _position(
        latitude: 35.22710,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:00Z'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    locationClient.addPosition(
      _position(
        latitude: 35.22720,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:10Z'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Status: Running'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    final runningAcceptedPoints = _intValue(
      tester,
      const Key('gps-accepted-points'),
    );
    expect(runningAcceptedPoints, greaterThanOrEqualTo(2));

    await tester.ensureVisible(find.byKey(const Key('run-pause-button')));
    await tester.tap(find.byKey(const Key('run-pause-button')));
    await tester.pump();
    final pausedDistance = tester
        .widget<Text>(find.byKey(const Key('run-distance')))
        .data;
    final pausedPace = tester
        .widget<Text>(find.byKey(const Key('run-pace')))
        .data;

    locationClient.addPosition(
      _position(
        latitude: 35.22800,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:20Z'),
      ),
    );
    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('Status: Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Paused - GPS points are not counted.'), findsOneWidget);
    expect(runApiService.createdRuns, isEmpty);
    expect(
      tester.widget<Text>(find.byKey(const Key('run-distance'))).data,
      pausedDistance,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('run-pace'))).data,
      pausedPace,
    );
    expect(
      _intValue(tester, const Key('gps-accepted-points')),
      runningAcceptedPoints,
    );

    await tester.ensureVisible(find.byKey(const Key('run-resume-button')));
    await tester.tap(find.byKey(const Key('run-resume-button')));
    await tester.pump();
    clock.advance(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    locationClient.addPosition(
      _position(
        latitude: 35.22800,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:30Z'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Status: Running'), findsOneWidget);
    expect(runApiService.createdRuns, isEmpty);
    expect(
      _intValue(tester, const Key('gps-accepted-points')),
      runningAcceptedPoints + 1,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('run-distance'))).data,
      pausedDistance,
    );

    locationClient.addPosition(
      _position(
        latitude: 35.22810,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:40Z'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    locationClient.addPosition(
      _position(
        latitude: 35.22820,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:50Z'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final finalAcceptedPoints = _intValue(
      tester,
      const Key('gps-accepted-points'),
    );
    expect(finalAcceptedPoints, runningAcceptedPoints + 3);

    await tester.ensureVisible(find.byKey(const Key('run-stop-button')));
    await tester.pump(const Duration(milliseconds: 300));
    final stopButton = tester.widget<FilledButton>(
      find.byKey(const Key('run-stop-button')),
    );
    expect(stopButton.onPressed, isNotNull);
    stopButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run-error')), findsNothing);
    expect(runApiService.createdRuns, hasLength(1));
    expect(runApiService.createdRuns.single.durationSeconds, lessThan(10));
    expect(
      runApiService.createdRuns.single.routePoints,
      hasLength(finalAcceptedPoints),
    );
    expect(
      runApiService.createdRuns.single.routePoints.last.sequenceNumber,
      finalAcceptedPoints,
    );
    expect(find.text('Run saved successfully'), findsOneWidget);
  });

  testWidgets('tracks app steps and saves Apple Health step comparison', (
    tester,
  ) async {
    final locationClient = _FakeLocationClient(
      currentPosition: _position(
        latitude: 35.22710,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:00Z'),
      ),
    );
    final runApiService = _FakeRunApiService([]);
    final stepClient = _FakeRunStepClient(
      startSnapshot: const RunStepStartSnapshot(healthKitStartStepCount: 47000),
      appStepCounts: [24, 48],
      finishSnapshot: const RunStepFinishSnapshot(
        appStepCount: 72,
        healthKitEndStepCount: 47065,
        healthKitUpdateLagSeconds: 10,
      ),
    );
    final clock = _FakeClock(DateTime.parse('2026-06-13T10:00:00Z'));

    await tester.pumpWidget(
      MaterialApp(
        home: RunScreen(
          runApiService: runApiService,
          locationClient: locationClient,
          stepClient: stepClient,
          now: clock.now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('run-action-button')));
    await tester.tap(find.byKey(const Key('run-action-button')));
    await tester.pump();

    expect(find.text('Momentum steps'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);

    clock.advance(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));

    locationClient.addPosition(
      _position(
        latitude: 35.22710,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:00Z'),
      ),
    );
    await tester.pump();
    locationClient.addPosition(
      _position(
        latitude: 35.22720,
        longitude: -80.84310,
        timestamp: DateTime.parse('2026-06-13T10:00:10Z'),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('run-stop-button')));
    final stopButton = tester.widget<FilledButton>(
      find.byKey(const Key('run-stop-button')),
    );
    stopButton.onPressed!();
    await tester.pumpAndSettle();

    expect(runApiService.createdRuns, hasLength(1));
    expect(runApiService.createdRuns.single.appStepCount, 72);
    expect(runApiService.createdRuns.single.healthKitStartStepCount, 47000);
    expect(runApiService.createdRuns.single.healthKitEndStepCount, 47065);
    expect(runApiService.createdRuns.single.healthKitUpdateLagSeconds, 10);
    expect(find.text('Momentum steps'), findsWidgets);
    expect(find.text('72'), findsWidgets);
    expect(find.text('Apple tracked'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(
      find.text('Apple Health checked again after 10 sec.'),
      findsOneWidget,
    );
  });

  testWidgets('deletes a run from history after confirmation', (tester) async {
    final runApiService = _FakeRunApiService([_runResponse()]);

    await tester.pumpWidget(
      MaterialApp(home: RunHistoryScreen(runApiService: runApiService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.00 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete run'));
    await tester.pumpAndSettle();

    expect(find.text('Delete run?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(runApiService.deletedRunIds, [1]);
    expect(find.text('No runs yet'), findsOneWidget);
    expect(find.text('Run deleted'), findsOneWidget);
  });

  testWidgets('run detail displays saved step comparison', (tester) async {
    final runApiService = _FakeRunApiService([
      _runResponse(
        appStepCount: 1800,
        healthKitStartStepCount: 47000,
        healthKitEndStepCount: 48720,
        healthKitStepCount: 1720,
        healthKitUpdateLagSeconds: 10,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: RunDetailScreen(runId: 1, runApiService: runApiService),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Momentum steps'), findsOneWidget);
    expect(find.text('1800'), findsOneWidget);
    expect(find.text('Apple tracked'), findsOneWidget);
    expect(find.text('1720'), findsOneWidget);
    expect(
      find.text('Apple Health checked again after 10 sec.'),
      findsOneWidget,
    );
  });
}

String? _textValue(WidgetTester tester, Key key) {
  return tester.widget<Text>(find.byKey(key)).data;
}

int _intValue(WidgetTester tester, Key key) {
  return int.parse(_textValue(tester, key)!);
}

class _FakeRunApiService extends RunApiService {
  _FakeRunApiService(this._runs) : super(baseUrl: 'http://example.com');

  final List<RunResponse> _runs;
  final List<int> deletedRunIds = [];
  final List<CreateRunRequest> createdRuns = [];

  @override
  Future<RunResponse> createRun(CreateRunRequest request) async {
    createdRuns.add(request);
    final now = DateTime.parse('2026-06-13T10:30:00Z');

    return RunResponse(
      id: 100 + createdRuns.length,
      startTime: request.startTime,
      endTime: request.endTime,
      distanceMeters: request.distanceMeters,
      durationSeconds: request.durationSeconds,
      averagePaceSecondsPerKm: request.averagePaceSecondsPerKm,
      appStepCount: request.appStepCount,
      healthKitStartStepCount: request.healthKitStartStepCount,
      healthKitEndStepCount: request.healthKitEndStepCount,
      healthKitStepCount:
          request.healthKitStartStepCount == null ||
              request.healthKitEndStepCount == null
          ? null
          : request.healthKitEndStepCount! - request.healthKitStartStepCount!,
      healthKitUpdateLagSeconds: request.healthKitUpdateLagSeconds,
      createdAt: now,
      updatedAt: now,
      routePoints: List.generate(request.routePoints.length, (index) {
        final point = request.routePoints[index];
        return RoutePointResponse(
          id: index + 1,
          latitude: point.latitude,
          longitude: point.longitude,
          recordedAt: point.recordedAt,
          accuracyMeters: point.accuracyMeters,
          sequenceNumber: point.sequenceNumber,
        );
      }),
    );
  }

  @override
  Future<List<RunResponse>> getRuns() async {
    return List.unmodifiable(_runs);
  }

  @override
  Future<RunResponse> getRunById(int id) async {
    return _runs.singleWhere((run) => run.id == id);
  }

  @override
  Future<void> deleteRun(int id) async {
    deletedRunIds.add(id);
    _runs.removeWhere((run) => run.id == id);
  }
}

class _FakeLocationClient implements RunLocationClient {
  _FakeLocationClient({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    Position? currentPosition,
  }) : currentPosition = currentPosition ?? _position(accuracy: 8);

  final bool serviceEnabled;
  final LocationPermission permission;
  final Position currentPosition;
  final StreamController<Position> _positionStreamController =
      StreamController<Position>.broadcast();

  @override
  Future<LocationPermission> checkPermission() async {
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings settings,
  }) async {
    return currentPosition;
  }

  @override
  Stream<Position> getPositionStream({required LocationSettings settings}) {
    return _positionStreamController.stream;
  }

  void addPosition(Position position) {
    _positionStreamController.add(position);
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return permission;
  }
}

class _FakeFitnessDataClient implements FitnessDataClient {
  const _FakeFitnessDataClient(this.summary);

  final FitnessSummary summary;

  @override
  Future<FitnessSummary> loadTodaySummary() async {
    return summary;
  }
}

class _FakeRunStepClient implements RunStepClient {
  _FakeRunStepClient({
    required this.startSnapshot,
    required this.finishSnapshot,
    required List<int> appStepCounts,
  }) : _appStepCounts = Queue<int>.of(appStepCounts);

  final RunStepStartSnapshot startSnapshot;
  final RunStepFinishSnapshot finishSnapshot;
  final Queue<int> _appStepCounts;

  @override
  Future<RunStepStartSnapshot> startRun({required DateTime startTime}) async {
    return startSnapshot;
  }

  @override
  Future<int?> currentAppStepCount({required DateTime startTime}) async {
    if (_appStepCounts.isEmpty) {
      return null;
    }

    return _appStepCounts.removeFirst();
  }

  @override
  Future<RunStepFinishSnapshot> finishRun({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return finishSnapshot;
  }
}

class _FakeFriendsRepository implements FriendsRepository {
  @override
  Future<FriendRequest> acceptRequest(int requestId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FriendUser>> getFriends() async => [];

  @override
  Future<void> deleteFriend(int friendUserId) async {}

  @override
  Future<List<FriendRequest>> getIncomingRequests() async => [];

  @override
  Future<List<FriendRequest>> getOutgoingRequests() async => [];

  @override
  Future<FriendRequest> rejectRequest(int requestId) {
    throw UnimplementedError();
  }

  @override
  Future<FriendRequest> sendRequest(int receiverUserId) {
    throw UnimplementedError();
  }

  @override
  Future<FriendUser> searchUser(String email) {
    throw UnimplementedError();
  }
}

class _FakeClock {
  _FakeClock(this._now);

  DateTime _now;

  DateTime now() {
    return _now;
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

RunResponse _runResponse({
  int? appStepCount,
  int? healthKitStartStepCount,
  int? healthKitEndStepCount,
  int? healthKitStepCount,
  int? healthKitUpdateLagSeconds,
}) {
  final startTime = DateTime.parse('2026-06-13T10:00:00Z');

  return RunResponse(
    id: 1,
    startTime: startTime,
    endTime: startTime.add(const Duration(minutes: 6)),
    distanceMeters: 1000,
    durationSeconds: 360,
    averagePaceSecondsPerKm: 360,
    appStepCount: appStepCount,
    healthKitStartStepCount: healthKitStartStepCount,
    healthKitEndStepCount: healthKitEndStepCount,
    healthKitStepCount: healthKitStepCount,
    healthKitUpdateLagSeconds: healthKitUpdateLagSeconds,
    createdAt: startTime,
    updatedAt: startTime,
    routePoints: const [],
  );
}

Position _position({
  double accuracy = 8,
  double latitude = 35.2271,
  double longitude = -80.8431,
  DateTime? timestamp,
}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: timestamp ?? DateTime.parse('2026-06-13T10:00:00Z'),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
