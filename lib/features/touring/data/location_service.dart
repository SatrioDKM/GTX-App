import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_constants.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStream;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  final StreamController<double> _speedController = StreamController<double>.broadcast();

  Stream<double> get speedStream => _speedController.stream;
  Stream<Position> get positionStream => _positionController.stream;

  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void startTracking(String roomCode, String userUid) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    final LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      // Konversi m/s ke km/h
      final speedKmh = position.speed * 3.6;
      
      _speedController.add(speedKmh);
      _positionController.add(position);
      _updateLocationToFirestore(roomCode, userUid, position);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _speedController.add(0);
  }

  Future<void> _updateLocationToFirestore(String roomCode, String userUid, Position position) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomCode.toUpperCase())
          .collection('members')
          .doc(userUid)
          .set({
        'uid': userUid,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Gagal update lokasi ke Firestore: $e');
    }
  }

  // Helper untuk mendapatkan posisi saat ini (sekali panggil)
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
