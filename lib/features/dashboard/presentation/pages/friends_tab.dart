import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/data/user_service.dart';

class FriendsTab extends StatelessWidget {
  FriendsTab({super.key});

  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Center(child: CircularProgressIndicator());
        }
        final myUid = state.user.uid;

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              // ── Pending Requests Section ─────────────────────────────────
              SliverToBoxAdapter(
                child: StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _userService.getIncomingRequestsStream(myUid),
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                          child: Row(
                            children: [
                              Text(
                                'Friend Requests',
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${requests.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                        ),
                        ...requests.map((req) {
                          final data = req.data() as Map<String, dynamic>;
                          return _RequestCard(
                            requestId: req.id,
                            fromUid: data['fromUid'] as String,
                            myUid: myUid,
                            userService: _userService,
                          );
                        }),
                        const Divider(indent: 24, endIndent: 24, height: 24),
                      ],
                    );
                  },
                ),
              ),

              // ── Friends List Section ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(
                    'My Friends',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              StreamBuilder<List<String>>(
                stream: _userService.getFriendsStream(myUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final friendUids = snapshot.data ?? [];
                  if (friendUids.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.group_off_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
                              SizedBox(height: 12),
                              Text(
                                'Belum ada teman.\nTambahkan dari Member Sidebar saat touring!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _FriendCard(
                        friendUid: friendUids[i],
                        myUid: myUid,
                        userService: _userService,
                      ),
                      childCount: friendUids.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final String requestId;
  final String fromUid;
  final String myUid;
  final UserService userService;

  const _RequestCard({
    required this.requestId,
    required this.fromUid,
    required this.myUid,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: userService.getUserProfileOnce(fromUid),
      builder: (context, snapshot) {
        final name = snapshot.data?['displayName'] as String? ?? fromUid;
        final photo = snapshot.data?['photoUrl'] as String? ?? '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          leading: CircleAvatar(
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?') : null,
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Wants to be your friend'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 30),
                tooltip: 'Accept',
                onPressed: () => userService.acceptFriendRequest(requestId, fromUid, myUid),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 30),
                tooltip: 'Reject',
                onPressed: () => userService.rejectFriendRequest(requestId),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Friend Card ──────────────────────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final String friendUid;
  final String myUid;
  final UserService userService;

  const _FriendCard({
    required this.friendUid,
    required this.myUid,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: userService.getUserProfile(friendUid),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final name = data?['displayName'] as String? ?? friendUid;
        final photo = data?['photoUrl'] as String? ?? '';
        final isOnline = data?['isOnline'] as bool? ?? false;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?') : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12),
          ),
        );
      },
    );
  }
}
