import 'package:flutter/material.dart';
import '../data/models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isHindi;
  final bool isHighlighted;
  final VoidCallback onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.isHindi,
    required this.isHighlighted,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHighlighted ? Colors.deepOrange : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHindi ? task.taskHindi : task.taskEnglish,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(Icons.place, task.where),
              _tag(Icons.devices, task.which),
              _tag(Icons.access_time, "${task.whenSession} ${task.whenTime}"),
              _tag(Icons.person, task.who),
              _tag(Icons.rule, task.howrMethod),
              _tag(
                task.isCompleted ? Icons.check_circle : Icons.pending,
                task.isCompleted ? "Completed" : "Pending",
              ),
            ],
          ),
          const SizedBox(height: 18),
          task.isCompleted
              ? _completedView()
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                    child: const Text(
                      "COMPLETE TASK",
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _completedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          "✅ Completed",
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    if (text.trim().isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.deepOrange,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
