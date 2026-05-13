import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/code_generator.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // CREATE ROOM
  // =========================
  Future<String> createRoom(
    String hostUid, {
    String rideName = 'Touring Room',
    int maxMembers = 20,
    bool requireApproval = false,
  }) async {
    final String roomCode = CodeGenerator.generateRoomCode();

    final roomRef = _firestore.collection('rooms').doc(roomCode);

    // Cek apakah room code sudah ada
    final existingRoom = await roomRef.get();

    if (existingRoom.exists) {
      return createRoom(
        hostUid,
        rideName: rideName,
        maxMembers: maxMembers,
        requireApproval: requireApproval,
      );
    }

    // Buat room
    await roomRef.set({
      'roomCode': roomCode,
      'hostId': hostUid,
      'rideName': rideName,
      'maxMembers': maxMembers,
      'requireApproval': requireApproval,
      'memberCount': 1,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Tambahkan host ke members
    await roomRef.collection('members').doc(hostUid).set({
      'uid': hostUid,
      'role': 'host',
      'isMuted': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return roomCode;
  }

  // =========================
  // JOIN ROOM
  // =========================
  Future<Map<String, dynamic>> joinRoom(
    String roomCode,
    String userUid,
  ) async {
    final roomRef =
        _firestore.collection('rooms').doc(roomCode.toUpperCase());

    final roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      throw Exception('Room tidak ditemukan');
    }

    final roomData = roomDoc.data()!;

    // Cek status room
    if (roomData['status'] != 'active') {
      throw Exception('Room tidak aktif');
    }

    // Cek kapasitas
    final currentMemberCount = roomData['memberCount'] ?? 0;
    final maxMembers = roomData['maxMembers'] ?? 20;

    if (currentMemberCount >= maxMembers) {
      throw Exception('Room sudah penuh');
    }

    // Cek apakah user sudah join atau sedang menunggu approval
    final memberDoc = await roomRef.collection('members').doc(userUid).get();
    if (memberDoc.exists) return roomData;

    final pendingDoc = await roomRef.collection('pending_approvals').doc(userUid).get();

    // Bypass approval jika user adalah HOST dari room ini
    if (roomData['hostId'] == userUid) {
      await roomRef.collection('members').doc(userUid).set({
        'uid': userUid,
        'role': 'host',
        'isMuted': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      return roomData;
    }

    // Jika butuh approval dan belum join
    if (roomData['requireApproval'] == true) {
      if (!pendingDoc.exists) {
        await roomRef.collection('pending_approvals').doc(userUid).set({
          'uid': userUid,
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }
      throw Exception('WAITING_FOR_APPROVAL');
    }

    // Join langsung jika tidak butuh approval
    await roomRef.collection('members').doc(userUid).set({
      'uid': userUid,
      'role': 'member',
      'isMuted': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await roomRef.update({
      'memberCount': FieldValue.increment(1),
    });

    return roomData;
  }

  // =========================
  // APPROVE / REJECT MEMBER
  // =========================
  Future<void> approveMember(String roomCode, String userUid, bool approve) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode.toUpperCase());
    
    if (approve) {
      final batch = _firestore.batch();
      
      batch.set(roomRef.collection('members').doc(userUid), {
        'uid': userUid,
        'role': 'member',
        'isMuted': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      batch.update(roomRef, {
        'memberCount': FieldValue.increment(1),
      });
      
      batch.delete(roomRef.collection('pending_approvals').doc(userUid));
      
      await batch.commit();
    } else {
      await roomRef.collection('pending_approvals').doc(userUid).delete();
    }
  }

  // =========================
  // KICK MEMBER
  // =========================
  Future<void> kickMember(String roomCode, String userUid) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode.toUpperCase());
    
    // Hapus member
    await roomRef.collection('members').doc(userUid).delete();

    // Kurangi member count
    await roomRef.update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  // =========================
  // REMOTE MUTE MEMBER
  // =========================
  Future<void> remoteMuteMember(String roomCode, String userUid) async {
    await _firestore
        .collection('rooms')
        .doc(roomCode.toUpperCase())
        .collection('members')
        .doc(userUid)
        .update({'isMuted': true});
  }

  // =========================
  // LEAVE ROOM
  // =========================
  Future<void> leaveRoom(
    String roomCode,
    String userUid,
  ) async {
    final roomRef =
        _firestore.collection('rooms').doc(roomCode.toUpperCase());

    final roomDoc = await roomRef.get();

    if (!roomDoc.exists) return;

    final roomData = roomDoc.data();

    if (roomData == null) return;

    // Hapus member (termasuk host jika dia keluar)
    await roomRef.collection('members').doc(userUid).delete();

    // Kurangi member count
    await roomRef.update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  // =========================
  // GET ROOM DATA
  // =========================
  Future<Map<String, dynamic>?> getRoom(String roomCode) async {
    final doc = await _firestore
        .collection('rooms')
        .doc(roomCode.toUpperCase())
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  // =========================
  // ROOM MEMBERS STREAM
  // =========================
  Stream<List<Map<String, dynamic>>> getRoomMembersStream(
    String roomCode,
  ) {
    return _firestore
        .collection('rooms')
        .doc(roomCode.toUpperCase())
        .collection('members')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data())
              .toList(),
        );
  }

  // =========================
  // ROOM STREAM
  // =========================
  Stream<DocumentSnapshot<Map<String, dynamic>>> getRoomStream(
    String roomCode,
  ) {
    return _firestore
        .collection('rooms')
        .doc(roomCode.toUpperCase())
        .snapshots();
  }

  // =========================
  // SET DESTINATION
  // =========================
  Future<void> setDestination(String roomCode, double lat, double lng) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode.toUpperCase());
    await roomRef.update({
      'destinationLat': lat,
      'destinationLng': lng,
    });
  }

  // =========================
  // ARCHIVE ROOM
  // =========================
  Future<void> archiveRoom(String roomCode) async {
    final roomRef = _firestore.collection('rooms').doc(roomCode.toUpperCase());
    final roomDoc = await roomRef.get();

    if (!roomDoc.exists) return;
    
    final roomData = roomDoc.data()!;
    final membersSnapshot = await roomRef.collection('members').get();
    
    List<String> memberUids = [];
    
    for (var doc in membersSnapshot.docs) {
      memberUids.add(doc.id);
    }

    roomData['memberUids'] = memberUids;
    roomData['archivedAt'] = FieldValue.serverTimestamp();
    roomData['status'] = 'archived';

    // Save to history_tours
    final historyRef = _firestore.collection('history_tours').doc(roomCode.toUpperCase());
    
    final batch = _firestore.batch();
    batch.set(historyRef, roomData);
    
    for (var doc in membersSnapshot.docs) {
      batch.set(historyRef.collection('members').doc(doc.id), doc.data());
      batch.delete(doc.reference); // delete original member doc
    }

    // Delete pending_approvals if any
    final pendingSnapshot = await roomRef.collection('pending_approvals').get();
    for(var doc in pendingSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(roomRef);
    
    try {
      await batch.commit();
    } catch (e) {
      print('Failed to archive room: $e');
    }
  }

  // =========================
  // ARCHIVE EXPIRED ROOMS
  // =========================
  Future<void> archiveExpiredRooms() async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      
      final expiredRoomsSnapshot = await _firestore
        .collection('rooms')
        .where('createdAt', isLessThan: Timestamp.fromDate(twentyFourHoursAgo))
        .get();
        
      for (var doc in expiredRoomsSnapshot.docs) {
        await archiveRoom(doc.id);
      }
    } catch (e) {
      print('Error auto-archiving rooms: $e');
    }
  }

  // =========================
  // HISTORY TOURS STREAM
  // =========================
  Stream<List<Map<String, dynamic>>> getHistoryToursStream(String userUid) {
    return _firestore
        .collection('history_tours')
        .where('memberUids', arrayContains: userUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
