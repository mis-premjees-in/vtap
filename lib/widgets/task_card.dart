import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
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
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.orange.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlighted ? Colors.orange : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? task.taskHindi : task.taskEnglish,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  "Time: ${task.taskTime}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: task.isCompleted,
            activeColor: AppColors.primary,
            onChanged: (_) => onComplete(),
          ),
        ],
      ),
    );
  }
}
