import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momentum_app/features/run/data/run_api_service.dart';
import 'package:momentum_app/features/run/models/run_response.dart';
import 'package:momentum_app/features/run/presentation/run_history_screen.dart';
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
    expect(find.text('GPS idle'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
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

class _FakeRunApiService extends RunApiService {
  _FakeRunApiService(this._runs) : super(baseUrl: 'http://example.com');

  final List<RunResponse> _runs;
  final List<int> deletedRunIds = [];

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
