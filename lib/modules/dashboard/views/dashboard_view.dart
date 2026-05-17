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
      backgroundColor: const Color(0xFFFFF7EF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // =====================================================
                // HEADER
                // =====================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color(0xFFFFB74D),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Obx(
                    () => Column(
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
                                      : "Namaste 🙏",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  controller.isHindi.value
                                      ? "वर्क टास्क"
                                      : "Work Tasks",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // LANGUAGE

                                InkWell(
                                  onTap: controller.toggleLanguage,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      controller.isHindi.value ? "EN" : "HI",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // REFRESH

                                IconButton(
                                  onPressed: () async {
                                    await controller.fetchTasks();
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                  ),
                                ),

                                // LOGOUT

                                IconButton(
                                  onPressed: () async {
                                    await StorageService.clearAll();

                                    Get.offAllNamed('/login');
                                  },
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // =====================================================
                        // STATS
                        // =====================================================

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatCard(
                              title:
                                  controller.isHindi.value ? "बाकी" : "Pending",
                              value: controller.tasks
                                  .where(
                                    (e) => !e.isCompleted,
                                  )
                                  .length
                                  .toString(),
                              icon: Icons.pending_actions,
                            ),
                            _buildStatCard(
                              title: controller.isHindi.value ? "पूरा" : "Done",
                              value: controller.tasks
                                  .where(
                                    (e) => e.isCompleted,
                                  )
                                  .length
                                  .toString(),
                              icon: Icons.check_circle,
                            ),
                            _buildStatCard(
                              title: controller.isHindi.value ? "कुल" : "Total",
                              value: controller.tasks.length.toString(),
                              icon: Icons.list_alt,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // =====================================================
                // PUNCH BUTTON
                // =====================================================

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Obx(() {
                    final bool isIn =
                        controller.currentPunchStatus.value == "in";

                    return SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: controller.isPunching.value
                            ? null
                            : () async {
                                await controller.handlePunchAction();
                              },
                        icon: controller.isPunching.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isIn ? Icons.fingerprint : Icons.login_rounded,
                              ),
                        label: Text(
                          controller.isPunching.value
                              ? (controller.isHindi.value
                                  ? "कृपया प्रतीक्षा करें..."
                                  : "Please wait...")
                              : isIn
                                  ? (controller.isHindi.value
                                      ? "पंच इन हो चुके हैं"
                                      : "PUNCHED IN")
                                  : (controller.isHindi.value
                                      ? "पंच इन करें"
                                      : "PUNCH IN"),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isIn ? Colors.green : Colors.deepOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                // =====================================================
                // TASK LIST
                // =====================================================

                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (controller.tasks.isEmpty) {
                      return Center(
                        child: Text(
                          controller.isHindi.value
                              ? "कोई टास्क नहीं मिला"
                              : "No tasks found",
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await controller.fetchTasks(
                          showLoader: false,
                        );
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          140,
                        ),
                        itemCount: controller.tasks.length,
                        itemBuilder: (context, index) {
                          final task = controller.tasks[index];

                          return TaskCard(
                            task: task,
                            isHindi: controller.isHindi.value,
                            isHighlighted:
                                controller.highlightedIndex.value == index,
                            isCompleting:
                                controller.completingTasks.contains(task.id),
                            onComplete: () async {
                              await controller.completeTask(task);
                            },
                          );
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),

            // =====================================================
            // FLOATING TASK POPUP
            // =====================================================

            Obx(() {
              final activeTask = controller.getCurrentReminderTask();

              if (activeTask == null) {
                return const SizedBox();
              }

              return FloatingTaskPopup(
                task: activeTask,
                isHindi: controller.isHindi.value,
                onComplete: () async {
                  await controller.completeTask(
                    activeTask,
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // STAT CARD
  // =====================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
