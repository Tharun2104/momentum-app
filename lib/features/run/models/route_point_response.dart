class RoutePointResponse {
  const RoutePointResponse({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.sequenceNumber,
  });

  final int id;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracyMeters;
  final int sequenceNumber;

  factory RoutePointResponse.fromJson(Map<String, dynamic> json) {
    return RoutePointResponse(
      id: json['id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String).toUtc(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      sequenceNumber: json['sequenceNumber'] as int,
    );
  }
}
