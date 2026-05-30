import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isAdmin;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: "Tasks"),
      if (isAdmin)
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Admin"),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
    ];

    final safeIndex = currentIndex.clamp(0, items.length - 1);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: items,
      ),
    );
  }
}
