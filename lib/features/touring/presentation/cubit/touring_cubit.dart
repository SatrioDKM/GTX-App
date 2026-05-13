import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/foreground_task_handler.dart';
import '../../data/location_service.dart';
import '../../data/livekit_service.dart';
import 'touring_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:livekit_client/livekit_client.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../../data/osrm_service.dart';

class TouringCubit extends Cubit<TouringState> {
  final LocationService _locationService;
  final LiveKitService _livekitService;

  TouringCubit(this._locationService, this._livekitService) : super(TouringInitial());

  String? _roomCode;
  String? _userUid;
  StreamSubscription? _roomEventSub;

  Stream<double> get audioLevelStream => _livekitService.audioLevelStream;
  Stream<double> get speedStream => _locationService.speedStream;
  Stream<Position> get positionStream => _locationService.positionStream;

  // Shared Navigation Streams
  final OsrmService _osrmService = OsrmService();
  final StreamController<List<LatLng>> _polylineController = StreamController<List<LatLng>>.broadcast();
  final StreamController<LatLng?> _destinationController = StreamController<LatLng?>.broadcast();
  final StreamController<double> _distanceToDestController = StreamController<double>.broadcast();

  Stream<List<LatLng>> get polylineStream => _polylineController.stream;
  Stream<LatLng?> get destinationStream => _destinationController.stream;
  Stream<double> get distanceToDestStream => _distanceToDestController.stream;

  LatLng? _currentDestination;
  StreamSubscription? _roomDocSub;
  StreamSubscription? _posSub;
  StreamSubscription? _memberDocSub;

