import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../cubit/touring_cubit.dart';
import '../../../room/presentation/cubit/room_cubit.dart';
import '../../data/nominatim_service.dart';
import 'navigation_marker.dart';

class TouringMapView extends StatelessWidget {
  final MapController mapController;
  final LatLng initialPosition;
  final VoidCallback onMapReady;
  final ValueChanged<bool> onMapInteraction;
  final String hostId;
  final String userUid;
  final String roomCode;
  final List<LatLng> previewRoute;
  final NominatimResult? previewDestination;
  final ValueNotifier<double> headingNotifier;

  const TouringMapView({
    super.key,
    required this.mapController,
    required this.initialPosition,
    required this.onMapReady,
    required this.onMapInteraction,
    required this.hostId,
    required this.userUid,
    required this.roomCode,
    required this.previewRoute,
    required this.previewDestination,
    required this.headingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        onMapReady: onMapReady,
        initialCenter: initialPosition,
        initialZoom: 14.0,
        onLongPress: (tapPosition, point) {
          if (hostId == userUid) {
            context.read<RoomCubit>().roomService.setDestination(roomCode, point.latitude, point.longitude);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hanya Host yang bisa mengatur tujuan!')));
          }
        },
        onMapEvent: (event) {
          // Jika user scroll/drag peta manual, matikan follow
          if (event.source != MapEventSource.mapController) {
            onMapInteraction(false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'GTX-App-Touring-Service-v1',
          tileProvider: NetworkTileProvider(),
        ),
        // Polyline Layer untuk rute
        StreamBuilder<List<LatLng>>(
          stream: context.read<TouringCubit>().polylineStream,
          builder: (context, snapshot) {
            final points = snapshot.data ?? [];
            if (points.isEmpty && previewRoute.isEmpty) return const SizedBox.shrink();
            return PolylineLayer(
              polylines: [
                if (points.isNotEmpty)
                  Polyline(
                    points: points,
                    color: Colors.blueAccent.withValues(alpha: 0.7),
                    strokeWidth: 6.0,
                  ),
                if (previewRoute.isNotEmpty)
                  Polyline(
                    points: previewRoute,
                    color: Colors.grey,
                    strokeWidth: 6.0,
                  ),
              ],
            );
          },
        ),
        // Marker Layer untuk tujuan
        StreamBuilder<LatLng?>(
          stream: context.read<TouringCubit>().destinationStream,
          builder: (context, snapshot) {
            final dest = snapshot.data;
            final previewDest = previewDestination?.position;
            
            if (dest == null && previewDest == null) return const SizedBox.shrink();
            
            return MarkerLayer(
              markers: [
                if (dest != null)
                  Marker(
                    point: dest,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_on, color: Colors.green, size: 45),
                  ),
                if (previewDest != null)
                  Marker(
                    point: previewDest,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_on, color: Colors.grey, size: 45),
                  ),
              ]
            );
          }
        ),
        // Marker Layer untuk anggota room (dengan real-time sync untuk user lokal)
        StreamBuilder<Position>(
          stream: context.read<TouringCubit>().positionStream,
          builder: (context, positionSnapshot) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: context.read<RoomCubit>().roomService.getRoomMembersStream(roomCode),
              builder: (context, membersSnapshot) {
                final members = membersSnapshot.data ?? [];
                final localPosition = positionSnapshot.data;

                final markers = members.map((m) {
                  final isMe = m['uid'] == userUid;
                  double lat = m['latitude'] ?? 0.0;
                  double lng = m['longitude'] ?? 0.0;

                  // Gunakan stream GPS lokal untuk pergerakan marker sendiri agar tidak delay
                  if (isMe && localPosition != null) {
                    lat = localPosition.latitude;
                    lng = localPosition.longitude;
                  }

                  // Abaikan jika koordinat tidak valid
                  if (lat == 0.0 && lng == 0.0) return null;

                  return Marker(
                    point: LatLng(lat, lng),
                    width: isMe ? 80 : 40,
                    height: isMe ? 80 : 40,
                    child: isMe 
                      ? NavigationMarker(headingNotifier: headingNotifier)
                      : const Icon(
                          Icons.motorcycle,
                          color: Colors.red,
                          size: 30,
                        ),
                  );
                }).whereType<Marker>().toList();

                return MarkerLayer(markers: markers);
              },
            );
          },
        ),
      ],
    );
  }
}
