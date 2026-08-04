import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  ImageStorageService._();

  static final ImageStorageService instance = ImageStorageService._();

  Future<String> persistImage({
    required String sourcePath,
    required int tradeId,
    required String stage,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(root.path, 'trade_images', tradeId.toString()),
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);

    final fileName =
        '${stage.toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}$extension';

    final destination = p.join(dir.path, fileName);
    final copied = await File(sourcePath).copy(destination);

    return copied.path;
  }

  Future<void> deleteImage(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
