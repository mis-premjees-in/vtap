import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vtap/core/services/location_bg_service.dart';

import 'core/localization/app_translations.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'routes/app_pages.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vtap/core/services/offline_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const firebaseConfig = FirebaseOptions(
    apiKey: "AIzaSyCtQf4e4hP8EYGcXX0LpPTnQCBbhP0RFP8",
    authDomain: "vtap-6958b.firebaseapp.com",
    projectId: "vtap-6958b",
    storageBucket: "vtap-6958b.firebasestorage.app",
    messagingSenderId: "712249917483",
    appId: "1:712249917483:web:6ff7ab164814691ad72a6e",
  );

  // 1. Initialize Firebase first
  if (kIsWeb) {
    await Firebase.initializeApp(options: firebaseConfig);
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } else {
    await Firebase.initializeApp();
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message while in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint(
          'Message also contained a notification: ${message.notification?.title}');
      Get.snackbar(
        message.notification?.title ?? "Notification",
        message.notification?.body ?? "",
        snackPosition: SnackPosition.TOP,
      );
    }
  });

  // 3. GetStorage init
  await GetStorage.init();
  Get.put(OfflineQueueService());

  if (!kIsWeb) {
    // 4. Notification Service init (Creates local channels now!)
    await NotificationService.init();

    // 🔥 NEW: Launch location boundary geofencing monitor threads
    await LocationBgService.initializeBackgroundTracking();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VTAP',
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
