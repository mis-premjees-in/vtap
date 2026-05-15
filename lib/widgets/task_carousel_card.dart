import 'package:flutter/material.dart';
import '../data/models/task_model.dart';

class TaskCarouselCard extends StatelessWidget {
  final TaskModel task;
  final bool isHindi;
  final VoidCallback onComplete;

  const TaskCarouselCard({
    super.key,
    required this.task,
    required this.isHindi,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 20,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: task.isCompleted
              ? [
                  Colors.green.shade400,
                  Colors.green.shade700,
                ]
              : [
                  Colors.orange.shade400,
                  Colors.deepOrange,
                ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  "${task.howrMethod} ${task.howrType}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                task.isCompleted ? Icons.check_circle : Icons.pending,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),

          const Spacer(),

          // TITLE
          Text(
            isHindi ? task.taskHindi : task.taskEnglish,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // TAGS
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              _buildTag(
                Icons.schedule,
                "${task.taskTime} ${task.taskTimeType}",
              ),
              _buildTag(
                Icons.location_on,
                "${task.location} • ${task.locationType}",
              ),
              _buildTag(
                Icons.person,
                task.assignedTo,
              ),
            ],
          ),

          const SizedBox(height: 30),

          // BUTTON
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: task.isCompleted ? null : onComplete,
              icon: Icon(
                task.isCompleted ? Icons.check : Icons.swipe,
              ),
              label: Text(
                task.isCompleted ? "Completed" : "Slide to Complete",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
