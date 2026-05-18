// modules/auth/controllers/login_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/google_auth_service.dart';

class LoginController extends GetxController {
  final AuthRepository repository = AuthRepository();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  RxBool isLoading = false.obs;
  RxBool obscurePassword = true.obs;

  // =====================================================
  // LOGIN
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

      // final userId = userData['memberID']?.toString() ?? '';
      final memberId = userData['memberID']?.toString() ?? '';
      String whosId = "";

      if (token.isEmpty) {
        throw Exception("Token missing");
      }

      // =====================================================
      // SAVE LOGIN
      // =====================================================

      await StorageService.saveLoginData(
        token: token,
        username: username,
        userId: memberId,
        whosId: whosId,
      );

      // =====================================================
      // FETCH WHOS ID FROM WHOS TABLE
      // =====================================================
      final whosResponse = await repository.apiService.getTableData(
        tableName: "whos",
        username: username,
        customWhere: "whos_who2='${memberId.toUpperCase()}'",
      );

      if (whosResponse['response']?['Error'] == "0") {
        final records = whosResponse['response']['Records'] as List;

        if (records.isNotEmpty) {
          whosId = records.first['whos_id']?.toString() ?? '';
        }
      }

      print("MEMBER ID => $memberId");
      print("WHOS ID => $whosId");

      // =====================================================
      // FETCH PREMISES
      // =====================================================

      final premises = await repository.apiService.getPremises(
        username: username,
      );

      // =====================================================
      // CHECK LOCATION
      // =====================================================

      final matchedPremise = await LocationService.getMatchedPremise(
        premises,
      );

      // =====================================================
// AUTO CHECK-IN
// =====================================================

      if (matchedPremise != null && whosId.isNotEmpty) {
        final success = await repository.apiService.submitPunch(
          username: username,
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

      Get.offAllNamed(
        AppRoutes.dashboard,
      );
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

      // =========================================
      // HANDLE REDIRECT RESULT
      // =========================================

      final redirectedUser = await GoogleAuthService.handleRedirectResult();

      if (redirectedUser != null) {
        await _handleGoogleUser(redirectedUser);
        return;
      }

      // =========================================
      // NORMAL LOGIN
      // =========================================

      final user = await GoogleAuthService.signInWithGoogle();

      if (user != null) {
        await _handleGoogleUser(user);
        return;
      }

      // =========================================
      // WEB POLLING
      // =========================================

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

  Future<void> _handleGoogleUser(user) async {
    await StorageService.saveLoginData(
      token: user.uid,
      username: user.displayName ?? '',
      userId: user.email ?? '',
      whosId: '',
    );

    Get.snackbar(
      "Success",
      "Google login successful",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );

    Get.offAllNamed(AppRoutes.dashboard);
  }

  // =====================================================
  // TOGGLE PASSWORD
  // =====================================================

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();

    super.onClose();
  }
}
