// modules/splash/views/splash_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();

    checkLogin();
  }

  // ================= CHECK LOGIN =================

  Future<void> checkLogin() async {
    await Future.delayed(
      const Duration(seconds: 2),
    );

    final token = await StorageService.getToken();

    if (token.isNotEmpty) {
      Get.offNamed(
        AppRoutes.dashboard,
      );
    } else {
      Get.offNamed(
        AppRoutes.login,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade400,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 100,
            ),
            SizedBox(height: 20),
            Text(
              "VTAP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "VTPs",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
