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

  // Logic to handle button click
  void _handleButtonAction() {
    // --- ADD THIS GUARD CLAUSE ---
    if (controller.currentPunchStatus.value != "in") {
      Get.back(); // Sheet band karein
      Get.defaultDialog(
        title: widget.isHindi ? "अटेंडेंस ज़रूरी है" : "Attendance Required",
        middleText: widget.isHindi
            ? "टास्क शुरू करने के लिए पहले पंच-इन करें।"
            : "Please Punch-In before starting any task.",
        textConfirm: widget.isHindi ? "पंच-इन करें" : "Punch-In",
        confirmTextColor: Colors.white,
        buttonColor: Colors.green,
        onConfirm: () {
          Get.back(); // Dialog band karein
          controller.handlePunchAction(); // Dashboard ka punch trigger karein
        },
        textCancel: widget.isHindi ? "कैंसिल" : "Cancel",
      );
      return;
    }
    bool hasSteps = widget.task.stepList.isNotEmpty;
    bool isAnyStepTicked = widget.task.stepCheckstates.any((e) => e == true);

    // CASE 1: No steps involved
    if (!hasSteps) {
      _proceedToFinalSubmit();
      return;
    }

    // CASE 2: Steps exist but NOTHING is ticked yet (Auto-Tick Mode)
    if (!isAnyStepTicked) {
      setState(() {
        for (int i = 0; i < widget.task.stepCheckstates.length; i++) {
          widget.task.stepCheckstates[i] = true;
        }
      });
      // Sirf UI update hoga, save nahi. User ab untick kar sakta hai.
      Get.snackbar(
        widget.isHindi ? "सभी स्टेप्स टिक हुए" : "All steps ticked",
        widget.isHindi
            ? "आप मैन्युअली बदलाव कर सकते हैं, फिर सबमिट दबाएं"
            : "You can manually untick now, then press submit again.",
        backgroundColor: Colors.blueGrey.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // CASE 3: Steps exist and user has selected some/all (Final Save Mode)
    _proceedToFinalSubmit();
  }

  void _proceedToFinalSubmit() {
    Get.defaultDialog(
      title: widget.isHindi ? "पुष्टि करें" : "Confirm Submission",
      middleText: widget.isHindi
          ? "क्या आप इस टास्क को ${widget.task.score.toStringAsFixed(0)}% स्कोर के साथ जमा करना चाहते हैं?"
          : "Do you want to submit this task with ${widget.task.score.toStringAsFixed(0)}% score?",
      textConfirm: widget.isHindi ? "हाँ" : "Yes",
      textCancel: widget.isHindi ? "नहीं" : "No",
      confirmTextColor: Colors.white,
      buttonColor: Colors.deepOrange,
      onConfirm: () {
        Get.back(); // Dialog band karein
        Get.back(); // Sheet band karein
        controller.completeTask(widget.task);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAnyStepTicked = widget.task.stepCheckstates.any((e) => e == true);
    bool hasSteps = widget.task.stepList.isNotEmpty;

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
          Wrap(spacing: 8, runSpacing: 8, children: [
            _detailTag(Icons.devices, widget.task.which),
            _detailTag(Icons.rule, widget.task.howrMethod),
            _detailTag(Icons.location_on, widget.task.where),
          ]),
          const SizedBox(height: 25),

          // Quality Score Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepOrange.withOpacity(0.15))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    widget.isHindi
                        ? "टास्क स्कोर (Accuracy):"
                        : "Task Quality Score:",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text("${widget.task.score.toStringAsFixed(0)}%",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.deepOrange)),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text(
              widget.isHindi
                  ? "प्रक्रिया के चरण (CHECKLIST)"
                  : "STEPS TO COMPLETE",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12)),
          const SizedBox(height: 10),

          // Checklist Builder
          Flexible(
            child: !hasSteps
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text(
                            widget.isHindi
                                ? "कोई अतिरिक्त चरण नहीं हैं"
                                : "No steps required.",
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: widget.task.stepList.length,
                    itemBuilder: (context, index) {
                      return CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: Text(widget.task.stepList[index],
                            style: TextStyle(
                                fontSize: 14,
                                decoration: widget.task.stepCheckstates[index]
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: widget.task.stepCheckstates[index]
                                    ? Colors.grey
                                    : Colors.black87)),
                        value: widget.task.stepCheckstates[index],
                        activeColor: Colors.deepOrange,
                        onChanged: (widget.task.isCompleted ||
                                controller.currentPunchStatus.value != "in")
                            ? null // Disable checkbox if completed OR if punched out
                            : (val) {
                                setState(() {
                                  widget.task.stepCheckstates[index] = val!;
                                });
                              },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 30),

          // Main Dynamic Button
          SizedBox(
            width: MediaQuery.of(context).size.height,
            child: ElevatedButton(
              onPressed:
                  widget.task.isCompleted ? null : () => _handleButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    widget.task.isCompleted ? Colors.grey : Colors.deepOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 5,
              ),
              child: Text(
                _getButtonText(hasSteps, isAnyStepTicked),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Dynamic Button Text Logic
  String _getButtonText(bool hasSteps, bool isAnyStepTicked) {
    if (widget.task.isCompleted) {
      return widget.isHindi ? "पूरा हुआ" : "COMPLETED";
    }
    if (!hasSteps) return widget.isHindi ? "टास्क जमा करें" : "SUBMIT TASK";
    if (!isAnyStepTicked) {
      return widget.isHindi ? "सभी टिक करें" : "TICK ALL STEPS";
    }
    return widget.isHindi ? "फाइनल सबमिट करें" : "FINAL SUBMIT";
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
