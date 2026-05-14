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
    final remarksController = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7EF),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFFB74D)]),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Namaste 🙏",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                          Text("Work Mode On!",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        onPressed: () => controller.fetchTasks(),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Obx(() => _buildStatCard(
                            title: "Pending",
                            value: controller.tasks
                                .where((t) => !t.isCompleted)
                                .length
                                .toString(),
                            icon: Icons.pending_actions,
                          )),
                      Obx(() => _buildStatCard(
                            title: "Done",
                            value: controller.tasks
                                .where((t) => t.isCompleted)
                                .length
                                .toString(),
                            icon: Icons.task_alt,
                          )),
                      GestureDetector(
                        onTap: () => controller.isHindi.value =
                            !controller.isHindi.value,
                        child: Obx(() => _buildStatCard(
                              title: "Language",
                              value: controller.isHindi.value ? "HI" : "EN",
                              icon: Icons.translate,
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Attendance Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Obx(() => controller.isPunching.value
                  ? const LinearProgressIndicator()
                  : Row(
                      children: [
                        Expanded(
                          child: PunchSliderSmall(
                            label: "In",
                            color: Colors.green,
                            icon: Icons.login,
                            onAction: () => controller.handlePunchAction("In"),
                            direction: SlideDirection.right,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: PunchSliderSmall(
                            label: "Out",
                            color: Colors.red,
                            icon: Icons.logout,
                            onAction: () => controller.handlePunchAction("Out"),
                            direction: SlideDirection.left,
                          ),
                        ),
                      ],
                    )),
            ),

            // Tasks Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Your Tasks",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Obx(() => IconButton(
                        onPressed: () => controller.isCarousel.value =
                            !controller.isCarousel.value,
                        icon: Icon(
                            controller.isCarousel.value
                                ? Icons.view_list
                                : Icons.view_carousel,
                            color: AppColors.primary),
                      )),
                ],
              ),
            ),

            Expanded(
              child: Obx(() {
                if (controller.isLoading.value)
                  return const Center(child: CircularProgressIndicator());
                if (controller.tasks.isEmpty)
                  return const Center(child: Text("No tasks found."));

                if (controller.isCarousel.value) {
                  return PageView.builder(
                    itemCount: controller.tasks.length,
                    controller: PageController(viewportFraction: 0.85),
                    itemBuilder: (context, index) {
                      return TaskCarouselCard(
                        task: controller.tasks[index],
                        isHindi: controller.isHindi.value,
                        remarksController: remarksController,
                        image: null,
                        onUpload: () {},
                        onComplete: () => controller.completeTask(index),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: controller.tasks.length,
                  itemBuilder: (context, index) {
                    return TaskCard(
                      task: controller.tasks[index],
                      isHindi: controller.isHindi.value,
                      isHighlighted: controller.highlightedIndex.value == index,
                      onComplete: () => controller.completeTask(index),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      {required String title, required String value, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(title,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

enum SlideDirection { left, right }

class PunchSliderSmall extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onAction;
  final SlideDirection direction;

  const PunchSliderSmall(
      {super.key,
      required this.label,
      required this.color,
      required this.icon,
      required this.onAction,
      required this.direction});

  @override
  State<PunchSliderSmall> createState() => _PunchSliderSmallState();
}

class _PunchSliderSmallState extends State<PunchSliderSmall> {
  double _dragValue = 0.0;
  final double _maxWidth = 100.0;

  @override
  Widget build(BuildContext context) {
    bool isRight = widget.direction == SlideDirection.right;
    return Container(
      height: 55,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Stack(
        children: [
          Center(
              child: Text(widget.label,
                  style: TextStyle(
                      color: widget.color, fontWeight: FontWeight.bold))),
          Positioned(
            left: isRight ? _dragValue : null,
            right: !isRight ? _dragValue : null,
            top: 4,
            bottom: 4,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) => setState(() => _dragValue =
                  (_dragValue +
                          (isRight ? details.delta.dx : -details.delta.dx))
                      .clamp(0, _maxWidth)),
              onHorizontalDragEnd: (details) {
                if (_dragValue >= _maxWidth * 0.7) widget.onAction();
                setState(() => _dragValue = 0);
              },
              child: Container(
                width: 47,
                decoration:
                    BoxDecoration(color: widget.color, shape: BoxShape.circle),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
