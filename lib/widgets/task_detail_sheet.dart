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

          // Core Tags Row (Who tag removed)
          Wrap(spacing: 8, runSpacing: 8, children: [
            _detailTag(Icons.devices, widget.task.which),
            _detailTag(Icons.rule, widget.task.howrMethod),
            _detailTag(Icons.location_on, widget.task.where),
          ]),

          const SizedBox(height: 20),

          // Score Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.15))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isHindi
                      ? "टास्क स्कोर accuracy:"
                      : "Task Quality Score:",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  "${widget.task.score.toStringAsFixed(0)}%",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.deepOrange),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
              widget.isHindi ? "प्रक्रिया के चरण (STEPS)" : "STEPS TO COMPLETE",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),

          // Checklist Logic
          Flexible(
            child: widget.task.stepList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("No steps found in DB",
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 12)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: widget.task.stepList.length,
                    itemBuilder: (context, index) {
                      return CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        visualDensity:
                            const VisualDensity(horizontal: -4, vertical: -4),
                        title: Text(widget.task.stepList[index],
                            style: const TextStyle(fontSize: 14)),
                        value: widget.task.stepCheckstates[index],
                        activeColor: Colors.deepOrange,
                        onChanged: widget.task.isCompleted
                            ? null // Locked if task is done
                            : (val) {
                                setState(() {
                                  widget.task.stepCheckstates[index] = val!;
                                });
                              },
                      );
                    },
                  ),
          ),

          const SizedBox(height: 24),

          // Submit Button (Locked if isCompleted is true)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: widget.task.isCompleted
                  ? null // Button disabled
                  : () {
                      // If user clicks without ticks, auto-tick all
                      if (widget.task.stepCheckstates.every((e) => !e)) {
                        for (int i = 0;
                            i < widget.task.stepCheckstates.length;
                            i++) {
                          widget.task.stepCheckstates[i] = true;
                        }
                      }
                      Get.back();
                      controller.completeTask(widget.task);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    widget.task.isCompleted ? Colors.grey : Colors.deepOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 8,
              ),
              child: Text(
                  widget.task.isCompleted
                      ? (widget.isHindi
                          ? "टास्क सबमिट हो चुका है"
                          : "ALREADY SUBMITTED")
                      : (widget.isHindi
                          ? "टास्क सबमिट करें"
                          : "SUBMIT COMPLETED TASK"),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
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
