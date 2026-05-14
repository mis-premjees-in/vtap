import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final ImagePicker picker = ImagePicker();

  // =====================================================
  // PICK IMAGE
  // =====================================================

  static Future<File?> pickImage() async {
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (picked == null) {
      return null;
    }

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      "${picked.path}_compressed.jpg",
      quality: 60,
    );

    if (compressed == null) {
      return File(picked.path);
    }

    return File(compressed.path);
  }
}
