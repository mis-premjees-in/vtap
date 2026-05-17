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
                // COMPACT HEADER
                // =====================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color(0xFFFFB74D),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Namaste 🙏",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Work Tasks",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // LANGUAGE

                              Obx(
                                () => InkWell(
                                  onTap: controller.toggleLanguage,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      controller.isHindi.value ? "HI" : "EN",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // REFRESH

                              IconButton(
                                onPressed: () async {
                                  await controller.fetchTasks();
                                },
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                ),
                              ),

                              // LOGOUT

                              IconButton(
                                onPressed: () async {
                                  await StorageService.clearAll();

                                  Get.offAllNamed(
                                    '/login',
                                  );
                                },
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // =====================================================
                      // STATS
                      // =====================================================

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Obx(
                            () => _buildStatCard(
                              title: "Pending",
                              value: controller.tasks
                                  .where(
                                    (t) => !t.isCompleted,
                                  )
                                  .length
                                  .toString(),
                              icon: Icons.pending,
                            ),
                          ),
                          Obx(
                            () => _buildStatCard(
                              title: "Done",
                              value: controller.tasks
                                  .where(
                                    (t) => t.isCompleted,
                                  )
                                  .length
                                  .toString(),
                              icon: Icons.check_circle,
                            ),
                          ),
                          Obx(
                            () => _buildStatCard(
                              title: "Total",
                              value: controller.tasks.length.toString(),
                              icon: Icons.list_alt,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                        icon: Icon(
                          isIn ? Icons.fingerprint : Icons.login,
                        ),
                        label: Text(
                          isIn ? "PUNCHED IN" : "PUNCH IN",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isIn ? Colors.green : Colors.deepOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                // =====================================================
                // TASKS
                // =====================================================

                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (controller.tasks.isEmpty) {
                      return const Center(
                        child: Text(
                          "No tasks found",
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
                          0,
                          16,
                          120,
                        ),
                        itemCount: controller.tasks.length,
                        itemBuilder: (context, index) {
                          final task = controller.tasks[index];

                          return TaskCard(
                            task: task,
                            isHindi: controller.isHindi.value,
                            isHighlighted:
                                controller.highlightedIndex.value == index,
                            onComplete: () async {
                              await controller.completeTask(
                                task,
                              );
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
            // FLOATING POPUP
            // =====================================================

            Obx(() {
              final activeTask = controller.getCurrentReminderTask();

              if (activeTask == null) {
                return const SizedBox();
              }

              return FloatingTaskPopup(
                task: activeTask,
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
      width: 82,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
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
              fontSize: 15,
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
