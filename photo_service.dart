import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PhotoService {
  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// Captures a photo and stores it permanently in app documents folder.
  /// Returns the stable saved path, or null if cancelled.
  Future<String?> captureAndStore({
    required String workItemId,
    required bool before,
    int imageQuality = 75,
  }) async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
    );
    if (x == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/work_items/$workItemId/photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = before ? 'before_$ts.jpg' : 'after_$ts.jpg';

    final target = File('${dir.path}/$name');
    final saved = await File(x.path).copy(target.path);

    return saved.path;
  }

  Future<void> safeDeleteFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
