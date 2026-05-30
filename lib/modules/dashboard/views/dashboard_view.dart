import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/floating_task_popup.dart';
import '../../../widgets/task_card.dart';
import '../controllers/dashboard_controller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});
  void _requestNotificationPermission() async {
    // Uses structural platform-checking mechanisms built directly into the core
    if (GetPlatform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.put(DashboardController());
    _requestNotificationPermission();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Optimized Header Card
                Obx(() => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.isHindi.value
                                        ? "नमस्ते 🙏"
                                        : "Hello, Team!",
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    controller.isHindi.value
                                        ? "वर्क टास्क"
                                        : "Daily Tasks",
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // Controls Row
                              Row(
                                children: [
                                  _headerCircleBtn(Icons.translate,
                                      controller.toggleLanguage),
                                  const SizedBox(width: 8),
                                  _headerCircleBtn(Icons.refresh,
                                      () => controller.fetchTasks()),
                                  const SizedBox(width: 8),
                                  _headerCircleBtn(
                                      Icons.logout_rounded,
                                      () => _showLogoutDialog(
                                          context, controller),
                                      isDestructive: true),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          // NEW: Clickable & Color Dynamic Punch Indicator
                          // DashboardView ke andar Punch Button ka logic replace karein:

                          // Part of your dashboard_view.dart layout file

                          // Part of modules/dashboard/views/dashboard_view.dart

                          // Part of modules/dashboard/views/dashboard_view.dart

                          Obx(() {
                            // Enforce a safe lowercase validation for UI representation
                            final String rawStatus = controller
                                .currentPunchStatus.value
                                .toString()
                                .toLowerCase()
                                .trim();
                            final bool isIn = rawStatus == "in";

                            return InkWell(
                              onTap: controller.isPunching.value
                                  ? null
                                  : () {
                                      Get.defaultDialog(
                                        title: isIn
                                            ? (controller.isHindi.value
                                                ? "पंच-आउट?"
                                                : "Punch Out?")
                                            : (controller.isHindi.value
                                                ? "पंच-इन?"
                                                : "Punch In?"),
                                        middleText: controller.isHindi.value
                                            ? "क्या आप अटेंडेंस मार्क करना चाहते हैं?"
                                            : "Do you want to mark your attendance?",
                                        textConfirm: controller.isHindi.value
                                            ? "हाँ"
                                            : "Yes",
                                        textCancel: controller.isHindi.value
                                            ? "नहीं"
                                            : "No",
                                        confirmTextColor: Colors.white,
                                        buttonColor:
                                            isIn ? Colors.red : Colors.green,
                                        onConfirm: () {
                                          Get.back(); // Clear confirmation modal cleanly
                                          controller
                                              .handlePunchAction(); // Fire synchronized operation
                                        },
                                      );
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isIn
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isIn ? Colors.green : Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    controller.isPunching.value
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: isIn
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          )
                                        : Icon(
                                            isIn
                                                ? Icons.verified_user_rounded
                                                : Icons
                                                    .radio_button_off_rounded,
                                            size: 18,
                                            color: isIn
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                    const SizedBox(width: 10),
                                    Text(
                                      controller.isPunching.value
                                          ? "SYNCING..."
                                          : (isIn
                                              ? (controller.isHindi.value
                                                  ? "सक्रिय: ड्युटी पर"
                                                  : "ACTIVE: LOGGED IN")
                                              : (controller.isHindi.value
                                                  ? "शुरू करें: पंच इन"
                                                  : "OFFLINE: PUNCH IN")),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isIn ? Colors.green : Colors.red,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 15),

                          // Stats Metrics
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _statBox(
                                  controller.tasks
                                      .where((e) => !e.isCompleted)
                                      .length
                                      .toString(),
                                  controller.isHindi.value ? "बाकी" : "Pending",
                                  Colors.orange),
                              _statBox(
                                  controller.tasks
                                      .where((e) => e.isCompleted)
                                      .length
                                      .toString(),
                                  controller.isHindi.value
                                      ? "पूरे हुए"
                                      : "Done",
                                  Colors.green),
                              _statBox(
                                  controller.tasks.length.toString(),
                                  controller.isHindi.value ? "कुल" : "Total",
                                  Colors.blue),
                            ],
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 10),

                // Task List (Now covers more screen area)
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.deepOrange));
                    }
                    if (controller.tasks.isEmpty) {
                      return Center(
                          child: Text(controller.isHindi.value
                              ? "आज कोई टास्क नहीं है"
                              : "No tasks found."));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      itemCount: controller.tasks.length,
                      itemBuilder: (context, index) {
                        return TaskCard(
                          task: controller.tasks[index],
                          isHindi: controller.isHindi.value,
                          isHighlighted:
                              controller.highlightedIndex.value == index,
                        );
                      },
                    );
                  }),
                ),
              ],
            ),

            // Reminder Popup
            Obx(() {
              if (controller.reminderTask.value == null) {
                return const SizedBox();
              }
              return FloatingTaskPopup(
                task: controller.reminderTask.value!,
                isHindi: controller.isHindi.value,
                onComplete: () =>
                    controller.completeTask(controller.reminderTask.value!),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, DashboardController controller) {
    Get.defaultDialog(
      title: controller.isHindi.value ? "लॉगआउट" : "Logout",
      middleText: controller.isHindi.value
          ? "क्या आप बाहर निकलना चाहते हैं?"
          : "Do you want to logout?",
      textConfirm: controller.isHindi.value ? "हाँ" : "Yes",
      textCancel: controller.isHindi.value ? "नहीं" : "No",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () => controller.logoutUser(),
    );
  }

  Widget _headerCircleBtn(IconData icon, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade50 : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 20, color: isDestructive ? Colors.redAccent : Colors.black87),
      ),
    );
  }

  Widget _statBox(String val, String label, Color color) {
    return Container(
      width: Get.width * 0.28,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
