import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/storage_service.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../admin/views/background_logs_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardController = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          dashboardController.isHindi.value ? "प्रोफ़ाइल" : "My Profile",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _loadUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            );
          }

          final data = snapshot.data ?? {};
          final username = data['username'] ?? "N/A";
          final userId = data['userId'] ?? "N/A";
          final email = data['email'] ?? "N/A";
          final whosId = data['whosId'] ?? "N/A";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Premium Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepOrange, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrange.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(
                            Icons.person_rounded,
                            size: 55,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.isNotEmpty ? email : "VTAP Team Member",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Info Section
                _buildSectionHeader(
                  dashboardController.isHindi.value
                      ? "खाता जानकारी"
                      : "Account Details",
                ),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow(
                    Icons.fingerprint_rounded,
                    dashboardController.isHindi.value ? "यूज़र आईडी" : "User ID",
                    userId,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.badge_rounded,
                    dashboardController.isHindi.value ? "डब्ल्यूएचओ आईडी" : "Whos ID",
                    whosId,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.security_rounded,
                    dashboardController.isHindi.value ? "ड्यूटी स्टेटस" : "Shift Status",
                    dashboardController.currentPunchStatus.value.toUpperCase(),
                    valueColor: dashboardController.currentPunchStatus.value.toLowerCase() == 'in'
                        ? Colors.green
                        : Colors.red,
                  ),
                ]),

                const SizedBox(height: 24),

                // Actions Section
                _buildSectionHeader(
                  dashboardController.isHindi.value
                      ? "सेटिंग्स और टूल्स"
                      : "Settings & Tools",
                ),
                const SizedBox(height: 12),
                _buildInfoCard([
                  ListTile(
                    leading: const Icon(Icons.translate, color: Colors.deepOrange),
                    title: Text(
                      dashboardController.isHindi.value ? "भाषा बदलें" : "Language",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      dashboardController.isHindi.value ? "हिंदी सक्रिय" : "English Active",
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      dashboardController.toggleLanguage();
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.deepOrange),
                    title: Text(
                      dashboardController.isHindi.value ? "बैकग्राउंड सर्विस लॉग्स" : "Background Service Logs",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      dashboardController.isHindi.value ? "डायग्नोस्टिक लॉग विवरण देखें" : "View diagnostic log details",
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Get.to(() => const BackgroundLogsView());
                    },
                  ),
                  // _buildDivider(),
                  // ListTile(
                  //   leading: const Icon(Icons.calendar_month_rounded, color: Colors.deepOrange),
                  //   title: Text(
                  //     dashboardController.isHindi.value ? "गूगल कैलेंडर सिंक" : "Sync with Google Calendar",
                  //     style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  //   ),
                  //   subtitle: Text(
                  //     dashboardController.isHindi.value ? "कैलेंडर में टास्क रिमाइंडर्स जोड़ें" : "Sync active tasks to your calendar",
                  //     style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                  //   ),
                  //   trailing: Obx(() => dashboardController.isSyncingCalendar.value
                  //       ? const SizedBox(
                  //           width: 16,
                  //           height: 16,
                  //           child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange),
                  //         )
                  //       : const Icon(Icons.arrow_forward_ios_rounded, size: 16)),
                  //   onTap: () {
                  //     dashboardController.syncTasksToGoogleCalendar();
                  //   },
                  // ),
                  _buildDivider(),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: Text(
                      dashboardController.isHindi.value ? "लॉगआउट" : "Logout",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    subtitle: Text(
                      dashboardController.isHindi.value
                          ? "सुरक्षित रूप से बाहर निकलें"
                          : "Exit session securely",
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      _showLogoutDialog(context, dashboardController);
                    },
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, String>> _loadUserData() async {
    final username = await StorageService.getUsername();
    final userId = await StorageService.getUserId();
    final whosId = await StorageService.getWhosId();
    String email = await StorageService.getGoogleEmail();

    return {
      'username': username,
      'userId': userId,
      'whosId': whosId,
      'email': email,
    };
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: valueColor ?? Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 20,
      endIndent: 20,
    );
  }

  void _showLogoutDialog(BuildContext context, DashboardController controller) {
    Get.defaultDialog(
      title: controller.isHindi.value ? "लॉगआउट" : "Logout",
      middleText: controller.isHindi.value
          ? "क्या आप बाहर निकलना चाहते हैं?"
          : "Do you want to logout?",
      textConfirm: controller.isHindi.value ? "हाँ" : "Yes",
      textCancel: controller.isHindi.value ? "नहीं" : "No",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        Get.back();
        controller.logoutUser();
      },
    );
  }
}
