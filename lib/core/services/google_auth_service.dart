import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'storage_service.dart';

class GoogleAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '712249917483-4m24bkqb6bkgcog4f11uqm2d7i6sjkm6.apps.googleusercontent.com'
        : null,
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  // =====================================================
  // CURRENT USER
  // =====================================================

  static User? get currentUser => _auth.currentUser;

  // =====================================================
  // AUTH CHANGES
  // =====================================================

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =====================================================
  // GET OR REFRESH ACCESS TOKEN (SILENT)
  // =====================================================

  static Future<String> getOrRefreshAccessToken() async {
    try {
      // 1. Try to sign in silently first to refresh token if expired
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final String? token = googleAuth.accessToken;
        if (token != null) {
          await StorageService.saveGoogleAccessToken(token);
          return token;
        }
      }
    } catch (e) {
      debugPrint("Silent Sign-In Error => $e");
    }
    // 2. Fallback to currently stored access token
    return await StorageService.getGoogleAccessToken();
  }

  // =====================================================
  // HANDLE WEB REDIRECT (PLACEHOLDER FOR COMPATIBILITY)
  // =====================================================

  static Future<User?> handleRedirectResult() async {
    return null;
  }

  // =====================================================
  // GOOGLE LOGIN (INTERACTIVE)
  // =====================================================

  static Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      // 2. Fetch authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken != null) {
        await StorageService.saveGoogleAccessToken(accessToken);
      }

      // 3. Authenticate with Firebase using Google credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      debugPrint("Google Sign-In Error => $e");
      rethrow;
    }
  }

  // =====================================================
  // LOGOUT
  // =====================================================

  static Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
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
