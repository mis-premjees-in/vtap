import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/task_card.dart';
import '../../../widgets/task_carousel_card.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.put(DashboardController());

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7EF),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    Color(0xFFFFB74D),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =====================================================
                  // TOP BAR
                  // =====================================================

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
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Work Mode On!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // =====================================================
                          // REFRESH
                          // =====================================================

                          IconButton(
                            onPressed: () async {
                              await controller.fetchTasks(
                                showLoader: true,
                              );
                            },
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                          ),

                          // =====================================================
                          // LOGOUT
                          // =====================================================

                          IconButton(
                            onPressed: () async {
                              await StorageService.clearAll();

                              Get.offAllNamed('/login');

                              Get.snackbar(
                                "Logout",
                                "Logged out successfully",
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: Colors.black87,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(12),
                                borderRadius: 14,
                                duration: const Duration(seconds: 2),
                              );
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

                  const SizedBox(height: 30),

                  // =====================================================
                  // STATS
                  // =====================================================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // =====================================================
                      // PENDING
                      // =====================================================

                      Obx(
                        () => _buildStatCard(
                          title: "Pending",
                          value: controller.tasks
                              .where(
                                (t) => !t.isCompleted,
                              )
                              .length
                              .toString(),
                          icon: Icons.pending_actions_rounded,
                        ),
                      ),

                      // =====================================================
                      // COMPLETED
                      // =====================================================

                      Obx(
                        () => _buildStatCard(
                          title: "Done",
                          value: controller.tasks
                              .where(
                                (t) => t.isCompleted,
                              )
                              .length
                              .toString(),
                          icon: Icons.task_alt_rounded,
                        ),
                      ),

                      // =====================================================
                      // LANGUAGE
                      // =====================================================

                      GestureDetector(
                        onTap: () {
                          controller.toggleLanguage();
                        },
                        child: Obx(
                          () => _buildStatCard(
                            title: "Language",
                            value: controller.isHindi.value ? "HI" : "EN",
                            icon: Icons.translate_rounded,
                          ),
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
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                0,
              ),
              child: Obx(() {
                final bool isIn = controller.currentPunchStatus.value == "in";

                return InkWell(
                  borderRadius: BorderRadius.circular(35),
                  onTap: controller.isPunching.value
                      ? null
                      : () async {
                          await controller.handlePunchAction();
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 68,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isIn
                            ? [
                                Colors.green,
                                Colors.greenAccent,
                              ]
                            : [
                                Colors.red,
                                Colors.orange,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: controller.isPunching.value
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isIn
                                    ? Icons.fingerprint_rounded
                                    : Icons.login_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isIn ? "🟢 PUNCHED IN" : "🔴 PUNCH IN",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }),
            ),

            // =====================================================
            // TASKS HEADER
            // =====================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your Tasks",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Obx(
                    () => IconButton(
                      onPressed: () {
                        controller.isCarousel.value =
                            !controller.isCarousel.value;
                      },
                      icon: Icon(
                        controller.isCarousel.value
                            ? Icons.view_list_rounded
                            : Icons.view_carousel_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =====================================================
            // TASK LIST
            // =====================================================

            Expanded(
              child: Obx(() {
                // =====================================================
                // LOADER
                // =====================================================

                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                    ),
                  );
                }

                // =====================================================
                // EMPTY
                // =====================================================

                if (controller.tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 70,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "No tasks found",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // =====================================================
                // CAROUSEL VIEW
                // =====================================================

                if (controller.isCarousel.value) {
                  return PageView.builder(
                    controller: PageController(
                      viewportFraction: 0.88,
                    ),
                    itemCount: controller.tasks.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final task = controller.tasks[index];

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 20,
                        ),
                        child: TaskCarouselCard(
                          task: task,
                          isHindi: controller.isHindi.value,
                          onComplete: () async {
                            await controller.completeTask(task);
                          },
                        ),
                      );
                    },
                  );
                }

                // =====================================================
                // LIST VIEW
                // =====================================================

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await controller.fetchTasks(
                      showLoader: false,
                    );
                  },
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      20,
                    ),
                    itemCount: controller.tasks.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final task = controller.tasks[index];

                      return TaskCard(
                        task: task,
                        isHindi: controller.isHindi.value,
                        isHighlighted:
                            controller.highlightedIndex.value == index,
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
      width: 95,
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 10,
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
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
