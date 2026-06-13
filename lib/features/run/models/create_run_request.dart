import 'route_point_request.dart';

class CreateRunRequest {
  const CreateRunRequest({
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.averagePaceSecondsPerKm,
    required this.routePoints,
  });

  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int durationSeconds;
  final double averagePaceSecondsPerKm;
  final List<RoutePointRequest> routePoints;

  Map<String, Object> toJson() {
    return {
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'averagePaceSecondsPerKm': averagePaceSecondsPerKm,
      'routePoints': routePoints.map((point) => point.toJson()).toList(),
    };
  }
}
