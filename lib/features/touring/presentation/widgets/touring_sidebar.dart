import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../auth/data/user_service.dart';
import '../../../room/data/room_service.dart';
import 'invite_friend_popup.dart';

/// Widget Drawer yang menampilkan daftar anggota room secara real-time dari Firestore.
class TouringSidebar extends StatefulWidget {
  final String roomCode;
  final String hostId;
  final String myUid;
  final String myName;

  const TouringSidebar({
    super.key,
    required this.roomCode,
    required this.hostId,
    required this.myUid,
    required this.myName,
  });

  @override
  State<TouringSidebar> createState() => _TouringSidebarState();
}

class _TouringSidebarState extends State<TouringSidebar> {
  final RoomService _roomService = RoomService();

  @override
  Widget build(BuildContext context) {
    final roomCode = widget.roomCode;
    final hostId = widget.hostId;
    final myUid = widget.myUid;
    final myName = widget.myName;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final isIHost = myUid == hostId;

    return Drawer(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anggota Room',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Room: $roomCode',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.5,
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: roomCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kode Room disalin ke clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Section: Permintaan Bergabung (Hanya untuk Host)
            if (isIHost)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomCode.toUpperCase())
                    .collection('pending_approvals')
                    .snapshots(),
                builder: (context, snapshot) {
                  final pending = snapshot.data?.docs ?? [];
                  if (pending.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Permintaan Bergabung (${pending.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orangeAccent,
                          ),
                        ),
                      ),
                      ...pending.map((doc) {
                        final pData = doc.data() as Map<String, dynamic>;
                        final pUid = pData['uid'] as String;
                        
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(pUid).get(),
                          builder: (context, userSnap) {
                            final name = (userSnap.data?.data() as Map<String, dynamic>?)?['displayName'] ?? pUid;
                            return ListTile(
                              dense: true,
                              title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 22),
                                    onPressed: () => _roomService.approveMember(roomCode, pUid, true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 22),
                                    onPressed: () => _roomService.approveMember(roomCode, pUid, false),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }),
                      const Divider(),
                    ],
                  );
                },
              ),

            const SizedBox(height: 8),

            // Daftar member real-time dari Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomCode.toUpperCase())
                    .collection('members')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada anggota',
                        style: TextStyle(color: textColor.withValues(alpha: 0.5)),
                      ),
                    );
                  }

                  final members = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final data = members[index].data() as Map<String, dynamic>;
                      final uid = data['uid'] as String? ?? '';
                      final role = data['role'] as String? ?? 'member';
                      final isMuted = data['isMuted'] as bool? ?? false;
                      final isHost = uid == hostId;

                      return _MemberListTile(
                        uid: uid,
                        myUid: myUid,
                        role: role,
                        isMuted: isMuted,
                        isHost: isHost,
                        isIHost: isIHost,
                        roomCode: roomCode,
                        status: data['status'] as String? ?? 'offline',
                        textColor: textColor,
                      );
                    },
                  );
                },
              ),
            ),

            // Footer: Invite Button (Persistent at bottom)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.indigoAccent],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => InviteFriendPopup(
                        myUid: myUid,
                        myName: myName,
                        roomCode: roomCode,
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Undang Teman',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile tunggal untuk setiap member, mengambil displayName dari koleksi users.
class _MemberListTile extends StatelessWidget {
  final String uid;
  final String myUid;
  final String role;
  final bool isMuted;
  final bool isHost;
  final bool isIHost;
  final String roomCode;
  final String status;
  final Color textColor;

  _MemberListTile({
    required this.uid,
    required this.myUid,
    required this.role,
    required this.isMuted,
    required this.isHost,
    required this.isIHost,
    required this.roomCode,
    required this.status,
    required this.textColor,
  });

  final UserService _userService = UserService();
  final RoomService _roomService = RoomService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final userData = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)
            : null;
            
        final name = userData?['displayName'] as String? ?? uid;
        final photoUrl = userData?['photoUrl'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Avatar Section
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  if (isHost)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, size: 9, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Name and Status Section (Expanded to prevent overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      uid == myUid ? '$name (You)' : name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          isHost ? 'Host' : 'Member',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: status == 'online' ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'online' ? Colors.green : Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Actions Section
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (uid != myUid)
                    FutureBuilder<bool>(
                      future: _userService.areFriends(myUid, uid),
                      builder: (context, friendSnap) {
                        final areFriends = friendSnap.data ?? true;
                        if (areFriends) return const SizedBox.shrink();

                        return FutureBuilder<bool>(
                          future: _userService.hasPendingRequest(myUid, uid),
                          builder: (context, pendingSnap) {
                            final hasPending = pendingSnap.data ?? true;
                            
                            return IconButton(
                              icon: Icon(
                                hasPending ? Icons.hourglass_empty_rounded : Icons.person_add_rounded,
                                size: 20,
                                color: hasPending ? Colors.grey : Colors.blueAccent,
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                              onPressed: hasPending
                                  ? null
                                  : () async {
                                      await _userService.sendFriendRequest(myUid, uid);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Friend request sent to $name')),
                                      );
                                    },
                            );
                          },
                        );
                      },
                    ),
                  
                  if (isIHost && uid != myUid) ...[
                    if (!isMuted)
                      IconButton(
                        icon: const Icon(Icons.volume_off, color: Colors.orange, size: 20),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        onPressed: () => _roomService.remoteMuteMember(roomCode, uid),
                      ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Kick Member'),
                            content: Text('Apakah Anda yakin ingin mengeluarkan $name dari room?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _roomService.kickMember(roomCode, uid);
                                },
                                child: const Text('Kick', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          key: ValueKey(isMuted),
                          color: isMuted ? Colors.red : Colors.green,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
