import 'route_point_request.dart';

class CreateRunRequest {
  const CreateRunRequest({
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.averagePaceSecondsPerKm,
    required this.routePoints,
    this.appStepCount,
    this.healthKitStartStepCount,
    this.healthKitEndStepCount,
    this.healthKitUpdateLagSeconds,
  });

  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int durationSeconds;
  final double averagePaceSecondsPerKm;
  final List<RoutePointRequest> routePoints;
  final int? appStepCount;
  final int? healthKitStartStepCount;
  final int? healthKitEndStepCount;
  final int? healthKitUpdateLagSeconds;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
      'routePoints': routePoints.map((point) => point.toJson()).toList(),
    };

    if (appStepCount != null) {
      json['appStepCount'] = appStepCount;
    }
    if (healthKitStartStepCount != null) {
      json['healthKitStartStepCount'] = healthKitStartStepCount;
    }
    if (healthKitEndStepCount != null) {
      json['healthKitEndStepCount'] = healthKitEndStepCount;
    }
    if (healthKitUpdateLagSeconds != null) {
      json['healthKitUpdateLagSeconds'] = healthKitUpdateLagSeconds;
    }

    return json;
  }
}
