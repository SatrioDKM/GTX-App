import 'package:equatable/equatable.dart';

abstract class RoomState extends Equatable {
  const RoomState();

  @override
  List<Object?> get props => [];
}

class RoomInitial extends RoomState {}

class RoomLoading extends RoomState {}

class RoomSuccess extends RoomState {
  final String roomCode;
  final String hostId;

  const RoomSuccess(this.roomCode, {required this.hostId});

  @override
  List<Object?> get props => [roomCode, hostId];
}

class RoomError extends RoomState {
  final String message;

  const RoomError(this.message);

  @override
  List<Object?> get props => [message];
}

class RoomWaitingApproval extends RoomState {
  final String roomCode;

  const RoomWaitingApproval(this.roomCode);

  @override
  List<Object?> get props => [roomCode];
}