  Future<void> startTouring(String roomCode, String userUid, String userName) async {
    _roomCode = roomCode;
    _userUid = userUid;

    // 1. Mulai background service agar aplikasi tetap hidup di background
    await ForegroundTaskService.startForegroundTask();

    // 2. Mulai tracking lokasi ke Firestore
    _locationService.startTracking(roomCode, userUid);
    
    // 3. Koneksi ke LiveKit
    try {
      await _livekitService.connect(roomCode, userUid, userName);
      
      // 4. Listen ke event Room (Presence)
      _roomEventSub = _livekitService.roomEventStream.listen((event) {
        if (event is RoomDisconnectedEvent) {
          leaveTouring();
        }
      });

      // Default ke loudspeaker & fetch devices
      await _livekitService.toggleSpeaker(true);
      final devices = await _livekitService.getAudioOutputs();

      emit(TouringConnected(
        isMicOn: true,
        isSpeakerOn: true,
        availableDevices: devices,
      ));

      // Sync status mic & presence ke Firestore
      await _syncMicStatus(isMuted: false);
      await _updatePresence(true);

      // --- SHARED NAVIGATION LOGIC ---
      _roomDocSub = FirebaseFirestore.instance.collection('rooms').doc(roomCode.toUpperCase()).snapshots().listen((doc) async {
        if (doc.exists) {
          final data = doc.data()!;
          if (data['destinationLat'] != null && data['destinationLng'] != null) {
            final newDest = LatLng(
              (data['destinationLat'] as num).toDouble(), 
              (data['destinationLng'] as num).toDouble()
            );
            
            if (newDest.latitude == 0 && newDest.longitude == 0) {
              _currentDestination = null;
              _destinationController.add(null);
              _polylineController.add([]);
              _distanceToDestController.add(0.0);
            } else if (_currentDestination == null || 
                _currentDestination!.latitude != newDest.latitude || 
                _currentDestination!.longitude != newDest.longitude) {
              
              _currentDestination = newDest;
              _destinationController.add(newDest);

              // Ambil posisi saat ini untuk tarik rute OSRM
              final pos = await _locationService.getCurrentPosition();
              if (pos != null) {
                // Update distance instantly
                final distanceInMeters = Geolocator.distanceBetween(
                  pos.latitude, pos.longitude,
                  newDest.latitude, newDest.longitude,
                );
                _distanceToDestController.add(distanceInMeters / 1000.0);
                
                final route = await _osrmService.getRoute(
                  LatLng(pos.latitude, pos.longitude), 
                  newDest
                );
                _polylineController.add(route);
              }
            }
          }
        }
      });

      _posSub = positionStream.listen((pos) {
        if (_currentDestination != null) {
          final distanceInMeters = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            _currentDestination!.latitude, _currentDestination!.longitude,
          );
          _distanceToDestController.add(distanceInMeters / 1000.0); // dalam KM
        }
      });
      // --------------------------------

      // --- MEMBER DOC LISTENER (Kick & Remote Mute) ---
      _memberDocSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode.toUpperCase())
          .collection('members')
          .doc(userUid)
          .snapshots()
          .listen((doc) async {
        if (!doc.exists) {
          // KICKED!
          await leaveTouring();
          emit(TouringKicked());
        } else {
          final data = doc.data()!;
          if (data['isMuted'] == true && state is TouringConnected) {
            final currentState = state as TouringConnected;
            if (currentState.isMicOn) {
              await _livekitService.toggleMic(false);
              emit(currentState.copyWith(isMicOn: false));
            }
          }
        }
      });
      // ------------------------------------------------

    } catch (e) {
      emit(TouringError(e.toString()));
    }
  }

  Future<void> toggleMic() async {
    if (state is TouringConnected) {
      final currentState = state as TouringConnected;
      final newMicStatus = !currentState.isMicOn;
      
      await _livekitService.toggleMic(newMicStatus);
      await _syncMicStatus(isMuted: !newMicStatus);
      
      emit(currentState.copyWith(isMicOn: newMicStatus));
    }
  }

  Future<void> toggleSpeaker() async {
    if (state is TouringConnected) {
      final currentState = state as TouringConnected;
      final newSpeakerStatus = !currentState.isSpeakerOn;
      
      await _livekitService.toggleSpeaker(newSpeakerStatus);
      emit(currentState.copyWith(isSpeakerOn: newSpeakerStatus));
    }
  }

  Future<void> refreshAudioDevices() async {
    if (state is TouringConnected) {
      final devices = await _livekitService.getAudioOutputs();
      emit((state as TouringConnected).copyWith(availableDevices: devices));
    }
  }

  Future<List<MediaDevice>> getAvailableAudioDevices() async {
    return await _livekitService.getAudioOutputs();
  }

  Future<void> selectAudioDevice(MediaDevice device) async {
    await _livekitService.setAudioOutput(device);
    // Simple check based on label to update UI state
    final isSpeaker = device.label.toLowerCase().contains('speaker');
    if (state is TouringConnected) {
      emit((state as TouringConnected).copyWith(isSpeakerOn: isSpeaker));
    }
  }

  Future<void> _syncMicStatus({required bool isMuted}) async {
    if (_roomCode == null || _userUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(_roomCode!.toUpperCase())
          .collection('members')
          .doc(_userUid)
          .set({'isMuted': isMuted}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _updatePresence(bool isOnline) async {
    if (_roomCode == null || _userUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(_roomCode!.toUpperCase())
          .collection('members')
          .doc(_userUid)
          .set({
            'status': isOnline ? 'online' : 'offline',
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> leaveTouring() async {
    await _updatePresence(false);
    _locationService.stopTracking();
    await _roomEventSub?.cancel();
    await _roomDocSub?.cancel();
    await _posSub?.cancel();
    await _memberDocSub?.cancel();
    await _livekitService.disconnect();
    await ForegroundTaskService.stopForegroundTask();
    
    emit(TouringInitial());
  }

  @override
  Future<void> close() async {
    _locationService.stopTracking();
    await _roomDocSub?.cancel();
    await _posSub?.cancel();
    await _memberDocSub?.cancel();
    await _livekitService.disconnect();
    await ForegroundTaskService.stopForegroundTask();
    
    _polylineController.close();
    _destinationController.close();
    _distanceToDestController.close();
    
    return super.close();
  }
}
