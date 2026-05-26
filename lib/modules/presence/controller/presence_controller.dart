// modules/dashboard/controllers/presence_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/storage_service.dart';

class PresenceController extends GetxController {
  final ApiService _api = ApiService();

  RxBool isLoading = false.obs;
  RxString lastStatus = "out".obs;

  // =====================================================
  // FETCH CURRENT STATUS
  // =====================================================
  Future<void> fetchStatus(String username) async {
    try {
      isLoading.value = true;
      String status = await _api.getLastPunchStatus(username: username);
      lastStatus.value = status.toLowerCase();
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to fetch attendance status",
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =====================================================
  // HANDLE PUNCH IN / OUT
  // =====================================================

  Future<void> handlePunchToggle(String username) async {
    await fetchStatus(username);
    try {
      isLoading.value = true;
      String nextType = lastStatus.value == "in"
          ? "Out"
          : "In"; // FIXED: Capitalized to match PHP payload tracking zone standard

      // GET PREMISES
      List premises = await _api.getPremises(username: username);

      if (premises.isEmpty) {
        Get.snackbar(
          "Error",
          "No premises configured",
        );
        return;
      }

      // LOCATION VALIDATION
      final matchedPremise = await LocationService.getMatchedPremise(premises);

      if (matchedPremise == null) {
        Get.defaultDialog(
          title: "📍 Outside Premise",
          middleText: "Pehle valid shop/location pe aajao 😅",
          textConfirm: "OK",
          confirmTextColor: Colors.white,
          onConfirm: () => Get.back(),
        );
        return;
      }

      final whosId = await StorageService.getWhosId();
      final secureToken = await StorageService
          .getToken(); // FIXED: Added missing local storage token extraction

      // SUBMIT PUNCH
      bool success = await _api.submitPunch(
        username: username,
        accessToken:
            secureToken, // FIXED: Injected required accessToken inside parameter map map
        type: nextType,
        premiseId: matchedPremise['premises_id'].toString(),
        whosId: whosId,
      );

      if (success) {
        lastStatus.value = nextType.toLowerCase();
        await StorageService.saveAttendance(
          status: nextType.toLowerCase(),
          premiseName: matchedPremise['premises_name'].toString(),
        );

        Get.snackbar(
          nextType.toLowerCase() == "in"
              ? "🎉 Punch In Success"
              : "🚀 Punch Out Success",
          nextType.toLowerCase() == "in"
              ? "Swagat hai champion 😎"
              : "Aaj ka kaam khatam 🔥",
          backgroundColor:
              nextType.toLowerCase() == "in" ? Colors.green : Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          "Error",
          "Punch failed",
        );
      }
    } catch (e) {
      print("PUNCH ERROR => $e");
      Get.snackbar(
        "Error",
        e.toString(),
      );
    } finally {
      isLoading.value = false;
    }
  }
}

// =====================================================
// PRESENCE PAGE
// =====================================================
class PresenceBeingPage extends StatelessWidget {
  final String username;

  PresenceBeingPage({
    super.key,
    required this.username,
  });

  final PresenceController controller = Get.put(PresenceController());

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchStatus(username);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(
              () => AnimatedSwitcher(
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
              ),
            ),
            const SizedBox(height: 20),
            Obx(
              () => Text(
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
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Slide below to change attendance",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 80),
            Obx(
              () => controller.isLoading.value
                  ? const CircularProgressIndicator()
                  : SmartPunchSlider(
                      isCurrentlyIn: controller.lastStatus.value == "in",
                      onAction: () {
                        controller.handlePunchToggle(username);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// SMART SLIDER
// =====================================================
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
        border: Border.all(
          color: themeColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
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
                setState(() {
                  _dragValue = 0.0;
                });
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
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
