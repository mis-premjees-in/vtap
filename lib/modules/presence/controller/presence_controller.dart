import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';

class PresenceController extends GetxController {
  final ApiService _api = ApiService();
  var isLoading = false.obs;
  var lastStatus = "out".obs; // Current state: "in" or "out"

  Future<void> fetchStatus(String username) async {
    isLoading.value = true;
    try {
      String status = await _api.getLastPunchStatus(username: username);
      lastStatus.value = status;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> handlePunchToggle(String username) async {
    isLoading.value = true;
    try {
      // Logic: If currently "in", next action is "out". If "out", next is "in".
      String nextType = lastStatus.value == "in" ? "out" : "in";

      // 1. Get valid premises
      List premises = await _api.getPremises(username: username);
      if (premises.isEmpty) {
        Get.snackbar("Error", "No premises configured.");
        return;
      }

      // 2. Validate location
      bool isWithinPremise =
          await LocationService.validateUserInPremise(premises);

      if (isWithinPremise) {
        // 3. Submit Punch (No lat/lng sent as requested previously)
        bool success = await _api.submitPunch(
          username: username,
          type: nextType,
        );

        if (success) {
          lastStatus.value = nextType; // Flip the state
          Get.snackbar(
            "Success",
            "Successfully punched ${nextType.toUpperCase()}",
            backgroundColor: Colors.green.withOpacity(0.1),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        Get.defaultDialog(
          title: "Access Denied",
          middleText:
              "You must be within a permitted premise to punch ${nextType.toUpperCase()}.",
          textConfirm: "OK",
          onConfirm: () => Get.back(),
        );
      }
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

class PresenceBeingPage extends StatelessWidget {
  final String username;
  PresenceBeingPage({super.key, required this.username});

  final controller = Get.put(PresenceController());

  @override
  Widget build(BuildContext context) {
    controller.fetchStatus(username);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance"),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Icon with Animation
            Obx(() => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Icon(
                    controller.lastStatus.value == "in"
                        ? Icons.door_front_door
                        : Icons.location_off,
                    key: ValueKey(controller.lastStatus.value),
                    size: 100,
                    color: controller.lastStatus.value == "in"
                        ? Colors.green
                        : Colors.grey,
                  ),
                )),
            const SizedBox(height: 20),
            // Current Status Text
            Obx(() => Text(
                  controller.lastStatus.value == "in"
                      ? "Punched IN"
                      : "Punched OUT",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: controller.lastStatus.value == "in"
                        ? Colors.green[700]
                        : Colors.grey[700],
                  ),
                )),
            const SizedBox(height: 10),
            const Text(
              "Slide the button below to change status",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 80),
            // Unified Single Toggle Slider
            Obx(() => controller.isLoading.value
                ? const CircularProgressIndicator()
                : SmartPunchSlider(
                    isCurrentlyIn: controller.lastStatus.value == "in",
                    onAction: () => controller.handlePunchToggle(username),
                  )),
          ],
        ),
      ),
    );
  }
}

class SmartPunchSlider extends StatefulWidget {
  final bool isCurrentlyIn;
  final VoidCallback onAction;

  const SmartPunchSlider({
    super.key,
    required this.isCurrentlyIn,
    required this.onAction,
  });

  @override
  State<SmartPunchSlider> createState() => _SmartPunchSliderState();
}

class _SmartPunchSliderState extends State<SmartPunchSlider> {
  double _dragValue = 0.0;
  static const double _maxDrag = 240.0;

  @override
  Widget build(BuildContext context) {
    // Dynamic appearance based on current status
    final Color themeColor = widget.isCurrentlyIn ? Colors.red : Colors.green;
    final String label =
        widget.isCurrentlyIn ? "SLIDE TO PUNCH OUT" : "SLIDE TO PUNCH IN";
    final IconData icon = widget.isCurrentlyIn ? Icons.logout : Icons.login;

    return Container(
      width: _maxDrag + 70,
      height: 80,
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
      ),
      child: Stack(
        children: [
          // Centered Guidance Text
          Center(
            child: Opacity(
              opacity: (1.0 - (_dragValue / _maxDrag)).clamp(0.2, 1.0),
              child: Text(
                label,
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          // Draggable Handle
          Positioned(
            left: _dragValue + 5,
            top: 5,
            bottom: 5,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragValue += details.delta.dx;
                  _dragValue = _dragValue.clamp(0.0, _maxDrag);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragValue >= _maxDrag * 0.85) {
                  widget.onAction();
                }
                setState(() => _dragValue = 0.0);
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
