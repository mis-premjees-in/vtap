import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/login_controller.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final LoginController controller = Get.put(LoginController());

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ================= BACKGROUND GRADIENT =================
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF3E0),
                  Color(0xFFFFE0B2),
                  Colors.white,
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 80),

                    // ================= LOGO ICON =================
                    Container(
                      height: 130,
                      width: 130,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            Colors.deepOrange,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.store_mall_directory,
                        color: Colors.white,
                        size: 60,
                      ),
                    ).animate().fade().scale(),

                    const SizedBox(height: 30),

                    // ================= HEADER TEXT =================
                    const Text(
                      "Premjees VTAP",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "VTAP Smart Checklist System",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ================= LOGIN CARD =================
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.15),
                            blurRadius: 25,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // ================= GOOGLE BUTTON =================
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: Obx(() => OutlinedButton.icon(
                                  onPressed: controller.isLoading.value
                                      ? null
                                      : () => controller.googleLogin(),
                                  icon: controller.isLoading.value
                                      ? const SizedBox.shrink()
                                      : const Icon(Icons.login,
                                          color: Colors.black87),
                                  label: controller.isLoading.value
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 3)
                                      : const Text(
                                          "Continue with Google",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                )),
                          ),

                          const SizedBox(height: 30),

                          // ================= FOOTER =================
                          Text(
                            "✨ VTAP! Certify the execution",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade().slideY(begin: 0.2),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
