import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

abstract class RunStepClient {
  Future<RunStepStartSnapshot> startRun({required DateTime startTime});

  Future<int?> currentAppStepCount({required DateTime startTime});

  Future<RunStepFinishSnapshot> finishRun({
    required DateTime startTime,
    required DateTime endTime,
  });
}

class RunStepStartSnapshot {
  const RunStepStartSnapshot({this.healthKitStartStepCount});

  final int? healthKitStartStepCount;
}

class RunStepFinishSnapshot {
  const RunStepFinishSnapshot({
    this.appStepCount,
    this.healthKitEndStepCount,
    this.healthKitUpdateLagSeconds,
  });

  final int? appStepCount;
  final int? healthKitEndStepCount;
  final int? healthKitUpdateLagSeconds;
}

RunStepClient createPlatformRunStepClient() {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return const UnsupportedRunStepClient();
  }

  return HealthKitRunStepClient(
    healthFactory: HealthFactory(),
    appStepCounter: const MethodChannelAppStepCounter(),
  );
}

class UnsupportedRunStepClient implements RunStepClient {
  const UnsupportedRunStepClient();

  @override
  Future<RunStepStartSnapshot> startRun({required DateTime startTime}) async {
    return const RunStepStartSnapshot();
  }

  @override
  Future<int?> currentAppStepCount({required DateTime startTime}) async {
    return null;
  }

  @override
  Future<RunStepFinishSnapshot> finishRun({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return const RunStepFinishSnapshot();
  }
}

class HealthKitRunStepClient implements RunStepClient {
  const HealthKitRunStepClient({
    required this.healthFactory,
    required this.appStepCounter,
    this.healthKitLagCheckDelay = const Duration(seconds: 10),
  });

  static const List<HealthDataType> _stepTypes = [HealthDataType.STEPS];

  final HealthFactory healthFactory;
  final AppStepCounter appStepCounter;
  final Duration healthKitLagCheckDelay;

  @override
  Future<RunStepStartSnapshot> startRun({required DateTime startTime}) async {
    final healthKitStartStepCount = await _readHealthKitStepTotal(startTime);
    return RunStepStartSnapshot(
      healthKitStartStepCount: healthKitStartStepCount,
    );
  }

  @override
  Future<int?> currentAppStepCount({required DateTime startTime}) {
    return appStepCounter.queryStepCountSince(startTime);
  }

  @override
  Future<RunStepFinishSnapshot> finishRun({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final appStepCount = await currentAppStepCount(startTime: startTime);
    final firstHealthKitEndStepCount = await _readHealthKitStepTotal(endTime);
    if (firstHealthKitEndStepCount == null ||
        healthKitLagCheckDelay == Duration.zero) {
      return RunStepFinishSnapshot(
        appStepCount: appStepCount,
        healthKitEndStepCount: firstHealthKitEndStepCount,
        healthKitUpdateLagSeconds: 0,
      );
    }

    await Future<void>.delayed(healthKitLagCheckDelay);
    final secondHealthKitEndStepCount = await _readHealthKitStepTotal(
      DateTime.now(),
    );

    return RunStepFinishSnapshot(
      appStepCount: appStepCount,
      healthKitEndStepCount: max(
        firstHealthKitEndStepCount,
        secondHealthKitEndStepCount ?? firstHealthKitEndStepCount,
      ),
      healthKitUpdateLagSeconds: healthKitLagCheckDelay.inSeconds,
    );
  }

  Future<int?> _readHealthKitStepTotal(DateTime through) async {
    try {
      final authorized = await healthFactory.requestAuthorization(_stepTypes);
      if (!authorized) {
        return null;
      }

      final localThrough = through.toLocal();
      final startOfDay = DateTime(
        localThrough.year,
        localThrough.month,
        localThrough.day,
      );
      final points = await healthFactory.getHealthDataFromTypes(
        startOfDay,
        localThrough,
        _stepTypes,
      );

      return points
          .where((point) => point.type == HealthDataType.STEPS)
          .fold<double>(0, (total, point) => total + point.value.toDouble())
          .round();
    } catch (_) {
      return null;
    }
  }
}

abstract class AppStepCounter {
  Future<int?> queryStepCountSince(DateTime startTime);
}

class MethodChannelAppStepCounter implements AppStepCounter {
  const MethodChannelAppStepCounter([
    this._channel = const MethodChannel('momentum.app/run_steps'),
  ]);

  final MethodChannel _channel;

  @override
  Future<int?> queryStepCountSince(DateTime startTime) async {
    try {
      final value = await _channel.invokeMethod<int>('queryAppStepCount', {
        'startTimeMillisecondsSinceEpoch': startTime
            .toUtc()
            .millisecondsSinceEpoch,
      });
      return value == null ? null : max(0, value);
    } catch (_) {
      return null;
    }
  }
}
