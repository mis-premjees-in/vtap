import 'dart:io';

import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/models/task_model.dart';

class TaskCarouselCard extends StatelessWidget {
  final TaskModel task;

  final bool isHindi;

  final TextEditingController remarksController;

  final File? image;

  final VoidCallback onUpload;

  final VoidCallback onComplete;

  const TaskCarouselCard({
    super.key,
    required this.task,
    required this.isHindi,
    required this.remarksController,
    required this.image,
    required this.onUpload,
    required this.onComplete,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 20,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          30,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.deepOrange.shade300,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isHindi ? task.taskHindi : task.taskEnglish,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            task.taskTime,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: task.isCompleted ? null : onComplete,
            icon: Icon(
              task.isCompleted ? Icons.check : Icons.done,
            ),
            label: Text(
              task.isCompleted ? "Completed" : "Complete",
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// INFO ROW
// =====================================================

Widget _infoRow({
  required IconData icon,
  required String title,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
      const SizedBox(width: 8),
      Text(
        "$title: ",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}
