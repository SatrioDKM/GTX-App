import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import '../../../../core/constants/app_constants.dart';
import '../cubit/touring_cubit.dart';
import '../cubit/touring_state.dart';
import '../../../room/presentation/cubit/room_cubit.dart';
import '../widgets/touring_sidebar.dart';
import '../widgets/touring_map_view.dart';
import '../widgets/compass_hud.dart';
import '../services/navigation_sensor_service.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../data/nominatim_service.dart';
import '../../data/osrm_service.dart';

class TouringPage extends StatefulWidget {
  final String roomCode;
  final String userUid;
  final String userName;
  final String hostId;

  const TouringPage({
    super.key,
    required this.roomCode,
    required this.userUid,
    required this.userName,
    required this.hostId,
  });

  @override
  State<TouringPage> createState() => _TouringPageState();
}

class _TouringPageState extends State<TouringPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimatedMapController _animatedMapController;
  late final NavigationSensorService _navService;
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LatLng _initialPosition = const LatLng(-6.200000, 106.816666);
  final NominatimService _nominatimService = NominatimService();
  final OsrmService _osrmService = OsrmService();
  
  StreamSubscription? _roomMembersSub;
  StreamSubscription? _destinationSub;
  List<String> _previousMembers = [];

  bool _isSearchExpanded = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<NominatimResult> _searchResults = [];
  Timer? _debounce;

  NominatimResult? _previewDestination;
  double _previewDistance = 0.0;
  List<LatLng> _previewRoute = [];

  // Navigation Mode (Heading-Up)
  bool _isNavMode = false;

  Future<void> _performSearch(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _nominatimService.search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(vsync: this, mapController: _mapController);
    _navService = NavigationSensorService(
      mapController: _mapController, 
      animatedMapController: _animatedMapController
    );
    _navService.init(context);
    
    context.read<TouringCubit>().startTouring(widget.roomCode, widget.userUid, widget.userName);
    
    // In-App Notifications for Join/Leave
    _roomMembersSub = context.read<RoomCubit>().roomService.getRoomMembersStream(widget.roomCode).listen((members) async {
      final currentMembers = members.map((e) => e['uid'] as String).toList();
      
      if (_previousMembers.isNotEmpty) {
        // Detect Joins
        for (var uid in currentMembers) {
          if (!_previousMembers.contains(uid) && uid != widget.userUid) {
            final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            if (doc.exists) {
               final name = doc.data()?['displayName'] ?? 'Seseorang';
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name bergabung ke room'), duration: const Duration(seconds: 2)));
               }
            }
          }
        }
        
        // Detect Leaves
        for (var uid in _previousMembers) {
          if (!currentMembers.contains(uid) && uid != widget.userUid) {
            final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            if (doc.exists) {
               final name = doc.data()?['displayName'] ?? 'Seseorang';
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name keluar dari room'), duration: const Duration(seconds: 2)));
               }
            }
          }
        }
      }
      
      _previousMembers = currentMembers;
    });

    // Listen ke destination stream untuk auto-nav mode
    _destinationSub = context.read<TouringCubit>().destinationStream.listen((dest) {
      if (dest != null && !_isNavMode) {
        _enableNavMode();
      } else if (dest == null && _isNavMode) {
        _disableNavMode();
      }
    });

  }

  @override
  void dispose() {
    _roomMembersSub?.cancel();
    _destinationSub?.cancel();
    _searchController.dispose();
    _debounce?.cancel();
    _navService.dispose();
    _animatedMapController.dispose();
    super.dispose();
  }

  void _enableNavMode() {
    setState(() => _isNavMode = true);
    _navService.enableNavMode();
  }

  void _disableNavMode() {
    setState(() => _isNavMode = false);
    _navService.disableNavMode();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hudColor = isDark 
        ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.8);
    final hudTextColor = isDark 
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.white;

    return MultiBlocListener(
      listeners: [
        BlocListener<TouringCubit, TouringState>(
          listener: (context, state) {
            if (state is TouringKicked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Anda telah dikeluarkan dari room oleh Host.'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.of(context).pop();
            }
          },
        ),
      ],
      child: Scaffold(
        key: _scaffoldKey,
        drawer: TouringSidebar(
          roomCode: widget.roomCode,
          hostId: widget.hostId,
          myUid: widget.userUid,
          myName: widget.userName,
        ),
        body: Stack(
        children: [
          // 1. Layer Peta (OpenStreetMap)
          TouringMapView(
            mapController: _mapController,
            initialPosition: _initialPosition,
            onMapReady: () {
              _navService.isMapReady = true;
              _navService.recenterMap();
            },
            onMapInteraction: (isFollowing) {
              if (_navService.isFollowingUser.value) {
                _navService.isFollowingUser.value = false;
              }
            },
            hostId: widget.hostId,
            userUid: widget.userUid,
            roomCode: widget.roomCode,
            previewRoute: _previewRoute,
            previewDestination: _previewDestination,
            headingNotifier: _navService.headingNotifier,
          ),

          // 2. HUD Atas (Info Room + Members button) - STICKY TOP
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Baris 1: Tombol Member, Room Code, Speaker
                    SizedBox(
                      height: 50,
                      child: Stack(
                        children: [
                          // Tombol buka drawer (daftar member) - Kiri
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => _scaffoldKey.currentState?.openDrawer(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: hudColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                                ),
                                child: const Icon(Icons.people_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                          
                          // Room code chip - CENTER
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: hudColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                              ),
                              child: Text(
                                'Room: ${widget.roomCode}',
                                style: TextStyle(
                                  color: hudTextColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),

                          // Tombol Compass (Top Right)
                          Align(
                            alignment: Alignment.centerRight,
                            child: CompassHud(
                              isMapReady: _navService.isMapReady,
                              compassNotifier: _navService.headingNotifier,
                              onCompassTap: _navService.onCompassTapped,
                            ),
                          ),
                        ],
                      ),
                    ),



                    // Baris 2: Search Bar (collapsed = icon, expanded = full bar)
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: _isSearchExpanded
                              ? MediaQuery.of(context).size.width - 32 // penuh (dikurangi horizontal padding 16*2)
                              : 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: hudColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isSearchExpanded ? Icons.close : Icons.search,
                                  color: hudTextColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearchExpanded = !_isSearchExpanded;
                                    if (!_isSearchExpanded) {
                                      _searchController.clear();
                                      _searchResults.clear();
                                    }
                                  });
                                },
                              ),
                              if (_isSearchExpanded)
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: TextStyle(color: hudTextColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Cari lokasi tujuan...',
                                      hintStyle: TextStyle(color: hudTextColor.withOpacity(0.5)),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (val) {
                                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                                      _debounce = Timer(const Duration(milliseconds: 500), () {
                                        _performSearch(val);
                                      });
                                    },
                                  ),
                                ),
                              if (_isSearching && _isSearchExpanded)
                                const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Search Results List
                    if (_isSearchExpanded && _searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: hudColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final option = _searchResults[index];
                            return ListTile(
                              leading: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                              title: Text(
                                option.displayName,
                                style: TextStyle(color: hudTextColor, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () async {
                                _mapController.move(option.position, 15.0);
                                setState(() {
                                  _isSearchExpanded = false;
                                  _searchController.clear();
                                  _searchResults.clear();
                                  _previewDestination = option;
                                  _previewRoute = [];
                                  _previewDistance = 0.0;
                                });
                                try {
                                  final pos = await Geolocator.getCurrentPosition();
                                  final dist = Geolocator.distanceBetween(
                                    pos.latitude, pos.longitude,
                                    option.position.latitude, option.position.longitude,
                                  );
                                  final route = await _osrmService.getRoute(
                                    LatLng(pos.latitude, pos.longitude),
                                    option.position,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _previewDistance = dist / 1000.0;
                                      _previewRoute = route;
                                    });
                                  }
                                } catch (_) {}
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Ergonomic Controls (Kiri Bawah: Recenter + Mic)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.leftHandErgonomicPadding),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  // Padding bawah agar tidak ketutup Speedometer HUD
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tombol Recenter Map / Re-follow Navigation
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _navService.isFollowingUser,
                          _navService.isCourseUp,
                        ]),
                        builder: (context, child) {
                          final isFollowing = _navService.isFollowingUser.value;
                          final isCourseUp = _navService.isCourseUp.value;

                          final Color bgColor = isFollowing 
                              ? Colors.blueAccent 
                              : (isDark ? Colors.grey[800]! : Colors.white);
                          
                          final Color fgColor = isFollowing 
                              ? Colors.white 
                              : (isDark ? Colors.white : Colors.black);
                              
                          final IconData icon = (isFollowing && isCourseUp)
                              ? Icons.navigation
                              : Icons.my_location;

                          return FloatingActionButton(
                            heroTag: 'recenter',
                            backgroundColor: bgColor,
                            foregroundColor: fgColor,
                            onPressed: _navService.onRecenterTapped,
                            child: Icon(icon),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tombol Speaker Selector (Dropdown Menu)
                      BlocBuilder<TouringCubit, TouringState>(
                        builder: (context, state) {
                          final bool isSpeakerOn =
                              state is TouringConnected ? state.isSpeakerOn : false;

                          return PopupMenuButton<MediaDevice>(
                            tooltip: 'Pilih Output Suara',
                            offset: const Offset(60, -100), // Pop up ke kanan atas
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: isSpeakerOn ? Colors.blueAccent : (isDark ? Colors.grey[800] : Colors.white),
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                                  color: isSpeakerOn ? Colors.white : (isDark ? Colors.white : Colors.black),
                                  size: 24,
                                ),
                              ),
                            ),
                            onSelected: (MediaDevice device) => context.read<TouringCubit>().selectAudioDevice(device),
                            itemBuilder: (context) {
                              final devices = state is TouringConnected ? (state as TouringConnected).availableDevices : <MediaDevice>[];
                              
                              return [
                                PopupMenuItem(
                                  enabled: false,
                                  child: Text(
                                    'Pilih Output Suara',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                ...devices.map((MediaDevice device) {
                                  IconData deviceIcon;
                                  final label = device.label.toLowerCase();
                                  
                                  if (label.contains('speaker')) {
                                    deviceIcon = Icons.volume_up_rounded;
                                  } else if (label.contains('bluetooth')) {
                                    deviceIcon = Icons.bluetooth_audio_rounded;
                                  } else if (label.contains('headset') || label.contains('headphones')) {
                                    deviceIcon = Icons.headset_rounded;
                                  } else if (label.contains('earpiece')) {
                                    deviceIcon = Icons.phone_android_rounded;
                                  } else {
                                    deviceIcon = Icons.audiotrack_rounded;
                                  }

                                  return PopupMenuItem<MediaDevice>(
                                    value: device,
                                    child: Row(
                                      children: [
                                        Icon(deviceIcon, size: 20, color: Colors.blueAccent),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            device.label,
                                            style: const TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  onTap: () => context.read<TouringCubit>().refreshAudioDevices(),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                                      SizedBox(width: 12),
                                      Text('Refresh List', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tombol Mic Toggle - SMOOTH VISUALIZER
                      BlocBuilder<TouringCubit, TouringState>(
                        builder: (context, state) {
                          final bool isMicOn =
                              state is TouringConnected ? state.isMicOn : false;

                          return StreamBuilder<double>(
                            stream: context.read<TouringCubit>().audioLevelStream,
                            builder: (context, snapshot) {
                              final volume = (snapshot.data ?? 0.0).clamp(0.0, 1.0);

                              // Color.lerp dari hijau ke biru berdasarkan volume suara
                              final Color micColor = isMicOn
                                  ? Color.lerp(Colors.green, Colors.blue, volume)!
                                  : Colors.red;

                              final double glowRadius = isMicOn && volume > 0.05 ? 15 + (volume * 10) : 0;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: isMicOn && volume > 0.05
                                      ? [
                                          BoxShadow(
                                            color: micColor.withValues(alpha: 0.6),
                                            blurRadius: glowRadius,
                                            spreadRadius: glowRadius / 3,
                                          )
                                        ]
                                      : [],
                                ),
                                child: FloatingActionButton(
                                  heroTag: 'mic_toggle',
                                  backgroundColor: micColor,
                                  foregroundColor: Colors.white,
                                  onPressed: () => context.read<TouringCubit>().toggleMic(),
                                  child: Icon(isMicOn ? Icons.mic : Icons.mic_off),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3.5 Google Maps Style Preview Card (Hanya terlihat saat mencari rute)
          if (_previewDestination != null)
            Positioned(
              bottom: 150, // Di atas Bottom HUD
              left: 16,
              right: 16,
              child: Card(
                color: hudColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _previewDestination!.displayName,
                        style: TextStyle(color: hudTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Jarak Estimasi: ${_previewDistance.toStringAsFixed(1)} km',
                        style: TextStyle(color: hudTextColor.withOpacity(0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _previewDestination = null;
                              _previewRoute.clear();
                            }),
                            child: const Text('Batal', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                            onPressed: () {
                              if (widget.hostId == widget.userUid) {
                                context.read<RoomCubit>().roomService.setDestination(
                                  widget.roomCode, 
                                  _previewDestination!.position.latitude, 
                                  _previewDestination!.position.longitude,
                                );
                                _enableNavMode(); // Aktifkan heading-up mode!
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hanya Host yang bisa mengatur tujuan navigasi!')));
                              }
                              setState(() {
                                _previewDestination = null;
                                _previewRoute.clear();
                              });
                            },
                            child: const Text('Mulai Navigasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Exit Button (Kanan Bawah - di atas Speedometer HUD)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                right: AppConstants.leftHandErgonomicPadding,
                bottom: AppConstants.leftHandErgonomicPadding + 80,
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  heroTag: 'leave_room',
                  backgroundColor: isDark ? Colors.grey[800] : Colors.black87,
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Exit Touring'),
                        content: const Text('Are you sure you want to leave the room?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Yes, Leave', style: TextStyle(color: Colors.red)),
                          ),
                        ],
      ),
    );

                    if (confirm == true) {
                      if (!context.mounted) return;
                      await context.read<TouringCubit>().leaveTouring();
                      await context.read<RoomCubit>().leaveRoom(widget.roomCode, widget.userUid);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: const Icon(Icons.exit_to_app),
                ),
              ),
            ),
          ),

          // 5. SPEEDOMETER HUD (Bawah Layar - Full Width)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: hudColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Distance
                    StreamBuilder<double>(
                      stream: context.read<TouringCubit>().distanceToDestStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(width: 80);
                        final distance = snapshot.data!;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sisa Jarak',
                              style: TextStyle(
                                color: hudTextColor.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: hudTextColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    // Speedometer
                    StreamBuilder<double>(
                      stream: context.read<TouringCubit>().speedStream,
                      builder: (context, snapshot) {
                        final speed = snapshot.data ?? 0.0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              speed.toStringAsFixed(0),
                              style: TextStyle(
                                color: hudTextColor,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'km/h',
                                style: TextStyle(
                                  color: hudTextColor.withOpacity(0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    // End Route Button (Hanya Host)
                    if (widget.hostId == widget.userUid)
                      StreamBuilder<LatLng?>(
                        stream: context.read<TouringCubit>().destinationStream,
                        builder: (context, snapshot) {
                          if (snapshot.data == null) return const SizedBox(width: 80);
                          return SizedBox(
                            width: 80,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 36),
                              tooltip: 'Akhiri Navigasi',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Akhiri Navigasi?'),
                                    content: const Text('Rute akan dihapus untuk semua anggota room.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Akhiri', style: TextStyle(color: Colors.red))),
                                    ],
      ),
    );
                                if (confirm == true) {
                                  context.read<RoomCubit>().roomService.setDestination(widget.roomCode, 0, 0);
                                  _disableNavMode();
                                }
                              },
                            ),
                          );
                        },
                      )
                    else
                      const SizedBox(width: 80), // Spacer untuk balance
                  ],
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

