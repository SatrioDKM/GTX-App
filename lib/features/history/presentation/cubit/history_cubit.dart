import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../room/data/room_service.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final RoomService _roomService;
  StreamSubscription? _historySub;

  HistoryCubit(this._roomService) : super(HistoryInitial());

  void loadHistory(String userUid) {
    emit(HistoryLoading());
    _historySub?.cancel();
    
    _historySub = _roomService.getHistoryToursStream(userUid).listen(
      (tours) {
        emit(HistoryLoaded(tours));
      },
      onError: (error) {
        emit(HistoryError(error.toString()));
      },
    );
  }

  @override
  Future<void> close() {
    _historySub?.cancel();
    return super.close();
  }
}
