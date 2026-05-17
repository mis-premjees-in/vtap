// import 'package:flutter/material.dart';

// class FloatingTaskReminder extends StatefulWidget {
//   final String title;

//   const FloatingTaskReminder({
//     super.key,
//     required this.title,
//   });

//   @override
//   State<FloatingTaskReminder> createState() => _FloatingTaskReminderState();
// }

// class _FloatingTaskReminderState extends State<FloatingTaskReminder>
//     with SingleTickerProviderStateMixin {
//   late AnimationController controller;

//   @override
//   void initState() {
//     super.initState();

//     controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat(reverse: true);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: controller,
//       builder: (context, child) {
//         return Transform.translate(
//           offset: Offset(
//             0,
//             controller.value * 8,
//           ),
//           child: child,
//         );
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(
//           horizontal: 18,
//           vertical: 14,
//         ),
//         decoration: BoxDecoration(
//           color: Colors.orange,
//           borderRadius: BorderRadius.circular(18),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.orange.withOpacity(0.4),
//               blurRadius: 20,
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(
//               Icons.notifications_active,
//               color: Colors.white,
//             ),
//             const SizedBox(width: 10),
//             Text(
//               widget.title,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
// }
