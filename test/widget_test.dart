import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:momentum_app/features/run/data/run_api_service.dart';
import 'package:momentum_app/features/run/models/create_run_request.dart';
import 'package:momentum_app/features/run/models/route_point_response.dart';
import 'package:momentum_app/features/run/models/run_response.dart';
import 'package:momentum_app/features/run/presentation/run_history_screen.dart';
import 'package:momentum_app/features/run/presentation/run_screen.dart';
import 'package:momentum_app/main.dart';

void main() {
  testWidgets('opens the run screen from home', (tester) async {
    await tester.pumpWidget(const MomentumApp());

    expect(find.text('Momentum'), findsWidgets);
    expect(find.text('Track your run with focus'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('0.00 km'), findsOneWidget);
    expect(find.text('-- /km'), findsOneWidget);
    expect(find.byKey(const Key('gps-status')), findsOneWidget);
    expect(
      find.text('Map will appear when GPS tracking starts.'),
      findsOneWidget,
    );
    expect(find.text('Start'), findsOneWidget);
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

RunResponse _runResponse() {
  final startTime = DateTime.parse('2026-06-13T10:00:00Z');

  return RunResponse(
    id: 1,
    startTime: startTime,
    endTime: startTime.add(const Duration(minutes: 6)),
    distanceMeters: 1000,
    durationSeconds: 360,
    averagePaceSecondsPerKm: 360,
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
