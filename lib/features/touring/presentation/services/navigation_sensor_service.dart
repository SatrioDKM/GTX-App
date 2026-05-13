import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import '../cubit/touring_cubit.dart';

class NavigationSensorService {
  final MapController mapController;
  final AnimatedMapController animatedMapController;
  
  final ValueNotifier<double> compassNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> isCourseUp = ValueNotifier(true);
  final ValueNotifier<bool> isFollowingUser = ValueNotifier(true);

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<double>? _speedSub;

  double _currentSpeed = 0.0;
  bool isNavMode = false;
  bool isMapReady = false;

  NavigationSensorService({
    required this.mapController,
    required this.animatedMapController,
  });

  Position? _lastPosition;

  void init(BuildContext context) {
    // Sensor Fusion: Track Speed
    _speedSub = context.read<TouringCubit>().speedStream.listen((speed) {
      _currentSpeed = speed;
    });

    // Sensor Fusion: Magnetometer (Kecepatan rendah)
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && _currentSpeed < 5.0) {
        headingNotifier.value = event.heading!;
        
        // Buat rotasi peta dan kompas se-responsif marker
        if (isCourseUp.value && isFollowingUser.value && isMapReady && _lastPosition != null) {
          final heading = event.heading!;
          final double rad = heading * math.pi / 180.0;
          const double offset = 0.0015;
          final offsetCenter = LatLng(
            _lastPosition!.latitude + math.cos(rad) * offset,
            _lastPosition!.longitude + math.sin(rad) * offset,
          );
          // Update langsung tanpa delay agar kompas dan arah pandang super smooth
          mapController.moveAndRotate(offsetCenter, 17.5, -heading);
        }
      }
    });

    // Sensor Fusion: GPS Heading & Map Recentering (Kecepatan tinggi / Pergerakan GPS)
    _posSub = context.read<TouringCubit>().positionStream.listen((pos) {
      _lastPosition = pos;
      if (_currentSpeed >= 5.0) {
        headingNotifier.value = pos.heading;
      }
      
      if (isFollowingUser.value) {
        if (_currentSpeed >= 5.0) {
          recenterMap(pos);
        } else {
          // Bypass animasi saat diam/pelan agar magnetometer mengambil alih tanpa konflik
          if (isCourseUp.value && isMapReady) {
            final heading = headingNotifier.value;
            final double rad = heading * math.pi / 180.0;
            const double offset = 0.0015;
            final offsetCenter = LatLng(
              pos.latitude + math.cos(rad) * offset,
              pos.longitude + math.sin(rad) * offset,
            );
            mapController.moveAndRotate(offsetCenter, 17.5, -heading);
          } else if (isMapReady) {
            mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
          }
        }
      }
    });

    // Listen to map events to update compass UI statelessly
    mapController.mapEventStream.listen((event) {
      // If user drags the map manually, stop following user
      if (event.source != MapEventSource.mapController) {
        if (isFollowingUser.value) {
          isFollowingUser.value = false;
        }
      }

      if (isMapReady) {
        compassNotifier.value = mapController.camera.rotation;
      }
    });
  }

  void dispose() {
    _compassSub?.cancel();
    _posSub?.cancel();
    _speedSub?.cancel();
    compassNotifier.dispose();
    headingNotifier.dispose();
    isFollowingUser.dispose();
  }

  Future<void> recenterMap([Position? pos]) async {
    if (!isMapReady) return;
    try {
      final position = pos ?? await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(position.latitude, position.longitude);
      
      isFollowingUser.value = true;
      
      if (isCourseUp.value) {
        final heading = headingNotifier.value;
        final double rad = heading * math.pi / 180.0;
        
        // OFFSET: Agar user berada di 1/4 bawah layar (Google Maps Style)
        const double offset = 0.0015; // Jarak visual ke depan (~150m)
        final offsetCenter = LatLng(
          position.latitude + math.cos(rad) * offset,
          position.longitude + math.sin(rad) * offset,
        );
        animatedMapController.animateTo(dest: offsetCenter, zoom: 17.5, rotation: -heading);
      } else {
        animatedMapController.animateTo(dest: userLatLng, zoom: 17.0, rotation: 0);
      }
    } catch (e) {
      debugPrint('Gagal recenter map: $e');
    }
  }

  void enableNavMode() {
    isNavMode = true;
    isCourseUp.value = true;
    isFollowingUser.value = true;
  }

  void disableNavMode() {
    isNavMode = false;
    isFollowingUser.value = true;
    if (isMapReady && !isCourseUp.value) {
      animatedMapController.animateTo(rotation: 0);
    }
  }

  void onCompassTapped() {
    if (isCourseUp.value) {
      isCourseUp.value = false;
      if (isMapReady && _lastPosition != null) {
        recenterMap(_lastPosition);
      }
    } else {
      isFollowingUser.value = false;
      if (isMapReady) {
        animatedMapController.animateTo(rotation: 0);
      }
    }
  }

  void onRecenterTapped() {
    if (!isFollowingUser.value) {
      // Free Roam -> Center North-Up
      isFollowingUser.value = true;
      isCourseUp.value = false;
    } else if (!isCourseUp.value) {
      // Center North-Up -> Center Course-Up
      isCourseUp.value = true;
    } else {
      // Center Course-Up -> Free Roam
      isFollowingUser.value = false;
      isCourseUp.value = false;
    }
    
    if (isMapReady && _lastPosition != null && isFollowingUser.value) {
      recenterMap(_lastPosition);
    } else if (isFollowingUser.value) {
      recenterMap();
    }
  }
}
