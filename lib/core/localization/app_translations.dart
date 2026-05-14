import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'login': 'Login',
      'welcome': 'Welcome',
      'dashboard': 'Dashboard',
      'tasks': 'Tasks',
      'remarks': 'Remarks',
      'upload_image': 'Upload Proof',
      'complete_task': 'Complete Task',
      'reload': 'Reload',
      'language': 'Language',
      'no_tasks': 'No Tasks Available',
    },
    'hi': {
      'login': 'लॉगिन',
      'welcome': 'स्वागत है',
      'dashboard': 'डैशबोर्ड',
      'tasks': 'कार्य',
      'remarks': 'टिप्पणी',
      'upload_image': 'प्रूफ अपलोड करें',
      'complete_task': 'कार्य पूरा करें',
      'reload': 'रीलोड',
      'language': 'भाषा',
      'no_tasks': 'कोई कार्य उपलब्ध नहीं',
    },
  };
}
