import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../models/fitness_summary.dart';
import 'fitness_data_client.dart';
import 'fitness_data_client_stub.dart';

FitnessDataClient createPlatformFitnessDataClient() {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return const UnsupportedFitnessDataClient();
  }

  return HealthFitnessDataClient(
    healthFactory: HealthFactory(),
    now: DateTime.now,
  );
}

class HealthFitnessDataClient implements FitnessDataClient {
  const HealthFitnessDataClient({
    required this._healthFactory,
    required this._now,
  });

  static const List<HealthDataType> _todayTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  final HealthFactory _healthFactory;
  final DateTime Function() _now;

  @override
  Future<FitnessSummary> loadTodaySummary() async {
    try {
      final authorized = await _healthFactory.requestAuthorization(
        List<HealthDataType>.of(_todayTypes),
      );
      if (!authorized) {
        return const FitnessSummary(
          status: FitnessSummaryStatus.permissionDenied,
          message: 'Allow Health access to show today\'s fitness data.',
        );
      }

      final now = _now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final points = await _healthFactory.getHealthDataFromTypes(
        startOfDay,
        now,
        _todayTypes,
      );

      return FitnessSummary(
        status: FitnessSummaryStatus.ready,
        steps: _sum(points, HealthDataType.STEPS).round(),
        distanceMeters: _sum(points, HealthDataType.DISTANCE_WALKING_RUNNING),
        activeCalories: _sum(points, HealthDataType.ACTIVE_ENERGY_BURNED),
      );
    } catch (error) {
      return FitnessSummary(
        status: FitnessSummaryStatus.error,
        message: 'Unable to load today\'s fitness data: $error',
      );
    }
  }

  double _sum(List<HealthDataPoint> points, HealthDataType type) {
    return points
        .where((point) => point.type == type)
        .fold<double>(0, (total, point) => total + point.value.toDouble());
  }
}
