import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/entities/user_entity.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mendapatkan user yang sedang login
  UserEntity? getCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      return UserEntity(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Unknown',
        photoUrl: user.photoURL ?? '',
      );
    }
    return null;
  }

  // Stream perubahan status login
  Stream<UserEntity?> get userStream {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user != null) {
        return UserEntity(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Unknown',
          photoUrl: user.photoURL ?? '',
        );
      }
      return null;
    });
  }

  // Google Sign-In
  Future<UserEntity?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Batal login

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Simpan atau update data user ke Firestore
        await _saveUserToFirestore(user);
        
        return UserEntity(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Unknown',
          photoUrl: user.photoURL ?? '',
        );
      }
    } catch (e) {
      throw Exception('Gagal login dengan Google: $e');
    }
    return null;
  }

  Future<void> _saveUserToFirestore(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    await userRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isOnline': true,
    }, SetOptions(merge: true));
  }

  // Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
