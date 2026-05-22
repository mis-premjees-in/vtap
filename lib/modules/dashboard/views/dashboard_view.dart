// modules/dashboard/views/dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/floating_task_popup.dart';
import '../../../widgets/task_card.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.put(DashboardController());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Clean Header
                Obx(() => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32)),
                      ),
                      child: Column(
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
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                      controller.isHindi.value
                                          ? "वर्क टास्क"
                                          : "Daily Tasks",
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Row(
                                children: [
                                  _headerCircleBtn(Icons.translate,
                                      controller.toggleLanguage),
                                  const SizedBox(width: 8),
                                  _headerCircleBtn(Icons.refresh,
                                      () => controller.fetchTasks()),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _statBox(
                                  controller.tasks
                                      .where((e) => !e.isCompleted)
                                      .length
                                      .toString(),
                                  "Pending",
                                  Colors.orange),
                              _statBox(
                                  controller.tasks
                                      .where((e) => e.isCompleted)
                                      .length
                                      .toString(),
                                  "Done",
                                  Colors.green),
                              _statBox(controller.tasks.length.toString(),
                                  "Total", Colors.blue),
                            ],
                          )
                        ],
                      ),
                    )),

                // Punch Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Obx(() {
                    bool isIn = controller.currentPunchStatus.value == "in";
                    return SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: controller.isPunching.value
                            ? null
                            : () => controller.handlePunchAction(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isIn ? Colors.green : Colors.deepOrange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: controller.isPunching.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Icon(isIn ? Icons.verified_user : Icons.login,
                                color: Colors.white),
                        label: Text(
                            isIn
                                ? "ACTIVE: PUNCHED IN"
                                : "START WORK: PUNCH IN",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    );
                  }),
                ),

                // Task List
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value)
                      return const Center(child: CircularProgressIndicator());
                    if (controller.tasks.isEmpty)
                      return const Center(
                          child: Text("No tasks for today. Relax!"));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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

            // Reminder Popup Overlay
            Obx(() {
              if (controller.reminderTask.value == null)
                return const SizedBox();
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

  Widget _headerCircleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration:
            BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.black87),
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
          border: Border.all(color: color.withOpacity(0.1))),
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
