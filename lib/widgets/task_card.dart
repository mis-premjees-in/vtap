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
      duration: const Duration(
        milliseconds: 350,
      ),
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  Colors.orange.shade100,
                  Colors.deepOrange.shade50,
                ],
              )
            : const LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white,
                ],
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlighted
              ? Colors.deepOrange.withOpacity(0.3)
              : Colors.grey.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // TITLE
          // =====================================================

          Text(
            isHindi
                ? (task.taskHindi.isEmpty ? task.taskEnglish : task.taskHindi)
                : task.taskEnglish,
            style: TextStyle(
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.bold,
              decoration: task.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: task.isCompleted ? Colors.grey : Colors.black87,
            ),
          ),

          const SizedBox(height: 15),

          // =====================================================
          // TAGS
          // =====================================================

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                Icons.schedule,
                task.taskTime.isEmpty ? "No Time" : task.taskTime,
              ),
              if (task.location.isNotEmpty)
                _tag(
                  Icons.location_on,
                  task.location,
                ),
              if (task.howrType.isNotEmpty)
                _tag(
                  Icons.assignment,
                  task.howrType,
                ),
              _tag(
                task.isCompleted ? Icons.check_circle : Icons.pending_actions,
                task.isCompleted ? "Completed" : "Pending",
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =====================================================
          // METHOD BADGE
          // =====================================================

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange,
                      Colors.orange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  task.howrMethod.isEmpty
                      ? "NORMAL"
                      : task.howrMethod.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // =====================================================
          // COMPLETE BUTTON
          // =====================================================

          task.isCompleted
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.green.shade200,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "✅ Task Completed",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(
                      Icons.check_circle,
                    ),
                    label: const Text(
                      "COMPLETE TASK",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          18,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // =====================================================
  // TAG
  // =====================================================

  Widget _tag(
    IconData icon,
    String text,
  ) {
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
            size: 15,
            color: Colors.deepOrange,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
