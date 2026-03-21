import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  static Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return null;
    return copyImageToAppDir(File(xFile.path));
  }

  static Future<File> copyImageToAppDir(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(join(appDir.path, 'lineup_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = extension(sourceFile.path);
    final newFileName = '${_uuid.v4()}$ext';
    final newPath = join(imagesDir.path, newFileName);

    return await sourceFile.copy(newPath);
  }

  static Future<void> deleteImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
