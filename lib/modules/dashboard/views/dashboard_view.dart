import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                25,
                20,
                30,
              ),
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
                  // TOP ROW
                  // =====================================================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.isHindi.value
                                  ? "प्रेमजी टास्क मास्टर"
                                  : "Premjees Task Master",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              controller.isHindi.value
                                  ? "डेली चेकलिस्ट डैशबोर्ड"
                                  : "Daily Checklist Dashboard",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // =====================================================
                      // LANGUAGE BUTTON
                      // =====================================================

                      Obx(
                        () => GestureDetector(
                          onTap: () {
                            controller.toggleLanguage();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(
                                18,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.language,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(
                                  width: 6,
                                ),
                                Text(
                                  controller.isHindi.value
                                      ? "हिंदी"
                                      : "English",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // TOGGLE BUTTON
                  // =====================================================

                  Obx(
                    () => ElevatedButton.icon(
                      onPressed: controller.toggleView,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      icon: Icon(
                        controller.isCarousel.value
                            ? Icons.view_list
                            : Icons.view_carousel,
                      ),
                      label: Text(
                        controller.isCarousel.value
                            ? "List View"
                            : "Carousel View",
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =====================================================
                  // STATS CARD
                  // =====================================================

                  Obx(
                    () {
                      final total = controller.tasks.length;

                      final completed = controller.tasks
                          .where(
                            (e) => e.isCompleted,
                          )
                          .length;

                      final pending = total - completed;

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(
                            24,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: controller.isHindi.value
                                    ? "टास्क"
                                    : "Tasks",
                                value: total.toString(),
                                icon: Icons.task_alt,
                              ),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                title:
                                    controller.isHindi.value ? "पूर्ण" : "Done",
                                value: completed.toString(),
                                icon: Icons.check_circle,
                              ),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                title: controller.isHindi.value
                                    ? "बाकी"
                                    : "Pending",
                                value: pending.toString(),
                                icon: Icons.pending_actions,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // =====================================================
            // TASKS
            // =====================================================

            Expanded(
              child: Obx(
                () {
                  // =====================================================
                  // LOADING
                  // =====================================================

                  if (controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // =====================================================
                  // EMPTY
                  // =====================================================

                  if (controller.tasks.isEmpty) {
                    return Center(
                      child: Text(
                        controller.isHindi.value
                            ? "कोई टास्क उपलब्ध नहीं है"
                            : "No Tasks Available",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

                  // =====================================================
                  // CAROUSEL VIEW
                  // =====================================================

                  if (controller.isCarousel.value) {
                    return PageView.builder(
                      itemCount: controller.tasks.length,
                      itemBuilder: (context, index) {
                        final task = controller.tasks[index];

                        return TaskCarouselCard(
                          task: task,
                          isHindi: controller.isHindi.value,
                          remarksController: TextEditingController(),
                          image: null,
                          onUpload: () {},
                          onComplete: () {
                            controller.completeTask(
                              index,
                            );
                          },
                        );
                      },
                    );
                  }

                  // =====================================================
                  // LIST VIEW
                  // =====================================================

                  return RefreshIndicator(
                    onRefresh: controller.fetchTasks,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(
                        20,
                      ),
                      itemCount: controller.tasks.length,
                      itemBuilder: (context, index) {
                        final task = controller.tasks[index];

                        return TaskCard(
                          task: task,
                          isHindi: controller.isHindi.value,
                          isHighlighted:
                              controller.highlightedIndex.value == index,
                          onComplete: () {
                            controller.completeTask(
                              index,
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
