import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/domain/entities/user_entity.dart';

/// Service untuk mengelola profil user dan skema sosial di Firestore.
///
/// Skema Firestore:
/// - users/{uid}                         → profil user + field invitations[]
/// - users/{uid}/friends/{friendUid}     → daftar pertemanan
/// - friend_requests/{fromUid}_{toUid}   → permintaan pertemanan
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Profile ───────────────────────────────────────────────────────────────

  Future<void> syncUserProfile(UserEntity user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
      'lastSeen': FieldValue.serverTimestamp(),
      'isOnline': true,
    }, SetOptions(merge: true));
  }

  Future<void> setOffline(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>?> getUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => doc.data(),
        );
  }

  Future<Map<String, dynamic>?> getUserProfileOnce(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // ─── Friend Requests ───────────────────────────────────────────────────────

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    final requestId = '${fromUid}_$toUid';
    // Pastikan request sebaliknya belum ada
    final reverseDoc = await _firestore
        .collection('friend_requests')
        .doc('${toUid}_$fromUid')
        .get();
    if (reverseDoc.exists && reverseDoc['status'] == 'pending') {
      // Auto-accept jika sudah ada request dari yang dituju
      await acceptFriendRequest('${toUid}_$fromUid', toUid, fromUid);
      return;
    }

    await _firestore.collection('friend_requests').doc(requestId).set({
      'fromUid': fromUid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String requestId, String fromUid, String toUid) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('friend_requests').doc(requestId),
      {'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()},
    );

    batch.set(
      _firestore.collection('users').doc(toUid).collection('friends').doc(fromUid),
      {'uid': fromUid, 'addedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _firestore.collection('users').doc(fromUid).collection('friends').doc(toUid),
      {'uid': toUid, 'addedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cek apakah dua user sudah berteman
  Future<bool> areFriends(String myUid, String otherUid) async {
    final doc = await _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  /// Cek apakah sudah ada request pending antara dua user
  Future<bool> hasPendingRequest(String fromUid, String toUid) async {
    final a = await _firestore
        .collection('friend_requests')
        .doc('${fromUid}_$toUid')
        .get();
    if (a.exists && a['status'] == 'pending') return true;
    final b = await _firestore
        .collection('friend_requests')
        .doc('${toUid}_$fromUid')
        .get();
    return b.exists && b['status'] == 'pending';
  }

  // ─── Friend List Stream ────────────────────────────────────────────────────

  /// Stream UID teman
  Stream<List<String>> getFriendsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  /// Stream incoming friend requests (belum ditolak/diterima)
  Stream<List<QueryDocumentSnapshot>> getIncomingRequestsStream(String myUid) {
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs);
  }

  // ─── Invitation / Direct Invite ───────────────────────────────────────────

  /// Kirim undangan room langsung ke teman. Disimpan di field invitations[] user.
  Future<void> sendRoomInvite({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String roomCode,
    required String rideName,
  }) async {
    await _firestore.collection('users').doc(toUid).update({
      'invitations': FieldValue.arrayUnion([
        {
          'fromUid': fromUid,
          'fromName': fromName,
          'roomCode': roomCode,
          'rideName': rideName,
          'sentAt': DateTime.now().toIso8601String(),
        }
      ]),
    });
  }

  /// Stream undangan masuk yang belum direspon
  Stream<List<Map<String, dynamic>>> getInvitationsStream(String myUid) {
    return _firestore.collection('users').doc(myUid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return [];
      final raw = doc.data()!['invitations'];
      if (raw == null || raw is! List) return [];
      return List<Map<String, dynamic>>.from(raw);
    });
  }

  /// Hapus undangan setelah diaksi (join / tolak)
  Future<void> dismissInvitation(String myUid, Map<String, dynamic> invite) async {
    await _firestore.collection('users').doc(myUid).update({
      'invitations': FieldValue.arrayRemove([invite]),
    });
  }

  /// Stream teman yang sedang online (Real-time)
  Stream<List<Map<String, dynamic>>> getOnlineFriendsStream(String myUid) {
    return getFriendsStream(myUid).asyncExpand((uids) {
      if (uids.isEmpty) return Stream.value([]);
      
      return _firestore
          .collection('users')
          .where('uid', whereIn: uids)
          .where('isOnline', isEqualTo: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    });
  }
}
