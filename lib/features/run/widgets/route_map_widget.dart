import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_point_response.dart';

class RouteMapWidget extends StatelessWidget {
  const RouteMapWidget({super.key, required this.routePoints});

  final List<RoutePointResponse> routePoints;

  @override
  Widget build(BuildContext context) {
    final mapPoints = _orderedMapPoints();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (mapPoints.length < 2)
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text('Not enough route points to display map.'),
                ),
              )
            else
              _RouteMap(mapPoints: mapPoints),
          ],
        ),
      ),
    );
  }

  List<LatLng> _orderedMapPoints() {
    final orderedPoints = [...routePoints]
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    return orderedPoints
        .where(
          (point) =>
              point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.latitude >= -90 &&
              point.latitude <= 90 &&
              point.longitude >= -180 &&
              point.longitude <= 180,
        )
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.mapPoints});

  final List<LatLng> mapPoints;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeColor = colorScheme.primary;
    final borderColor = colorScheme.surface;
    final hasSpread = mapPoints.any((point) => point != mapPoints.first);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _midpoint(mapPoints),
            initialZoom: 15,
            initialCameraFit: hasSpread
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(mapPoints),
                    padding: const EdgeInsets.all(32),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mttauto.momentumApp',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: mapPoints,
                  strokeWidth: 5,
                  color: routeColor,
                  borderStrokeWidth: 2,
                  borderColor: borderColor,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: mapPoints.first,
                  width: 44,
                  height: 44,
                  child: _RouteMarker(label: 'S', color: colorScheme.tertiary),
                ),
                Marker(
                  point: mapPoints.last,
                  width: 44,
                  height: 44,
                  child: _RouteMarker(label: 'E', color: colorScheme.error),
                ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }

  LatLng _midpoint(List<LatLng> points) {
    var latitude = 0.0;
    var longitude = 0.0;

    for (final point in points) {
      latitude += point.latitude;
      longitude += point.longitude;
    }

    return LatLng(latitude / points.length, longitude / points.length);
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
