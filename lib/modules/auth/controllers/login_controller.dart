// modules/auth/controllers/login_controller.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';

import '../../../core/services/google_auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/location_bg_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final AuthRepository repository = AuthRepository();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  RxBool isLoading = false.obs;
  RxBool obscurePassword = true.obs;

  String computeMd5Hash(String value) {
    return md5.convert(utf8.encode(value)).toString();
  }

  // =====================================================
  // NORMAL LOGIN
  // =====================================================
  Future<void> login() async {
    try {
      isLoading.value = true;

      // Accessing login direct from apiService instance mapping
      final response = await repository.apiService.login(
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
        md5: computeMd5Hash(passwordController.text.trim()),
      );

      final data = response;
      final responseData = data['response'] ?? {};
      final token = responseData['Access_Token']?.toString() ?? '';
      final userData = responseData['User_Data'] ?? {};
      final username =
          userData['memberID']?.toString() ?? usernameController.text.trim();
      final memberId = userData['memberID']?.toString() ?? '';

      if (token.isEmpty) throw Exception("Token missing");

      String whosId = "";
      String whosPremise = "";
      final whosResponse = await repository.apiService.getTableData(
        tableName: "whos",
        username: username,
        access_token: token,
        customWhere: "whos_who2='${memberId.toUpperCase()}'",
      );

      if (whosResponse['response']?['Error'] == "0") {
        final records = whosResponse['response']['Records'] as List;
        if (records.isNotEmpty) {
          whosId = records.first['whos_id']?.toString() ?? '';
          whosPremise = records.first['whos_premise']?.toString() ?? '';
        }
      }

      final groupId = userData['groupID']?.toString() ?? '';

      // Request notification permission and retrieve FCM token
      String? fcmDeviceToken;
      try {
        final NotificationSettings settings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          fcmDeviceToken = await FirebaseMessaging.instance.getToken();
          debugPrint("REAL FCM DEVICE TOKEN => $fcmDeviceToken");
        }
      } catch (fcmError) {
        debugPrint("Error fetching FCM token: $fcmError");
      }

      if (whosId.isNotEmpty &&
          fcmDeviceToken != null &&
          fcmDeviceToken.isNotEmpty) {
        await repository.apiService.updateWhosGoogleToken(
          username: memberId,
          accessToken: token,
          whosId: whosId,
          googleToken: fcmDeviceToken,
        );
      }

      await StorageService.saveLoginData(
        token: token,
        username: username,
        userId: memberId,
        whosId: whosId,
        groupId: groupId,
        whosPremise: whosPremise,
      );

      if (whosId.trim().isEmpty) {
        Get.snackbar("Warning", "Mapped profile not found (Missing Whos ID). Attendance features will be locked.",
            backgroundColor: Colors.amber, colorText: Colors.black87, duration: const Duration(seconds: 5));
      }

      final premises =
          await repository.apiService.getPremises(username: username);

      // Save details of assigned premise to Storage for native Kotlin service
      Map<String, dynamic>? matchingPremise;
      for (final p in premises) {
        if (p['premises_id']?.toString() == whosPremise) {
          matchingPremise = Map<String, dynamic>.from(p);
          break;
        }
      }

      if (matchingPremise != null) {
        final double? lat = double.tryParse(matchingPremise['premises_latitude']?.toString() ?? '');
        final double? lng = double.tryParse(matchingPremise['premises_longitude']?.toString() ?? '');
        final double? radius = double.tryParse(matchingPremise['premises_radius']?.toString() ?? '');
        final String name = matchingPremise['premises_name']?.toString() ?? 'Workspace';
        if (lat != null && lng != null && radius != null) {
          await StorageService.savePremiseDetails(lat: lat, lng: lng, radius: radius, name: name);
        }
      }

      final matchedPremise = await LocationService.getMatchedPremise(premises);
      final lastPunchStatus =
          await repository.apiService.getLastPunchStatus(username: memberId);

      bool isPunchedIn = lastPunchStatus != "out";

      if (matchedPremise != null &&
          whosId.isNotEmpty &&
          lastPunchStatus != "out") {
        final success = await repository.apiService.submitPunch(
          username: memberId,
          accessToken: token,
          type: "In",
          premiseId: matchedPremise['premises_id'].toString(),
          whosId: whosId,
        );

        if (success) {
          isPunchedIn = true;
        }
      }

      await StorageService.saveAttendanceStatus(isPunchedIn ? "in" : "out");

      if (!kIsWeb) {
        try {
          await LocationService.requestBackgroundLocationPermission();
          await LocationBgService.startServiceIfPermissionsGranted();
          await StorageService.addLog("Foreground App: Invoking background tracking start on login");
          FlutterBackgroundService().invoke('startTracking');
          FlutterBackgroundService().invoke('updatePunchStatus', {'status': isPunchedIn ? "in" : "out"});
        } catch (bgError) {
          await StorageService.addLog("Foreground App: Background tracking invoke on login failed: $bgError");
          debugPrint("Background service tracking invoke failed: $bgError");
        }
      }

      Get.snackbar(
          "Attendance Marked", "Aapki attendance lag chuki hai! Swagat hai.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);

      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      debugPrint("LOGIN ERROR => $e");
      Get.snackbar(
        "Login Failed",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =====================================================
  // GOOGLE LOGIN
  // =====================================================
  Future<void> googleLogin() async {
    try {
      isLoading.value = true;

      final redirectedUser = await GoogleAuthService.handleRedirectResult();
      if (redirectedUser != null) {
        await _handleGoogleUser(redirectedUser);
        return;
      }

      final user = await GoogleAuthService.signInWithGoogle();
      if (user != null) {
        await _handleGoogleUser(user);
        return;
      }

      GoogleAuthService.startWebPolling(
        isMounted: () => true,
        onUserFound: (user) async {
          await _handleGoogleUser(user);
        },
      );
    } catch (e) {
      debugPrint("GOOGLE LOGIN ERROR => $e");
      Get.snackbar(
        "Google Login Failed",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =====================================================
  // FIXED HANDLE GOOGLE USER PROCESS
  // =====================================================
  Future<void> _handleGoogleUser(dynamic user) async {
    try {
      isLoading.value = true;

      String? fcmDeviceToken;
      try {
        final NotificationSettings settings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          fcmDeviceToken = await FirebaseMessaging.instance.getToken();
          debugPrint("REAL FCM DEVICE TOKEN => $fcmDeviceToken");
        }
      } catch (fcmError) {
        debugPrint("Error fetching FCM token: $fcmError");
      }

      final String googleEmail = user.email?.toString().trim() ?? "";
      if (googleEmail.isEmpty) {
        throw Exception("Google email not found");
      }

      await StorageService.saveGoogleData(
        email: googleEmail,
        uid: user.uid.toString(), // Fixes property access type errors
        token: fcmDeviceToken ?? '',
      );

      debugPrint("GOOGLE EMAIL => $googleEmail");

      final firstLoginResponse = await repository.apiService.first_login();
      debugPrint("FIRST LOGIN => $firstLoginResponse");

      final firstLoginData = firstLoginResponse['response'] ?? {};
      final firstUser = firstLoginData['MemberId']?.toString() ?? '';
      final firstToken = firstLoginData['Access_Token']?.toString() ?? '';

      if (firstToken.isEmpty) {
        throw Exception("Unable to generate initial token");
      }

      final memberResponse = await repository.apiService.getTableData(
        tableName: "membership_users",
        username: firstUser,
        access_token: firstToken,
        customWhere: "email='$googleEmail'",
      );

      if (memberResponse['response']?['Error'] != "0") {
        throw Exception(
            memberResponse['response']?['Message'] ?? "User not found");
      }

      final records = memberResponse['response']['Records'] as List;
      if (records.isEmpty) {
        throw Exception("No VTAP account linked with this email");
      }

      final memberData = records.first;
      final memberId = memberData['memberID']?.toString() ?? "";
      final dbPassMD5 = memberData['passMD5']?.toString() ?? "";

      if (memberId.isEmpty || dbPassMD5.isEmpty) {
        throw Exception("Membership data invalid");
      }

      final authResponse = await repository.apiService.login(
        username: memberId,
        password: "",
        md5: dbPassMD5,
      );

      final authResponseData = authResponse['response'] ?? {};
      final backendToken =
          authResponseData['Access_Token']?.toString() ?? '';
      final authUserData = authResponseData['User_Data'] ?? {};
      final googleGroupId = authUserData['groupID']?.toString() ?? '';

      if (backendToken.isEmpty) {
        throw Exception("Unable to generate VTAP token");
      }

      String whosId = "";
      String whosPremise = "";
      final whosResponse = await repository.apiService.getTableData(
        tableName: "whos",
        username: memberId,
        access_token: backendToken,
        customWhere: "whos_who2='${memberId.toUpperCase()}'",
      );

      if (whosResponse['response']?['Error'] == "0") {
        final whosRecords = whosResponse['response']['Records'] as List;
        if (whosRecords.isNotEmpty) {
          whosId = whosRecords.first['whos_id']?.toString() ?? '';
          whosPremise = whosRecords.first['whos_premise']?.toString() ?? '';
        }
      }

      if (whosId.isNotEmpty &&
          fcmDeviceToken != null &&
          fcmDeviceToken.isNotEmpty) {
        await repository.apiService.updateWhosGoogleToken(
          username: memberId,
          accessToken: backendToken,
          whosId: whosId,
          googleToken: fcmDeviceToken,
        );
      }

      await StorageService.saveLoginData(
        token: backendToken,
        username: memberId,
        userId: memberId,
        whosId: whosId,
        groupId: googleGroupId,
        firstUser: firstUser,
        firstToken: backendToken,
        whosPremise: whosPremise,
      );

      if (whosId.trim().isEmpty) {
        Get.snackbar("Warning", "Mapped profile not found (Missing Whos ID). Attendance features will be locked.",
            backgroundColor: Colors.amber, colorText: Colors.black87, duration: const Duration(seconds: 5));
      }

      final premises =
          await repository.apiService.getPremises(username: memberId);

      // Save details of assigned premise to Storage for native Kotlin service
      Map<String, dynamic>? matchingPremise;
      for (final p in premises) {
        if (p['premises_id']?.toString() == whosPremise) {
          matchingPremise = Map<String, dynamic>.from(p);
          break;
        }
      }

      if (matchingPremise != null) {
        final double? lat = double.tryParse(matchingPremise['premises_latitude']?.toString() ?? '');
        final double? lng = double.tryParse(matchingPremise['premises_longitude']?.toString() ?? '');
        final double? radius = double.tryParse(matchingPremise['premises_radius']?.toString() ?? '');
        final String name = matchingPremise['premises_name']?.toString() ?? 'Workspace';
        if (lat != null && lng != null && radius != null) {
          await StorageService.savePremiseDetails(lat: lat, lng: lng, radius: radius, name: name);
        }
      }

      final matchedPremise = await LocationService.getMatchedPremise(premises);

      bool googleIsPunchedIn = false;
      if (matchedPremise != null && whosId.isNotEmpty) {
        final success = await repository.apiService.submitPunch(
          username: memberId,
          accessToken: backendToken,
          type: "In",
          premiseId: matchedPremise['premises_id'].toString(),
          whosId: whosId,
        );

        if (success) {
          googleIsPunchedIn = true;
        }
      }

      await StorageService.saveAttendanceStatus(googleIsPunchedIn ? "in" : "out");

      if (!kIsWeb) {
        try {
          await LocationService.requestBackgroundLocationPermission();
          await LocationBgService.startServiceIfPermissionsGranted();
          await StorageService.addLog("Foreground App: Invoking background tracking start on Google login");
          FlutterBackgroundService().invoke('startTracking');
          FlutterBackgroundService().invoke('updatePunchStatus', {'status': googleIsPunchedIn ? "in" : "out"});
        } catch (bgError) {
          await StorageService.addLog("Foreground App: Background tracking invoke on Google login failed: $bgError");
          debugPrint("Background service tracking invoke failed: $bgError");
        }
      }

      Get.snackbar(
        "Success",
        "Google login successful",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      debugPrint("GOOGLE HANDLE ERROR => $e");
      Get.snackbar(
        "Google Login Failed",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
