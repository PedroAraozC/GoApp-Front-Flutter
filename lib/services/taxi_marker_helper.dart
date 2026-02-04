// lib/services/taxi_marker_helper.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TaxiMarkerHelper {
  TaxiMarkerHelper._();
  static final TaxiMarkerHelper instance = TaxiMarkerHelper._();

  final Map<String, BitmapDescriptor> _cache = {};

  /// Normalize bearing to 0..360
  double _norm(double b) {
    var x = b % 360;
    if (x < 0) x += 360;
    return x;
  }

  /// Choose which sprite (front/right/back/left) to show based on bearing.
  String assetForBearing(double bearing, {int size = 96}) {
    final b = _norm(bearing);
    if (b >= 45 && b < 135) return 'assets/markers/taxi_right_$size.png';
    if (b >= 135 && b < 225) return 'assets/markers/taxi_back_$size.png';
    if (b >= 225 && b < 315) return 'assets/markers/taxi_left_$size.png';
    return 'assets/markers/taxi_front_$size.png';
  }

  /// Anchor tuned so the "wheel/axle" sits on the GPS point.
  /// You can micro-adjust these:
  ///  - Increase y => moves marker down
  ///  - Decrease y => moves marker up
  Offset anchorForBearing(double bearing) {
    final b = _norm(bearing);
    if (b >= 45 && b < 135) return const Offset(0.45, 0.80); // right
    if (b >= 135 && b < 225) return const Offset(0.50, 0.80); // back
    if (b >= 225 && b < 315) return const Offset(0.45, 0.80); // left
    return const Offset(0.50, 0.80); // front
  }

  /// Cached load (important for real-time updates).
  Future<BitmapDescriptor> loadIcon(double bearing, {int size = 96}) async {
    final asset = assetForBearing(bearing, size: size);
    final key = asset;
    final cached = _cache[key];
    if (cached != null) return cached;

    final icon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(size.toDouble(), size.toDouble())),
      asset,
    );
    _cache[key] = icon;
    return icon;
  }

  /// Build marker with rotation + anchor.
  /// NOTE: flat:true is required for rotation to apply.
  Marker build({
    required String id,
    required LatLng position,
    required BitmapDescriptor icon,
    required double bearing,
    required Offset anchor,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      anchor: anchor,
      flat: true,
      rotation: _norm(bearing),
      onTap: onTap,
    );
  }
}
