import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/room_service.dart';
import 'room_state.dart';

class RoomCubit extends Cubit<RoomState> {
  final RoomService roomService;

  RoomCubit(this.roomService) : super(RoomInitial());

  Future<void> createRoom(
    String hostUid, {
    String rideName = 'Touring Room',
    int maxMembers = 20,
    bool requireApproval = false,
  }) async {
    emit(RoomLoading());
    try {
      final roomCode = await roomService.createRoom(
        hostUid,
        rideName: rideName,
        maxMembers: maxMembers,
        requireApproval: requireApproval,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_room_code', roomCode.toUpperCase());
      await prefs.setString('auto_join_room_code', roomCode.toUpperCase());
      await prefs.setString('last_host_id', hostUid);
      emit(RoomSuccess(roomCode, hostId: hostUid));
    } catch (e) {
      emit(RoomError(e.toString()));
      emit(RoomInitial());
    }
  }

  Future<void> joinRoom(String roomCode, String userUid) async {
    if (roomCode.trim().isEmpty) {
      emit(const RoomError('Kode room tidak boleh kosong'));
      emit(RoomInitial());
      return;
    }
    
    emit(RoomLoading());
    try {
      final roomData = await roomService.joinRoom(roomCode, userUid);
      final prefs = await SharedPreferences.getInstance();
      final hostId = roomData['hostId'] as String;
      await prefs.setString('last_room_code', roomCode.toUpperCase());
      await prefs.setString('auto_join_room_code', roomCode.toUpperCase());
      await prefs.setString('last_host_id', hostId);
      emit(RoomSuccess(roomCode.toUpperCase(), hostId: hostId));
    } catch (e) {
      if (e.toString().contains('WAITING_FOR_APPROVAL')) {
        emit(RoomWaitingApproval(roomCode.toUpperCase()));
      } else {
        emit(RoomError(e.toString()));
        emit(RoomInitial());
      }
    }
  }

  void resetRoom() {
    emit(RoomInitial());
  }

  Future<void> leaveRoom(String roomCode, String userUid) async {
    try {
      await roomService.leaveRoom(roomCode, userUid);
      final prefs = await SharedPreferences.getInstance();
      // Hanya hapus auto_join_room_code agar tidak ditarik otomatis
      // last_room_code tetap dipertahankan untuk tombol "Reconnect" di UI
      await prefs.remove('auto_join_room_code');
      emit(RoomInitial());
    } catch (e) {
      print('Gagal leave room: $e');
    }
  }
}
