import 'package:flutter/material.dart';
import '../data/models/task_model.dart';

class FloatingTaskPopup extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onComplete;
  final bool isHindi;

  const FloatingTaskPopup({
    super.key,
    required this.task,
    required this.onComplete,
    required this.isHindi,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    isHindi ? "टास्क रिमाइंडर" : "Task Reminder",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isHindi ? task.taskHindi : task.taskEnglish,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "${task.whenSession} • ${task.whenTime}",
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                  ),
                  child: Text(
                    isHindi ? "टास्क पूरा करें" : "COMPLETE TASK",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
