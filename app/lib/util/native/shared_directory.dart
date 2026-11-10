import 'dart:io';

import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart' as android_channel;
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_isolates/rust/api/metadata.dart';
import 'package:localsend_isolates/util/content_uri_helper.dart';
import 'package:localsend_isolates/util/file_path_helper.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _logger = Logger('SharedDirectory');

/// The display name of the shared directory (SAF tree URI or raw path).
String sharedDirectoryName(String directory) {
  if (directory.startsWith('content://')) {
    final basePath = ContentUriHelper.getPathFromTreeUri(directory);
    if (basePath != null) {
      final name = ContentUriHelper.getEntityNameFromPath(basePath);
      if (name != null) {
        return name;
      }
    }
    return directory;
  }

  return p.basename(directory);
}

/// Reads the current content of the shared directory (recursively).
/// Returns null when the directory cannot be read, e.g. because the
/// persistable SAF permission was revoked or the directory was deleted.
Future<List<CrossFile>?> loadSharedDirectoryFiles(String directory) async {
  try {
    if (directory.startsWith('content://')) {
      final files = await android_channel.listDirectoryAndroid(directory);
      return CrossFileConverters.convertAndroidDirectory(
        android_channel.PickDirectoryResult(directoryUri: directory, files: files),
      );
    }

    final dir = Directory(directory);
    if (!dir.existsSync()) {
      _logger.warning('Shared directory does not exist: $directory');
      return null;
    }

    final directoryName = p.basename(directory);
    final files = <CrossFile>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }

      final relative = '$directoryName/${p.relative(entity.path, from: directory).replaceAll('\\', '/')}';
      final metadata = await readFileMetadata(path: entity.path);
      files.add(
        CrossFile(
          name: relative,
          fileType: relative.guessFileType(),
          size: await entity.length(),
          thumbnail: null,
          asset: null,
          path: entity.path,
          bytes: null,
          lastModified: metadata?.modified,
          lastAccessed: metadata?.accessed,
        ),
      );
    }

    return files;
  } catch (e, st) {
    _logger.warning('Failed to read shared directory $directory', e, st);
    return null;
  }
}