import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/room/presentation/cubit/room_cubit.dart';

class SocialOverlayManager {
  static final SocialOverlayManager _instance = SocialOverlayManager._internal();
  factory SocialOverlayManager() => _instance;
  SocialOverlayManager._internal();

  StreamSubscription? _inviteSub;
  StreamSubscription? _friendSub;
  OverlayEntry? _activeEntry;
  BuildContext? _context;

  void init(BuildContext context) {
    _context = context;
    final authCubit = context.read<AuthCubit>();
    
    authCubit.stream.listen((state) {
      if (state is Authenticated) {
        _startListening(state.user.uid);
      } else {
        _stopListening();
      }
    });

    // Check current state
    if (authCubit.state is Authenticated) {
      _startListening((authCubit.state as Authenticated).user.uid);
    }
  }

  void _startListening(String uid) {
    _stopListening();

    // Listen to Room Invites
    _inviteSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final invites = doc.data()?['invitations'] as List?;
      if (invites != null && invites.isNotEmpty) {
        // Show only the latest invite as a popup
        final latest = Map<String, dynamic>.from(invites.last);
        _showInvitePopup(latest, uid);
      }
    });

    // Listen to Friend Requests
    _friendSub = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        for (var doc in snap.docs) {
          _showFriendRequestPopup(doc.data(), doc.id);
        }
      }
    });
  }

  void _stopListening() {
    _inviteSub?.cancel();
    _friendSub?.cancel();
    _hidePopup();
  }

  void _showInvitePopup(Map<String, dynamic> invite, String myUid) {
    _showPopup(
      title: 'Undangan Touring!',
      message: '${invite['fromName']} mengajak Anda ke "${invite['rideName']}"',
      icon: Icons.rocket_launch_rounded,
      primaryActionText: 'JOIN',
      onPrimaryAction: () {
        if (_context != null) {
          _context!.read<RoomCubit>().joinRoom(invite['roomCode'], myUid);
          _hidePopup();
        }
      },
    );
  }

  void _showFriendRequestPopup(Map<String, dynamic> data, String requestId) {
    // We would need friend's name here, usually fetched once
    _showPopup(
      title: 'Permintaan Pertemanan',
      message: 'Seseorang ingin berteman dengan Anda.',
      icon: Icons.person_add_alt_1_rounded,
      primaryActionText: 'LIHAT',
      onPrimaryAction: () {
        // Navigate to friends tab or show detail
        _hidePopup();
      },
    );
  }

  void _showPopup({
    required String title,
    required String message,
    required IconData icon,
    required String primaryActionText,
    required VoidCallback onPrimaryAction,
  }) {
    if (_context == null) return;
    _hidePopup();

    final overlay = Overlay.of(_context!);
    
    _activeEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _PopupWidget(
            title: title,
            message: message,
            icon: icon,
            primaryActionText: primaryActionText,
            onPrimaryAction: onPrimaryAction,
            onDismiss: _hidePopup,
          ),
        ),
      ),
    );

    overlay.insert(_activeEntry!);

    // Auto dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () => _hidePopup());
  }

  void _hidePopup() {
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _PopupWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String primaryActionText;
  final VoidCallback onPrimaryAction;
  final VoidCallback onDismiss;

  const _PopupWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.primaryActionText,
    required this.onPrimaryAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onPrimaryAction,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(primaryActionText, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('NANTI', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
