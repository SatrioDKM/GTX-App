import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_service.dart';
import '../../data/user_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> with WidgetsBindingObserver {
  final AuthService _authService;
  final UserService _userService = UserService();

  AuthCubit(this._authService) : super(AuthInitial()) {
    _checkAuthStatus();
    WidgetsBinding.instance.addObserver(this);
  }

  void _checkAuthStatus() async {
    emit(AuthLoading());
    final user = _authService.getCurrentUser();
    if (user != null) {
      // Pastikan status online tersinkron saat aplikasi dibuka
      await _userService.syncUserProfile(user);
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authState = this.state;
    if (authState is Authenticated) {
      if (state == AppLifecycleState.resumed) {
        _userService.syncUserProfile(authState.user);
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _userService.setOffline(authState.user.uid);
      }
    }
  }

  Future<void> loginWithGoogle() async {
    emit(AuthLoading());
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        await _userService.syncUserProfile(user);
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    final user = _authService.getCurrentUser();
    if (user != null) {
      await _userService.setOffline(user.uid);
    }
    await _authService.signOut();
    emit(Unauthenticated());
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
