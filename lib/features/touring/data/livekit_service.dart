import 'dart:async';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:audio_session/audio_session.dart';

class LiveKitService {
  final String _url = 'wss://gtx-app-zvt0njjr.livekit.cloud';
  final String _apiKey = 'APITMppApvEh2z3';
  final String _apiSecret = '4u8Zk1PQWuMl0B2C5VdVaz3L4FqS9a8yV8eGC0ta2Re';

  Room? _room;
  
  Room? get room => _room;

  // Stream untuk memonitor level audio secara real-time
  Stream<double> get audioLevelStream async* {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_room != null && _room!.localParticipant != null) {
        yield _room!.localParticipant!.audioLevel;
      } else {
        yield 0.0;
      }
    }
  }

  // Stream untuk event partisipan (Join/Leave)
  Stream<RoomEvent> get roomEventStream {
    if (_room == null) return const Stream.empty();
    
    final controller = StreamController<RoomEvent>();
    final listener = _room!.createListener();
    
    listener.on<RoomEvent>((event) {
      if (!controller.isClosed) {
        controller.add(event);
      }
    });

    controller.onCancel = () => listener.dispose();
    
    return controller.stream;
  }

  String generateToken(String roomId, String participantId, String participantName) {
    // Membuat payload untuk JWT token LiveKit
    final jwt = JWT(
      {
        'sub': participantId,
        'name': participantName,
        'video': {
          'room': roomId,
          'roomJoin': true,
        },
      },
      issuer: _apiKey,
    );

    // Menandatangani token dengan API Key dan Secret
    final token = jwt.sign(
      SecretKey(_apiSecret),
      expiresIn: const Duration(hours: 12),
    );

    return token;
  }

  Future<void> connect(String roomId, String participantId, String participantName) async {
    try {
      // Konfigurasi AudioSession untuk background mic (Communication Mode)
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      final token = generateToken(roomId, participantId, participantName);
      
      _room = Room();
      
      await _room!.connect(
        _url,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      // Auto-publish microphone on connect
      await toggleMic(true);
      
    } catch (e) {
      throw Exception('Gagal terkoneksi ke LiveKit: $e');
    }
  }

  Future<void> toggleMic(bool enable) async {
    if (_room == null || _room!.localParticipant == null) return;
    
    await _room!.localParticipant!.setMicrophoneEnabled(enable);
  }

  Future<void> toggleSpeaker(bool enable) async {
    await Hardware.instance.setSpeakerphoneOn(enable);
  }

  Future<List<MediaDevice>> getAudioOutputs() async {
    return await Hardware.instance.audioOutputs();
  }

  Future<void> setAudioOutput(MediaDevice device) async {
    if (_room == null) return;
    await _room!.setAudioOutputDevice(device);
  }

  Future<void> disconnect() async {
    if (_room != null) {
      await toggleMic(false); // Pastikan mic mati sebelum keluar
      await _room!.disconnect();
      _room = null;
    }
  }
}
