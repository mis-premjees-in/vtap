// modules/auth/controllers/login_controller.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/google_auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';
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
        }
      }

      await StorageService.saveLoginData(
        token: token,
        username: username,
        userId: memberId,
        whosId: whosId,
      );

      final premises =
          await repository.apiService.getPremises(username: username);
      final matchedPremise = await LocationService.getMatchedPremise(premises);
      final lastPunchStatus =
          await repository.apiService.getLastPunchStatus(username: memberId);

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

        // if (success) {
        //   await StorageService.saveAttendance(
        //     status: "in",
        //     premiseName: matchedPremise['premises_name'].toString(),
        //   );
        // }
      }

      Get.snackbar(
          "Attendance Marked", "Aapki attendance lag chuki hai! Swagat hai.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);

      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      print("LOGIN ERROR => $e");
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
      print("GOOGLE LOGIN ERROR => $e");
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
        fcmDeviceToken = await FirebaseMessaging.instance.getToken();
        print("REAL FCM DEVICE TOKEN => $fcmDeviceToken");
      } catch (fcmError) {
        print("Error fetching FCM token: $fcmError");
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

      print("GOOGLE EMAIL => $googleEmail");

      final firstLoginResponse = await repository.apiService.first_login();
      print("FIRST LOGIN => $firstLoginResponse");

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

      final backendToken =
          authResponse['response']?['Access_Token']?.toString() ?? '';
      if (backendToken.isEmpty) {
        throw Exception("Unable to generate VTAP token");
      }

      String whosId = "";
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
        }
      }

      if (whosId.isNotEmpty) {
        await repository.apiService.updateWhosGoogleToken(
            username: memberId,
            accessToken: backendToken,
            whosId: whosId,
            googleToken: fcmDeviceToken ?? '',
            firstUser: firstUser,
            firstToken: firstToken);
      }

      await StorageService.saveLoginData(
        token: backendToken,
        username: memberId,
        userId: memberId,
        whosId: whosId,
        firstUser: firstUser,
        firstToken: backendToken,
      );

      final premises =
          await repository.apiService.getPremises(username: memberId);
      final matchedPremise = await LocationService.getMatchedPremise(premises);

      if (matchedPremise != null && whosId.isNotEmpty) {
        final success = await repository.apiService.submitPunch(
          username: memberId,
          accessToken: backendToken,
          type: "In",
          premiseId: matchedPremise['premises_id'].toString(),
          whosId: whosId,
        );

        // if (success) {
        //   await StorageService.saveAttendance(
        //     status: "in",
        //     premiseName: matchedPremise['premises_name'].toString(),
        //   );
        // }
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
      print("GOOGLE HANDLE ERROR => $e");
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
