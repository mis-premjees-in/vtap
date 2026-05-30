import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/storage_service.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class BackgroundLogsView extends StatefulWidget {
  const BackgroundLogsView({super.key});

  @override
  State<BackgroundLogsView> createState() => _BackgroundLogsViewState();
}

class _BackgroundLogsViewState extends State<BackgroundLogsView> {
  final dashboardController = Get.find<DashboardController>();
  final TextEditingController _searchController = TextEditingController();

  List<String> _allLogs = [];
  List<String> _filteredLogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    final logs = await StorageService.getLogs();
    
    setState(() {
      // Show newest first
      _allLogs = logs.reversed.toList();
      _filterLogs(_searchController.text);
      _isLoading = false;
    });
  }

  void _filterLogs(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredLogs = List.from(_allLogs);
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        return log.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  Future<void> _copyToClipboard() async {
    if (_allLogs.isEmpty) return;
    
    // Copy in chronological order (oldest to newest)
    final textToCopy = _allLogs.reversed.join('\n');
    await Clipboard.setData(ClipboardData(text: textToCopy));

    Get.snackbar(
      dashboardController.isHindi.value ? "कॉपी किया गया" : "Copied",
      dashboardController.isHindi.value 
          ? "सभी लॉग क्लिपबोर्ड पर कॉपी हो चुके हैं।" 
          : "All logs copied to clipboard.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _confirmClearLogs() async {
    Get.defaultDialog(
      title: dashboardController.isHindi.value ? "लॉग साफ़ करें?" : "Clear Logs?",
      middleText: dashboardController.isHindi.value
          ? "क्या आप सभी बैकग्राउंड सर्विस लॉग साफ़ करना चाहते हैं? इसे वापस नहीं लाया जा सकता।"
          : "Are you sure you want to delete all background service logs? This action is permanent.",
      textConfirm: dashboardController.isHindi.value ? "हाँ" : "Yes",
      textCancel: dashboardController.isHindi.value ? "नहीं" : "No",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back(); // Dismiss dialog
        await StorageService.clearLogs();
        await _loadLogs();
        Get.snackbar(
          dashboardController.isHindi.value ? "सफलता" : "Success",
          dashboardController.isHindi.value ? "लॉग साफ़ कर दिए गए हैं।" : "Logs cleared successfully.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueGrey,
          colorText: Colors.white,
        );
      },
    );
  }

  // Parse log and extract styling details
  Map<String, dynamic> _parseLogEntry(String log) {
    // Expected format: "[YYYY-MM-DD HH:mm:ss] message"
    String timestamp = "";
    String message = log;

    if (log.startsWith('[') && log.contains(']')) {
      final closingBracketIdx = log.indexOf(']');
      timestamp = log.substring(1, closingBracketIdx);
      message = log.substring(closingBracketIdx + 1).trim();
    }

    // Determine type/theme based on message contents
    Color color = Colors.blueGrey.shade600;
    IconData icon = Icons.info_outline_rounded;

    final lowerMsg = message.toLowerCase();
    if (lowerMsg.contains("error") || 
        lowerMsg.contains("failed") || 
        lowerMsg.contains("aborted") || 
        lowerMsg.contains("failure")) {
      color = Colors.redAccent;
      icon = Icons.error_outline_rounded;
    } else if (lowerMsg.contains("success") || 
               lowerMsg.contains("succeeded") || 
               lowerMsg.contains("punched in") || 
               lowerMsg.contains("punched out")) {
      color = Colors.green;
      icon = Icons.check_circle_outline_rounded;
    } else if (lowerMsg.contains("geofence trigger") || 
               lowerMsg.contains("enter zone") || 
               lowerMsg.contains("exit zone") || 
               lowerMsg.contains("transition")) {
      color = Colors.orange;
      icon = Icons.explore_outlined;
    } else if (lowerMsg.contains("foreground app:") || 
               lowerMsg.contains("invoking") || 
               lowerMsg.contains("received")) {
      color = Colors.blue;
      icon = Icons.touch_app_rounded;
    }

    return {
      "timestamp": timestamp,
      "message": message,
      "color": color,
      "icon": icon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = dashboardController.isHindi.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          isHindi ? "सिस्टम डायग्नोस्टिक लॉग्स" : "Background Diagnostics",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLogs,
              decoration: InputDecoration(
                hintText: isHindi ? "लॉग संदेश खोजें..." : "Filter logs by keyword...",
                hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filterLogs("");
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FD),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              isHindi ? "कोई लॉग डेटा नहीं मिला" : "No logs available",
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        color: Colors.deepOrange,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredLogs.length,
                          itemBuilder: (context, index) {
                            final parsed = _parseLogEntry(_filteredLogs[index]);
                            return _buildLogCard(parsed);
                          },
                        ),
                      ),
          ),

          // Bottom Action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ]
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _confirmClearLogs,
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                      label: Text(
                        isHindi ? "साफ़ करें" : "Clear All",
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
                      label: Text(
                        isHindi ? "कॉपी करें" : "Copy Logs",
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> parsed) {
    final String timestamp = parsed["timestamp"];
    final String message = parsed["message"];
    final Color color = parsed["color"];
    final IconData icon = parsed["icon"];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon with background glow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (timestamp.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        timestamp,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
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
}
