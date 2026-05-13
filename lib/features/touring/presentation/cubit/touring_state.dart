import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';

abstract class TouringState extends Equatable {
  const TouringState();

  @override
  List<Object?> get props => [];
}

class TouringInitial extends TouringState {}

class TouringConnected extends TouringState {
  final bool isMicOn;
  final bool isSpeakerOn;
  final List<MediaDevice> availableDevices;

  const TouringConnected({
    this.isMicOn = false,
    this.isSpeakerOn = false,
    this.availableDevices = const [],
  });

  @override
  List<Object?> get props => [isMicOn, isSpeakerOn, availableDevices];

  TouringConnected copyWith({
    bool? isMicOn,
    bool? isSpeakerOn,
    List<MediaDevice>? availableDevices,
  }) {
    return TouringConnected(
      isMicOn: isMicOn ?? this.isMicOn,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      availableDevices: availableDevices ?? this.availableDevices,
    );
  }
}

class TouringError extends TouringState {
  final String message;

  const TouringError(this.message);

  @override
  List<Object?> get props => [message];
}

class TouringKicked extends TouringState {}
