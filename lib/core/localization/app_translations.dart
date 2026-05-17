import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'login': 'Login',
          'logout': 'Logout',
          'pending': 'Pending',
          'completed': 'Completed',
          'total': 'Total',
          'tasks': 'Tasks',
          'punch_in': 'Punch In',
          'punched_in': 'Punched In',
          'complete_task': 'Complete Task',
          'task_completed': 'Task Completed',
          'language': 'Language',
          'refresh': 'Refresh',
          'work_tasks': 'Work Tasks',
          'no_tasks_found': 'No tasks found',
        },
        'hi': {
          'login': 'लॉगिन',
          'logout': 'लॉगआउट',
          'pending': 'लंबित',
          'completed': 'पूर्ण',
          'total': 'कुल',
          'tasks': 'कार्य',
          'punch_in': 'पंच इन',
          'punched_in': 'पंच इन हो चुका',
          'complete_task': 'कार्य पूरा करें',
          'task_completed': 'कार्य पूरा हो गया',
          'language': 'भाषा',
          'refresh': 'रीफ्रेश',
          'work_tasks': 'वर्क टास्क',
          'no_tasks_found': 'कोई कार्य नहीं मिला',
        },
      };
}
