import 'dart:io';

import 'package:device_apps/device_apps.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart' as android_channel;
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/rust/api/metadata.dart';
import 'package:localsend_isolates/util/content_uri_helper.dart';
import 'package:localsend_isolates/util/file_path_helper.dart';
import 'package:logging/logging.dart';
import 'package:share_handler/share_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

final _logger = Logger('CrossFileConverters');

/// Utility functions to convert third party models to common [CrossFile] model.
class CrossFileConverters {
  static Future<CrossFile> convertAssetEntity(AssetEntity asset) async {
    final file = (await asset.originFile)!;
    final metadata = await readFileMetadata(path: file.path);
    return CrossFile(
      name: await asset.titleAsync,
      fileType: asset.type == AssetType.video ? FileType.video : FileType.image,
      size: await file.length(),
      thumbnail: null,
      asset: asset,
      path: file.path,
      bytes: null,
      lastModified: metadata?.modified,
      lastAccessed: metadata?.accessed,
    );
  }

  static Future<CrossFile> convertXFile(XFile file) async {
    final metadata = kIsWeb ? null : await readFileMetadata(path: file.path);
    return CrossFile(
      name: file.name,
      fileType: file.name.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: kIsWeb ? null : file.path,
      bytes: kIsWeb ? await file.readAsBytes() : null, // we can fetch it now because in Web it is already there
      lastModified: metadata?.modified,
      lastAccessed: metadata?.accessed,
    );
  }

  static Future<CrossFile> convertFile(File file) async {
    final metadata = await readFileMetadata(path: file.path);
    return CrossFile(
      name: file.path.fileName,
      fileType: file.path.fileName.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: file.path,
      bytes: null,
      lastModified: metadata?.modified,
      lastAccessed: metadata?.accessed,
    );
  }

  static Future<CrossFile> convertFileInfo(android_channel.FileInfo file) async {
    return CrossFile(
      name: file.name,
      fileType: file.name.guessFileType(),
      size: file.size,
      thumbnail: null,
      asset: null,
      path: file.uri,
      bytes: null,
      // SAF only provides milliseconds, so there is no point statting in Rust.
      lastModified: file.lastModified,
      lastAccessed: null,
    );
  }

  /// Converts the files of a picked Android SAF directory into [CrossFile]s,
  /// named relative to the picked folder (including the folder name).
  /// Returns null when the tree URI cannot be decoded.
  static List<CrossFile>? convertAndroidDirectory(android_channel.PickDirectoryResult result) {
    final basePath = ContentUriHelper.getPathFromTreeUri(result.directoryUri);
    if (basePath == null) {
      _logger.warning('Could not get base path from ${result.directoryUri}');
      return null;
    }
    final folderName = ContentUriHelper.getEntityNameFromPath(basePath);
    if (folderName == null) {
      _logger.warning('Could not get folder name from $basePath');
      return null;
    }

    final files = <CrossFile>[];
    for (final file in result.files) {
      final relative = ContentUriHelper.guessRelativePathFromPickedFileContentUri(
        folderContentUri: result.directoryUri,
        basePath: basePath,
        folderName: folderName,
        uri: file.uri,
      );
      if (relative == null) {
        _logger.warning('Could not get relative path from ${file.uri}');
        continue;
      }

      files.add(
        CrossFile(
          name: relative,
          fileType: file.name.guessFileType(),
          size: file.size,
          thumbnail: null,
          asset: null,
          path: file.uri,
          bytes: null,
          // SAF only provides milliseconds, so there is no point statting in Rust.
          lastModified: file.lastModified,
          lastAccessed: null,
        ),
      );
    }

    return files;
  }

  static Future<CrossFile> convertSharedAttachment(SharedAttachment attachment) async {
    final file = File(attachment.path);
    final fileName = attachment.path.fileName;
    final metadata = await readFileMetadata(path: file.path);
    return CrossFile(
      name: fileName,
      fileType: fileName.guessFileType(),
      size: await file.length(),
      thumbnail: null,
      asset: null,
      path: file.path,
      bytes: null,
      lastModified: metadata?.modified,
      lastAccessed: metadata?.accessed,
    );
  }

  static Future<CrossFile> convertApplication(Application app) async {
    final file = File(app.apkFilePath);
    return CrossFile(
      name: '${app.appName.trim()} - v${app.versionName}.apk',
      fileType: FileType.apk,
      thumbnail: app is ApplicationWithIcon ? app.icon : null,
      size: await file.length(),
      asset: null,
      path: app.apkFilePath,
      bytes: null,
      lastModified: null,
      lastAccessed: null,
    );
  }
}

extension CompareFile on CrossFile {
  bool isSameFile({required CrossFile otherFile}) {
    return (path ?? '') == (otherFile.path ?? '');
  }
}
