import 'package:flutter/material.dart';

import '../data/models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isHindi;
  final bool isHighlighted;
  final bool isCompleting;
  final VoidCallback onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.isHindi,
    required this.isHighlighted,
    required this.isCompleting,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlighted ? Colors.deepOrange : Colors.grey.shade200,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // TITLE
          // =====================================================

          Row(
            children: [
              Expanded(
                child: Text(
                  isHindi ? task.taskHindi : task.taskEnglish,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.bold,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (isHighlighted && !task.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isHindi ? "अब" : "NOW",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 15),

          // =====================================================
          // TAGS
          // =====================================================

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(Icons.place, task.where),
              _tag(Icons.devices, task.which),
              _tag(
                Icons.access_time,
                "${task.whenSession} ${task.whenTime}",
              ),
              _tag(Icons.person, task.who),
              _tag(Icons.rule, task.howrMethod),
              _tag(
                task.isCompleted ? Icons.check_circle : Icons.pending,
                task.isCompleted
                    ? (isHindi ? "पूरा" : "Completed")
                    : (isHindi ? "बाकी" : "Pending"),
              ),
            ],
          ),

          // =====================================================
          // STEPS
          // =====================================================

          if (task.hows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                task.hows,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // =====================================================
          // BUTTON
          // =====================================================

          task.isCompleted
              ? _completedView()
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isCompleting ? null : onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      disabledBackgroundColor: Colors.orange.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isCompleting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isHindi ? "टास्क पूरा करें" : "COMPLETE TASK",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
        ],
      ),
    );
  }

  // =====================================================
  // COMPLETED VIEW
  // =====================================================

  Widget _completedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          isHindi ? "✅ टास्क पूरा हो गया" : "✅ Completed",
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            style: const TextStyle(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
