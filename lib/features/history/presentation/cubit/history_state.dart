abstract class HistoryState {}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<Map<String, dynamic>> tours;
  HistoryLoaded(this.tours);
}

class HistoryError extends HistoryState {
  final String message;
  HistoryError(this.message);
}
