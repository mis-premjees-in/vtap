// modules/dashboard/widgets/task_detail_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtap/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:vtap/modules/presence/controller/presence_controller.dart';
import '../../../data/models/task_model.dart';

import '../../../core/services/storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class TaskDetailSheet extends StatefulWidget {
  final TaskModel task;
  final bool isHindi;

  const TaskDetailSheet({super.key, required this.task, required this.isHindi});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  final controller = Get.find<DashboardController>();
  final presenceController = Get.put(PresenceController()); // 🔥 INJECTED

  File? _proofImage;
  bool _formOpened = false;

  void _handleButtonAction() async {
    // 1. Attendance Verification Guard Block
    debugPrint(
        "current status ${controller.currentPunchStatus.value.toString().trim().toLowerCase()}");
    if (controller.currentPunchStatus.value.toString().trim().toLowerCase() !=
        "in") {
      Get.back();
      Get.defaultDialog(
        title: widget.isHindi ? "अटेंडेंस ज़रूरी है" : "Attendance Required",
        middleText: widget.isHindi
            ? "टास्क शुरू करने के लिए पहले पंच-इन करें।"
            : "Please Punch-In before starting any task.",
        textConfirm: widget.isHindi ? "पंच-इन करें" : "Punch-In",
        confirmTextColor: Colors.white,
        buttonColor: Colors.green,
        onConfirm: () {
          Get.back();
          controller.handlePunchAction();
        },
        textCancel: widget.isHindi ? "कैंसिल" : "Cancel",
      );
      return;
    }

    // 2. CONDITION 2: Verify user position falls within dynamic database radius limit
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final String activeUsername = await StorageService.getUsername();
    
    // Check network connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty;

    bool isAllowed = true;
    if (!isOffline) {
      // Validate position coordinates directly inside the dynamic shop radius fence
      isAllowed = await presenceController.isUserWithinTaskRadius(
          activeUsername, widget.task.premiseId);
    }
    Get.back(); // Dismiss progress spinner safely

    if (!isAllowed) {
      Get.back(); // Dismiss bottom sheet workflow container
      Get.defaultDialog(
        title: widget.isHindi ? "लोकेशन एरर" : "Location Out of Range",
        middleText: widget.isHindi
            ? "Aap is task ko update nahi kar sakte kyunki aap shop ki assigned task boundary se bahar hain."
            : "You cannot complete this task because you are located outside the assigned shop footprint boundary.",
        textConfirm: "OK",
        confirmTextColor: Colors.white,
        buttonColor: Colors.redAccent,
        onConfirm: () => Get.back(),
      );
      return;
    }

    // Proceeding using your native model checklist configurations safely
    bool hasSteps = widget.task.stepList.isNotEmpty;
    bool isAnyStepTicked = widget.task.stepCheckstates.any((e) => e == true);

    if (widget.task.isUploadProofTask && _proofImage == null) {
      Get.snackbar(
        widget.isHindi ? "फोटो प्रूफ आवश्यक है" : "Photo Proof Required",
        widget.isHindi
            ? "कृपया सबमिट करने से पहले एक फोटो प्रूफ खींचें।"
            : "Please take a photo proof before submitting this task.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (widget.task.isExternalFormTask && !_formOpened) {
      Get.snackbar(
        widget.isHindi ? "फॉर्म खोलना आवश्यक है" : "Form Not Opened",
        widget.isHindi
            ? "कृपया सबमिट करने से पहले 'Open Form & Fill' दबाकर फॉर्म खोलें।"
            : "Please open the external form first to fill it.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!hasSteps) {
      _proceedToFinalSubmit();
      return;
    }

    if (!isAnyStepTicked) {
      setState(() {
        for (int i = 0; i < widget.task.stepCheckstates.length; i++) {
          widget.task.stepCheckstates[i] = true;
        }
      });
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

    _proceedToFinalSubmit();
  }

  void _proceedToFinalSubmit() {
    Get.defaultDialog(
      title: widget.isHindi ? "पुष्टि करें" : "Confirm Submission",
      middleText: widget.isHindi
          ? "क्या आप इस काम को सेव करना चाहते हैं??"
          : "Do you want to submit this task?",
      textConfirm: widget.isHindi ? "हाँ" : "Yes",
      textCancel: widget.isHindi ? "नहीं" : "No",
      confirmTextColor: Colors.white,
      buttonColor: Colors.deepOrange,
      onConfirm: () {
        Get.back();
        Get.back();
        controller.completeTask(widget.task, imageFile: _proofImage);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.isHindi ? widget.task.taskHindi : widget.task.taskEnglish,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Get.back(),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _detailTag(Icons.devices, widget.task.which),
            _detailTag(Icons.rule, widget.task.howrMethod),
            _detailTag(Icons.location_on, widget.task.where),
          ]),
          const SizedBox(height: 25),
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
          if (widget.task.isUploadProofTask) _buildPhotoProofSection(),
          if (widget.task.isExternalFormTask) _buildExternalFormSection(),
          Text(
              widget.isHindi
                  ? "प्रक्रिया के चरण (CHECKLIST)"
                  : "STEPS TO COMPLETE",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12)),
          const SizedBox(height: 10),
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
                                controller.currentPunchStatus.value.toLowerCase().trim() != "in")
                            ? null
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
          SizedBox(
            width: double.infinity,
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

  Widget _buildPhotoProofSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isHindi ? "फोटो प्रूफ (आवश्यक)" : "PHOTO PROOF (REQUIRED)",
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12),
        ),
        const SizedBox(height: 10),
        _proofImage == null
            ? InkWell(
                onTap: () async {
                  final file = await controller.pickImage();
                  if (file != null) {
                    setState(() {
                      _proofImage = file;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.camera_alt_rounded,
                          size: 36, color: Colors.deepOrange),
                      const SizedBox(height: 8),
                      Text(
                        widget.isHindi
                            ? "फोटो लेने के लिए यहाँ टैप करें"
                            : "Tap here to take Photo Proof",
                        style: TextStyle(
                          color: Colors.deepOrange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isHindi
                            ? "कैमरा से लाइव इमेज कैप्चर करें"
                            : "Capture a live image from your camera",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.file(
                        _proofImage!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _proofImage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black45,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.isHindi ? "इमेज सिलेक्टेड" : "Image Captured",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final file = await controller.pickImage();
                                  if (file != null) {
                                    setState(() {
                                      _proofImage = file;
                                    });
                                  }
                                },
                                child: Text(
                                  widget.isHindi ? "बदलें (Retake)" : "Retake Photo",
                                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildExternalFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isHindi ? "एक्सटर्नल फॉर्म (आवश्यक)" : "EXTERNAL FORM (REQUIRED)",
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description_rounded, color: Colors.blue.shade800, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isHindi ? "फॉर्म सबमिशन" : "Form Submission",
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isHindi
                              ? "इस टास्क को पूरा करने के लिए नीचे दिए गए फॉर्म को भरें।"
                              : "Fill out the linked web form in the browser to complete this task.",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 18),
                  label: Text(
                    widget.isHindi ? "फॉर्म खोलें और भरें" : "Open Form & Fill",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  onPressed: () async {
                    setState(() {
                      _formOpened = true;
                    });
                    await launchUrl(Uri.parse(widget.task.howrUrl.trim()),
                        mode: LaunchMode.inAppBrowserView);
                  },
                ),
              ),
              if (_formOpened) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.isHindi
                            ? "लिंक खोला जा चुका है। फॉर्म भरने के बाद सबमिट करें।"
                            : "Link opened. Complete form, then submit below.",
                        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  String _getButtonText(bool hasSteps, bool isAnyStepTicked) {
    if (widget.task.isCompleted)
      return widget.isHindi ? "पूरा हुआ" : "COMPLETED";
    if (!hasSteps) return widget.isHindi ? "टास्क जमा करें" : "SUBMIT TASK";
    if (!isAnyStepTicked)
      return widget.isHindi ? "सभी टिक करें" : "TICK ALL STEPS";
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
