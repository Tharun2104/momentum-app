import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_point_request.dart';

class LiveRouteMapWidget extends StatefulWidget {
  const LiveRouteMapWidget({
    super.key,
    required this.routePoints,
    required this.isRunning,
  });

  final List<RoutePointRequest> routePoints;
  final bool isRunning;

  @override
  State<LiveRouteMapWidget> createState() => _LiveRouteMapWidgetState();
}

class _LiveRouteMapWidgetState extends State<LiveRouteMapWidget> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant LiveRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isRunning || widget.routePoints.isEmpty) {
      return;
    }

    final previousLatest = oldWidget.routePoints.isEmpty
        ? null
        : oldWidget.routePoints.last;
    final latest = widget.routePoints.last;
    if (previousLatest == latest) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _mapController.move(_toLatLng(latest), _mapController.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mapPoints = widget.routePoints
        .where(_isValidPoint)
        .map(_toLatLng)
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live route', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (mapPoints.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    widget.isRunning
                        ? 'Waiting for GPS signal...'
                        : 'Map will appear when GPS tracking starts.',
                    key: const Key('run-map-placeholder'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              _LiveRouteMap(
                mapController: _mapController,
                mapPoints: mapPoints,
                isRunning: widget.isRunning,
              ),
          ],
        ),
      ),
    );
  }

  bool _isValidPoint(RoutePointRequest point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  LatLng _toLatLng(RoutePointRequest point) {
    return LatLng(point.latitude, point.longitude);
  }
}

class _LiveRouteMap extends StatelessWidget {
  const _LiveRouteMap({
    required this.mapController,
    required this.mapPoints,
    required this.isRunning,
  });

  final MapController mapController;
  final List<LatLng> mapPoints;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeColor = colorScheme.primary;
    final borderColor = colorScheme.surface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: mapPoints.last, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mttauto.momentumApp',
            ),
            if (mapPoints.length >= 2)
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
            MarkerLayer(markers: _markers(context)),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _markers(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final markers = <Marker>[
      Marker(
        point: mapPoints.first,
        width: 44,
        height: 44,
        child: _RouteMarker(label: 'S', color: colorScheme.tertiary),
      ),
    ];

    if (isRunning) {
      markers.add(
        Marker(
          point: mapPoints.last,
          width: 44,
          height: 44,
          child: _CurrentLocationMarker(color: colorScheme.primary),
        ),
      );
    } else if (mapPoints.length >= 2) {
      markers.add(
        Marker(
          point: mapPoints.last,
          width: 44,
          height: 44,
          child: _RouteMarker(label: 'E', color: colorScheme.error),
        ),
      );
    }

    return markers;
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

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
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
            child: const SizedBox(width: 18, height: 18),
          ),
        ),
      ),
    );
  }
}
