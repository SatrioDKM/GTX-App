import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/room_cubit.dart';
import '../cubit/room_state.dart';
import '../../../touring/presentation/pages/touring_page.dart';
import '../../../auth/data/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _rideNameController = TextEditingController(text: 'Sunmori Santai');
  int _maxMembers = 20;
  bool _requireApproval = false;
  final UserService _userService = UserService();
  final List<String> _selectedFriendUids = [];
  String? _lastRoomCode;

  @override
  void initState() {
    super.initState();
    _loadLastRoom();
  }

  Future<void> _loadLastRoom() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastRoomCode = prefs.getString('last_room_code');
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _rideNameController.dispose();
    super.dispose();
  }

  Future<void> _showCreateRoomSheet(BuildContext context, String userUid) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Touring Room',
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    const SizedBox(height: 24),

                    // Nama Ride
                    TextField(
                      controller: _rideNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Ride',
                        hintText: 'Misal: Sunmori Puncak',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Maksimal Member
                    Row(
                      children: [
                        Text('Maks. Anggota:', style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                        Expanded(
                          child: Slider(
                            value: _maxMembers.toDouble(),
                            min: 2, max: 50,
                            divisions: 48,
                            label: '$_maxMembers orang',
                            onChanged: (v) => setSheetState(() => _maxMembers = v.toInt()),
                          ),
                        ),
                        Text('$_maxMembers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Toggle Approval
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('ACC Member Manual'),
                      subtitle: const Text('Host harus setujui tiap anggota baru'),
                      value: _requireApproval,
                      onChanged: (v) => setSheetState(() => _requireApproval = v),
                    ),
                    const SizedBox(height: 16),

                    Text('Invite Online Friends:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _userService.getOnlineFriendsStream(userUid),
                        builder: (context, snapshot) {
                          final onlineFriends = snapshot.data ?? [];
                          if (onlineFriends.isEmpty) {
                            return const Center(child: Text('No friends online', style: TextStyle(color: Colors.grey, fontSize: 12)));
                          }
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: onlineFriends.length,
                            itemBuilder: (ctx, i) {
                              final friend = onlineFriends[i];
                              final uid = friend['uid'] as String;
                              final name = friend['displayName'] as String;
                              final photo = friend['photoUrl'] as String? ?? '';
                              final isSelected = _selectedFriendUids.contains(uid);

                              return GestureDetector(
                                onTap: () => setSheetState(() {
                                  if (isSelected) _selectedFriendUids.remove(uid);
                                  else _selectedFriendUids.add(uid);
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                            child: photo.isEmpty ? Text(name[0]) : null,
                                          ),
                                          if (isSelected)
                                            const Positioned(
                                              right: 0, bottom: 0,
                                              child: CircleAvatar(
                                                radius: 8,
                                                backgroundColor: Colors.green,
                                                child: Icon(Icons.check, size: 10, color: Colors.white),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(width: 50, child: Text(name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.rocket_launch_rounded),
                        label: const Text('Buat Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          context.read<RoomCubit>().createRoom(
                            userUid,
                            rideName: _rideNameController.text.trim().isEmpty
                                ? 'Touring Room'
                                : _rideNameController.text.trim(),
                            maxMembers: _maxMembers,
                            requireApproval: _requireApproval,
                          ).then((_) {
                            // Setelah sukses, kirim undangan jika ada yang dipilih
                            final state = context.read<RoomCubit>().state;
                            if (state is RoomSuccess && _selectedFriendUids.isNotEmpty) {
                              for (var friendUid in _selectedFriendUids) {
                                _userService.sendRoomInvite(
                                  fromUid: userUid,
                                  fromName: context.read<AuthCubit>().state is Authenticated 
                                      ? (context.read<AuthCubit>().state as Authenticated).user.displayName 
                                      : 'Host',
                                  toUid: friendUid,
                                  roomCode: state.roomCode,
                                  rideName: _rideNameController.text,
                                );
                              }
                              _selectedFriendUids.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNotificationSheet(BuildContext context) async {
    final userUid = context.read<AuthCubit>().state is Authenticated 
        ? (context.read<AuthCubit>().state as Authenticated).user.uid 
        : '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications', 
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _userService.getInvitationsStream(userUid),
                  builder: (context, snapshot) {
                    final invites = snapshot.data ?? [];
                    
                    if (invites.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.bellOff, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('Belum ada notifikasi baru', 
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: invites.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final invite = invites[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: const Icon(LucideIcons.mail, size: 20),
                          ),
                          title: Text('${invite['fromName']} mengajak touring!', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text('Ride: ${invite['rideName']}', 
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(LucideIcons.checkCircle2, color: Colors.green),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context.read<RoomCubit>().joinRoom(invite['roomCode'], userUid);
                                  _userService.dismissInvitation(userUid, invite);
                                },
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.xCircle, color: Colors.red),
                                onPressed: () => _userService.dismissInvitation(userUid, invite),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWaitingApprovalDialog(BuildContext context, String roomCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomCode.toUpperCase())
              .collection('members')
              .doc(context.read<AuthCubit>().state is Authenticated 
                  ? (context.read<AuthCubit>().state as Authenticated).user.uid 
                  : '')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              // Approved! Navigate to Touring
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogCtx)) {
                  Navigator.pop(dialogCtx);
                }
                context.read<RoomCubit>().joinRoom(roomCode, (context.read<AuthCubit>().state as Authenticated).user.uid);
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Menunggu Persetujuan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Host sedang meninjau permintaan bergabung Anda ke room $roomCode.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    context.read<RoomCubit>().resetRoom();
                  },
                  child: const Text('Batal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoomCubit, RoomState>(
      listener: (context, state) {
        if (state is RoomError) {
          _showErrorSnackBar(state.message);
        } else if (state is RoomWaitingApproval) {
          _showWaitingApprovalDialog(context, state.roomCode);
        } else if (state is RoomSuccess) {
          final user = context.read<AuthCubit>().state is Authenticated 
              ? (context.read<AuthCubit>().state as Authenticated).user 
              : null;
              
          if (user != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TouringPage(
                  roomCode: state.roomCode,
                  userUid: user.uid,
                  userName: user.displayName,
                  hostId: state.hostId,
                ),
              ),
            ).then((_) => _loadLastRoom());
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 70,
          title: Image.asset(
            'assets/images/gtx_logo.png',
            height: 40,
            fit: BoxFit.contain,
          ),
          actions: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _userService.getInvitationsStream(context.read<AuthCubit>().state is Authenticated 
                  ? (context.read<AuthCubit>().state as Authenticated).user.uid : ''),
              builder: (context, inviteSnapshot) {
                final inviteCount = inviteSnapshot.data?.length ?? 0;
                
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.bell, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => _showNotificationSheet(context),
                    ),
                    if (inviteCount > 0)
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: Icon(LucideIcons.settings, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Settings'),
                    content: const Text('Halaman Settings akan segera hadir!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              if (authState is Authenticated) {
                final user = authState.user;
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Profil
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: user.photoUrl.isNotEmpty
                                      ? NetworkImage(user.photoUrl)
                                      : null,
                                  child: user.photoUrl.isEmpty
                                      ? const Icon(Icons.person, size: 28)
                                      : null,
                                ),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ready to ride,',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    user.displayName,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
  
                        // Touring Coordination Card
                        Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.users, color: Theme.of(context).colorScheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Touring Coordination',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                              const SizedBox(height: 24),
                              
                              // Create Room Button
                              BlocBuilder<RoomCubit, RoomState>(
                                builder: (context, roomState) {
                                  final isLoading = roomState is RoomLoading;
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () => _showCreateRoomSheet(context, user.uid),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0052CC),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 24, height: 24,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(LucideIcons.mapPin, size: 20),
                                                SizedBox(width: 12),
                                                Text(
                                                  'Create Touring Group',
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                                ),
                                                Spacer(),
                                                Icon(LucideIcons.chevronRight, size: 20),
                                              ],
                                            ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade200)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey.shade200)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Join Room Form
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                      ),
                                      child: TextField(
                                        controller: _codeController,
                                        textCapitalization: TextCapitalization.characters,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter 6-Digit Code',
                                          hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          prefixIcon: Icon(LucideIcons.hash, color: Colors.grey, size: 20),
                                        ),
                                        maxLength: 6,
                                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  BlocBuilder<RoomCubit, RoomState>(
                                    builder: (context, roomState) {
                                      final isLoading = roomState is RoomLoading;
                                      return Container(
                                        height: 56,
                                        width: 56,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: IconButton(
                                          onPressed: isLoading
                                              ? null
                                              : () {
                                                  if (_codeController.text.length == 6) {
                                                    context.read<RoomCubit>().joinRoom(
                                                      _codeController.text,
                                                      user.uid,
                                                    );
                                                  } else {
                                                    _showErrorSnackBar("Code must be 6 digits");
                                                  }
                                                },
                                          icon: isLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(LucideIcons.arrowRight, color: Color(0xFF0052CC)),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              
                              if (_lastRoomCode != null) ...[
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () {
                                    _codeController.text = _lastRoomCode!;
                                    context.read<RoomCubit>().joinRoom(_lastRoomCode!, user.uid);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0052CC).withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.history, size: 18, color: const Color(0xFF0052CC)),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Reconnect to last group',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _lastRoomCode!,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Icon(LucideIcons.chevronRight, size: 18, color: const Color(0xFF0052CC)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}
