import 'route_point_response.dart';

class RunResponse {
  const RunResponse({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.averagePaceSecondsPerKm,
    required this.createdAt,
    required this.updatedAt,
    required this.routePoints,
  });

  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int durationSeconds;
  final double averagePaceSecondsPerKm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RoutePointResponse> routePoints;

  factory RunResponse.fromJson(Map<String, dynamic> json) {
    final routePointsJson = json['routePoints'] as List<dynamic>? ?? [];

    return RunResponse(
      id: json['id'] as int,
      startTime: DateTime.parse(json['startTime'] as String).toUtc(),
      endTime: DateTime.parse(json['endTime'] as String).toUtc(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      averagePaceSecondsPerKm: (json['averagePaceSecondsPerKm'] as num)
          .toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      routePoints: routePointsJson
          .map(
            (point) =>
                RoutePointResponse.fromJson(point as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
