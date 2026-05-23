// modules/auth/controllers/login_controller.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  // MD5 generator context code
  String computeMd5Hash(String value) {
    return md5.convert(utf8.encode(value)).toString();
  }

  // =====================================================
  // NORMAL LOGIN
  // =====================================================
  Future<void> login() async {
    try {
      isLoading.value = true;

      final response = await repository.login(
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );

      final data = response.data;
      final responseData = data['response'] ?? {};
      final token = responseData['Access_Token']?.toString() ?? '';
      final userData = responseData['User_Data'] ?? {};
      final username =
          userData['memberID']?.toString() ?? usernameController.text.trim();
      final memberId = userData['memberID']?.toString() ?? '';

      if (token.isEmpty) {
        throw Exception("Token missing");
      }

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
          await repository.apiService.getLastPunchStatus(username: username);

      if (matchedPremise != null &&
          whosId.isNotEmpty &&
          lastPunchStatus != "in") {
        final success = await repository.apiService.submitPunch(
          username: username,
          accessToken: token,
          type: "In",
          premiseId: matchedPremise['premises_id'].toString(),
          whosId: whosId,
        );

        if (success) {
          await StorageService.saveAttendance(
            status: "in",
            premiseName: matchedPremise['premises_name'].toString(),
          );
        }
      }

      Get.snackbar(
        "Success",
        "Login successful",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

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
  Future<void> _handleGoogleUser(user) async {
    try {
      isLoading.value = true;

      final String googleEmail = user.email?.toString().trim() ?? "";
      if (googleEmail.isEmpty) {
        throw Exception("Google email not found");
      }

      final String googleToken = await user.getIdToken();

      await StorageService.saveGoogleData(
        email: googleEmail,
        uid: user.uid,
        token: googleToken,
      );

      print("GOOGLE EMAIL => $googleEmail");

      // STEP 1 => AUTH LOGIN USING DEFAULT CREDS
      final firstLoginResponse = await repository.apiService.login(
        username: "tm_premjees",
        password: "Another10\$1",
      );

      print("FIRST LOGIN => $firstLoginResponse");
      final firstLoginData = firstLoginResponse['response'] ?? {};
      final firstToken = firstLoginData['Access_Token']?.toString() ?? '';

      if (firstToken.isEmpty) {
        throw Exception("Unable to generate initial token");
      }

      // STEP 2 => FIND USER FROM membership_users WITH VALID FILTER
      final memberResponse = await repository.apiService.getTableData(
        tableName: "membership_users",
        username: "tm_premjees",
        access_token: firstToken,
        customWhere: "email='$googleEmail'",
      );

      print("MEMBER RESPONSE => $memberResponse");

      if (memberResponse['response']?['Error'] != "0") {
        throw Exception(
          memberResponse['response']?['Message'] ?? "User not found",
        );
      }

      final records = memberResponse['response']['Records'] as List;
      if (records.isEmpty) {
        throw Exception("No VTAP account linked with this email");
      }

      final memberData = records.first;
      final memberId = memberData['memberID']?.toString() ?? "";

      // FIXED: Database se direct passMD5 column uthayen (Bcrypt hash)
      final dbPassMD5 = memberData['passMD5']?.toString() ?? "";

      if (memberId.isEmpty || dbPassMD5.isEmpty) {
        throw Exception("Membership data invalid");
      }

      print("MEMBER ID => $memberId | DB HASH => $dbPassMD5");

      // SECOND AUTH LOGIN USING MEMBER ACCOUNT
      // FIXED: dbPassMD5 ko 'md5' parameter mein bhejें, na ki 'password' mein.
      final authResponse = await repository.apiService.login(
        username: memberId,
        password: "",
        md5: dbPassMD5,
      );

      print("SECOND AUTH RESPONSE => $authResponse");
      final backendToken =
          authResponse['response']?['Access_Token']?.toString() ?? '';

      if (backendToken.isEmpty) {
        throw Exception("Unable to generate VTAP token");
      }

      // STEP 3 => FETCH WHOS ID
      String whosId = "";
      final whosResponse = await repository.apiService.getTableData(
        tableName: "whos",
        username: memberId,
        access_token: backendToken,
        customWhere: "whos_who2='${memberId.toUpperCase()}'",
      );

      print("WHOS RESPONSE => $whosResponse");

      if (whosResponse['response']?['Error'] == "0") {
        final whosRecords = whosResponse['response']['Records'] as List;
        if (whosRecords.isNotEmpty) {
          final whosData = whosRecords.first;
          whosId = whosData['whos_id']?.toString() ?? '';
        }
      }

      print("WHOS ID => $whosId");

      // STEP 4 => SAVE GOOGLE TOKEN INTO WHOS TABLE
      if (whosId.isNotEmpty) {
        await repository.apiService.updateWhosGoogleToken(
          username: memberId,
          accessToken: backendToken,
          whosId: whosId,
          googleToken: googleToken,
        );
      }

      // STEP 5 => SAVE LOGIN DATA LOCALLY (Overwriting with the 2nd token)
      await StorageService.saveLoginData(
        token: backendToken,
        username: memberId,
        userId: memberId,
        whosId: whosId,
      );

      // STEP 6 => FETCH PREMISES
      final premises =
          await repository.apiService.getPremises(username: memberId);
      final matchedPremise = await LocationService.getMatchedPremise(premises);

      // STEP 8 => AUTO PUNCH-IN
      if (matchedPremise != null && whosId.isNotEmpty) {
        final success = await repository.apiService.submitPunch(
          username: memberId,
          accessToken: backendToken,
          type: "In",
          premiseId: matchedPremise['premises_id'].toString(),
          whosId: whosId,
        );

        if (success) {
          await StorageService.saveAttendance(
            status: "in",
            premiseName: matchedPremise['premises_name'].toString(),
          );
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
