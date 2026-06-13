class RoutePointRequest {
  const RoutePointRequest({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.sequenceNumber,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
  final int sequenceNumber;

  Map<String, Object> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
      'accuracyMeters': accuracyMeters,
      'sequenceNumber': sequenceNumber,
    };
  }
}
