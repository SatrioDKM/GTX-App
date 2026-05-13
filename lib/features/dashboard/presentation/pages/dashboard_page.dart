import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../room/presentation/pages/home_page.dart';
import '../../../room/presentation/cubit/room_cubit.dart';
import '../../../history/presentation/pages/history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import 'package:gtx_app/features/touring/presentation/pages/touring_page.dart';
import 'friends_tab.dart';
import 'profile_tab.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 2; // Default ke tab Home

  final List<Widget> _pages = [
    const HistoryPage(),
    FriendsTab(),
    const HomePage(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-archive expired rooms
    context.read<RoomCubit>().roomService.archiveExpiredRooms();
    
    // Cek Auto-Join
    _checkAutoJoin();
  }

  Future<void> _checkAutoJoin() async {
    final prefs = await SharedPreferences.getInstance();
    final roomCode = prefs.getString('auto_join_room_code');
    final hostId = prefs.getString('last_host_id');

    if (roomCode != null && hostId != null) {
      final authState = context.read<AuthCubit>().state;
      if (authState is Authenticated) {
        final uid = authState.user.uid;
        final name = authState.user.displayName ?? 'User';
        
        try {
          final memberDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomCode)
              .collection('members')
              .doc(uid)
              .get();
              
          final roomDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomCode)
              .get();
              
          if (memberDoc.exists && roomDoc.exists) {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TouringPage(
                    roomCode: roomCode,
                    userUid: uid,
                    userName: name,
                    hostId: hostId,
                  ),
                ),
              );
            }
          } else {
             // Bersihkan jika ternyata room sudah dihapus atau user sudah di-kick
             await prefs.remove('last_room_code');
             await prefs.remove('last_host_id');
          }
        } catch (e) {
          debugPrint('Auto-join check failed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.history),
            ),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.users),
            ),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.home),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.user),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
