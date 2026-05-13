import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';

import 'features/room/data/room_service.dart';
import 'features/room/presentation/cubit/room_cubit.dart';

import 'features/touring/data/location_service.dart';
import 'features/touring/data/livekit_service.dart';
import 'features/touring/presentation/cubit/touring_cubit.dart';

import 'features/history/presentation/cubit/history_cubit.dart';

import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'core/theme/theme_cubit.dart';
import 'core/utils/social_overlay_manager.dart';
import 'features/touring/presentation/cubit/touring_cubit.dart';
import 'core/services/foreground_task_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize background service
  await ForegroundTaskService.initForegroundTask();

  runApp(const GTXApp());
}

class GTXApp extends StatelessWidget {
  const GTXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(create: (context) => AuthCubit(AuthService())),
        BlocProvider(create: (context) => RoomCubit(RoomService())),
        BlocProvider(create: (context) => HistoryCubit(RoomService())),
        BlocProvider(create: (context) => TouringCubit(LocationService(), LiveKitService())),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'GTX Touring Xperience',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0052CC), // Royal Blue
                primary: const Color(0xFF0052CC),
                surface: Colors.white,
                background: Colors.white,
                brightness: Brightness.light,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Modern off-white
              cardTheme: CardThemeData(
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shadowColor: const Color(0xFF0052CC).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0052CC),
                primary: const Color(0xFF0052CC),
                brightness: Brightness.dark,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
              scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark Navy Slate
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              // Initialize Overlay Manager once context is available
              SocialOverlayManager().init(context);
              return child!;
            },
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (state is Authenticated) {
          return const DashboardPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
