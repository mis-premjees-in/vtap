// widgets/task_card.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/services/offline_queue_service.dart';
import '../data/models/task_model.dart';
import 'task_detail_sheet.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isHindi;
  final bool isHighlighted;

  const TaskCard({
    super.key,
    required this.task,
    required this.isHindi,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPendingSync = Get.find<OfflineQueueService>().isTaskPendingSync(task.id);

    return GestureDetector(
      onTap: () => Get.bottomSheet(
        TaskDetailSheet(task: task, isHindi: isHindi),
        isScrollControlled: true,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isHighlighted && !task.isCompleted
                ? Colors.deepOrange
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? Colors.deepOrange.withOpacity(0.1)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            _buildStatusIcon(isPendingSync),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi ? task.taskHindi : task.taskEnglish,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _miniTag(Icons.access_time, task.whenTime, Colors.blue),
                      const SizedBox(width: 10),
                      _miniTag(Icons.location_on_outlined,
                          task.where.split(' ').first, Colors.orange),
                      if (isPendingSync) ...[
                        const SizedBox(width: 10),
                        _miniTag(Icons.cloud_upload_outlined,
                            isHindi ? "सिंक बाकी" : "Pending Sync", Colors.amber.shade800),
                      ],
                    ],
                  )
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isPendingSync) {
    if (isPendingSync) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          Icons.cloud_upload_rounded,
          color: Colors.amber.shade800,
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: task.isCompleted
            ? Colors.green.withOpacity(0.1)
            : Colors.deepOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        task.isCompleted
            ? Icons.check_circle_rounded
            : Icons.pending_actions_rounded,
        color: task.isCompleted ? Colors.green : Colors.deepOrange,
      ),
    );
  }

  Widget _miniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
