import 'package:flutter/material.dart';
import '../../../auth/data/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InviteFriendPopup extends StatefulWidget {
  final String myUid;
  final String myName;
  final String roomCode;

  const InviteFriendPopup({
    super.key,
    required this.myUid,
    required this.myName,
    required this.roomCode,
  });

  @override
  State<InviteFriendPopup> createState() => _InviteFriendPopupState();
}

class _InviteFriendPopupState extends State<InviteFriendPopup> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Undang Teman',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Cari nama teman...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // Friend List
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _userService.getFriendsStream(widget.myUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final friendUids = snapshot.data ?? [];
                if (friendUids.isEmpty) {
                  return const Center(child: Text('Belum ada teman'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('uid', whereIn: friendUids)
                      .snapshots(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = userSnap.data?.docs ?? [];
                    final filteredUsers = users.where((doc) {
                      final name = (doc.data() as Map<String, dynamic>)['displayName'] as String? ?? '';
                      return name.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filteredUsers.isEmpty) {
                      return const Center(child: Text('Teman tidak ditemukan'));
                    }

                    // Sort: Online users first
                    filteredUsers.sort((a, b) {
                      final aOnline = (a.data() as Map<String, dynamic>)['isOnline'] as bool? ?? false;
                      final bOnline = (b.data() as Map<String, dynamic>)['isOnline'] as bool? ?? false;
                      if (aOnline && !bOnline) return -1;
                      if (!aOnline && bOnline) return 1;
                      return 0;
                    });

                    return ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final data = filteredUsers[index].data() as Map<String, dynamic>;
                        final name = data['displayName'] as String? ?? 'User';
                        final photoUrl = data['photoUrl'] as String? ?? '';
                        final isOnline = data['isOnline'] as bool? ?? false;
                        final uid = data['uid'] as String;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty ? Text(name[0].toUpperCase()) : null,
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(isOnline ? 'Online' : 'Offline', 
                            style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
                          trailing: ElevatedButton(
                            onPressed: isOnline 
                              ? () async {
                                  await _userService.sendRoomInvite(
                                    fromUid: widget.myUid,
                                    fromName: widget.myName,
                                    toUid: uid,
                                    roomCode: widget.roomCode,
                                    rideName: 'Touring Room',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Undangan terkirim ke $name')),
                                    );
                                  }
                                }
                              : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOnline ? Colors.blueAccent : Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Undang', style: TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
