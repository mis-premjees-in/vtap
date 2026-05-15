// modules/auth/controllers/login_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

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

      print("LOGIN RESPONSE => $data");

      // =====================================================
      // RESPONSE DATA
      // =====================================================

      final responseData = data['response'] ?? {};

      // =====================================================
      // TOKEN
      // =====================================================

      final token = responseData['Access_Token']?.toString() ?? '';

      // =====================================================
      // USER DATA
      // =====================================================

      final userData = responseData['User_Data'] ?? {};

      final username =
          userData['memberID']?.toString() ?? usernameController.text.trim();

      final userId = userData['memberID']?.toString() ?? '';

      // =====================================================
      // VALIDATION
      // =====================================================

      if (token.isEmpty) {
        throw Exception("Token missing from API");
      }

      // =====================================================
      // SAVE LOGIN DATA
      // =====================================================

      await StorageService.saveLoginData(
        token: token,
        username: username,
        userId: userId,
      );

      print("TOKEN SAVED => $token");

      // =====================================================
      // SUCCESS MESSAGE
      // =====================================================

      Get.snackbar(
        "🎉 Welcome Back",
        "Login successful boss 😎",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        borderRadius: 18,
        margin: const EdgeInsets.all(14),
        icon: const Icon(
          Icons.celebration,
          color: Colors.white,
        ),
        duration: const Duration(seconds: 4),
      );

      // =====================================================
      // NAVIGATE
      // =====================================================

      Get.offAllNamed(
        AppRoutes.dashboard,
      );
    } catch (e) {
      print("LOGIN ERROR => $e");

      Get.snackbar(
        "😵 Oops Login Failed",
        "Username ya password galat hai 😅",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade400,
        colorText: Colors.white,
        borderRadius: 18,
        margin: const EdgeInsets.all(14),
        icon: const Icon(
          Icons.error_outline,
          color: Colors.white,
        ),
      );
    } finally {
      isLoading.value = false;
    }
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
