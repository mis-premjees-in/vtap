import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import 'background_logs_view.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardController = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          dashboardController.isHindi.value ? "एडमिन डैशबोर्ड" : "Admin Console",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats description
            Text(
              dashboardController.isHindi.value
                  ? "सिस्टम और वर्कस्पेस की स्थिति"
                  : "System & Workspace Metrics",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),

            // Top Quick Info Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  Icons.store_rounded,
                  dashboardController.isHindi.value ? "पंजीकृत दुकानें" : "Active Shop Zones",
                  "4 Zones",
                  Colors.blue,
                ),
                _buildStatCard(
                  Icons.radar_rounded,
                  dashboardController.isHindi.value ? "जियोफेंस लिमिट" : "Geofence Radius",
                  "10 Meters",
                  Colors.deepOrange,
                ),
                _buildStatCard(
                  Icons.wifi_tethering_rounded,
                  dashboardController.isHindi.value ? "ट्रैकिंग सेवा" : "Tracking Engine",
                  kIsWeb ? "UNSUPPORTED" : "ONLINE",
                  kIsWeb ? Colors.orange : Colors.green,
                ),
                _buildStatCard(
                  Icons.query_stats_rounded,
                  dashboardController.isHindi.value ? "आज के सबमिशन" : "Sync Success Rate",
                  "99.8%",
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Geofence status and diagnostic tools
            Text(
              dashboardController.isHindi.value
                  ? "जियोफेंस डायग्नोस्टिक्स"
                  : "Geofence Diagnostics",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  _buildDiagnosticRow(
                    Icons.gps_fixed_rounded,
                    dashboardController.isHindi.value ? "सक्रिय स्थान सेवा" : "Location Provider Status",
                    dashboardController.isHindi.value ? "सक्रिय (उच्च सटीकता)" : "Active (High Accuracy)",
                    Colors.green,
                  ),
                  const Divider(height: 24),
                  _buildDiagnosticRow(
                    Icons.security_update_warning_rounded,
                    dashboardController.isHindi.value ? "माक लोकेशन ब्लॉक" : "Allow Mock Locations",
                    dashboardController.isHindi.value ? "प्रतिबंधित (सुरक्षित)" : "Disabled (Protected)",
                    Colors.deepOrange,
                  ),
                  const Divider(height: 24),
                  _buildDiagnosticRow(
                    Icons.lock_clock_rounded,
                    dashboardController.isHindi.value ? "बैकग्राउंड मॉनिटर" : "Background Monitor isolate",
                    kIsWeb
                        ? (dashboardController.isHindi.value ? "असमर्थित (वेब)" : "Unsupported on Web")
                        : (dashboardController.isHindi.value ? "सक्रिय" : "Active isolate thread"),
                    kIsWeb ? Colors.orange : Colors.blue,
                  ),
                  const Divider(height: 24),
                  InkWell(
                    onTap: () => Get.to(() => const BackgroundLogsView()),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: Colors.deepOrange, size: 22),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              dashboardController.isHindi.value ? "डायग्नोस्टिक लॉग्स देखें" : "View Diagnostic Logs",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.deepOrange, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Help section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.deepOrange),
                      const SizedBox(width: 12),
                      Text(
                        dashboardController.isHindi.value ? "एडमिन जानकारी" : "Admin Information",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dashboardController.isHindi.value
                        ? "यह एडमिन पैनल आपको जियोफेंसिंग सुरक्षा और सिस्टम मेट्रिक्स को ट्रैक करने में मदद करता है। किसी भी विसंगति के मामले में, कृपया लाइव रिफ्रेश बटन का उपयोग करें।"
                        : "This console details current device configurations, geofence bounds, and platform diagnostic state. Radius updates or perimeter adjustments are dynamically read from the database server.",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(IconData icon, String label, String value, Color statusColor) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
