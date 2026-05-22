import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/task_model.dart';
import '../modules/dashboard/controllers/dashboard_controller.dart';

class TaskDetailSheet extends StatefulWidget {
  final TaskModel task;
  final bool isHindi;

  const TaskDetailSheet({super.key, required this.task, required this.isHindi});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  final controller = Get.find<DashboardController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text(widget.isHindi ? widget.task.taskHindi : widget.task.taskEnglish,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // Necessary Tags
          Wrap(spacing: 8, runSpacing: 8, children: [
            _detailTag(Icons.person, widget.task.who),
            _detailTag(Icons.devices, widget.task.which),
            _detailTag(Icons.rule, widget.task.howrMethod),
          ]),

          const SizedBox(height: 25),
          const Text("STEPS TO COMPLETE",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),

          // Steps with Checkboxes
          ...List.generate(widget.task.stepList.length, (index) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.task.stepList[index],
                  style: const TextStyle(fontSize: 14)),
              value: widget.task.stepCheckstates[index],
              activeColor: Colors.deepOrange,
              onChanged: widget.task.isCompleted
                  ? null
                  : (val) {
                      setState(() {
                        widget.task.stepCheckstates[index] = val!;
                        // Logic: If all steps checked, trigger completion
                        if (widget.task.stepCheckstates.every((e) => e)) {
                          Get.back();
                          controller.completeTask(widget.task);
                        }
                      });
                    },
            );
          }),

          const SizedBox(height: 30),

          // Enhanced Complete Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: widget.task.isCompleted
                  ? null
                  : () {
                      Get.back();
                      controller.completeTask(widget.task);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                shadowColor: Colors.deepOrange.withOpacity(0.4),
              ),
              child: Text(widget.isHindi ? "टास्क पूरा करें" : "COMPLETE TASK",
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _detailTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.deepOrange),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
