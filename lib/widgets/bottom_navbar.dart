import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;

  final Function(int) onTap;

  const BottomNavbar({
    super.key,

    required this.currentIndex,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        currentIndex: currentIndex,

        onTap: onTap,

        backgroundColor: Colors.transparent,

        elevation: 0,

        selectedItemColor: Colors.orange,

        unselectedItemColor: Colors.grey,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: "Tasks"),

          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Admin"),

          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
