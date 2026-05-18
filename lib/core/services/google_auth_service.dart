import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // =====================================================
  // CURRENT USER
  // =====================================================

  static User? get currentUser => _auth.currentUser;

  // =====================================================
  // AUTH CHANGES
  // =====================================================

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =====================================================
  // HANDLE WEB REDIRECT
  // =====================================================

  static Future<User?> handleRedirectResult() async {
    if (kIsWeb) {
      try {
        final UserCredential result = await _auth.getRedirectResult();

        return result.user;
      } catch (e) {
        debugPrint("Redirect Result Error => $e");
      }
    }

    return null;
  }

  // =====================================================
  // GOOGLE LOGIN
  // =====================================================

  static Future<User?> signInWithGoogle() async {
    try {
      GoogleAuthProvider provider = GoogleAuthProvider();

      provider.setCustomParameters({
        'prompt': 'select_account',
      });

      // ================= WEB =================

      if (kIsWeb) {
        try {
          final UserCredential userCredential =
              await _auth.signInWithPopup(provider);

          return userCredential.user;
        } catch (e) {
          debugPrint("Popup failed => $e");

          await _auth.signInWithRedirect(provider);

          return null;
        }
      }

      // ================= ANDROID =================

      final UserCredential userCredential =
          await _auth.signInWithProvider(provider);

      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // =====================================================
  // LOGOUT
  // =====================================================

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // =====================================================
  // WEB POLLING
  // =====================================================

  static void startWebPolling({
    required bool Function() isMounted,
    required Function(User user) onUserFound,
  }) {
    Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        if (!isMounted()) {
          timer.cancel();
          return;
        }

        final user = currentUser;

        if (user != null) {
          timer.cancel();

          onUserFound(user);
        }
      },
    );
  }
}
