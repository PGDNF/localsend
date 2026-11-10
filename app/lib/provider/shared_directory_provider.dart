import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The directory whose current content is offered for download via the link.
/// The value is a SAF tree URI (or a raw path on older Android versions).
/// `null` means no shared directory is configured.
final sharedDirectoryProvider = NotifierProvider<SharedDirectoryService, String?>((ref) {
  return SharedDirectoryService(ref.read(persistenceProvider));
});

class SharedDirectoryService extends PureNotifier<String?> {
  final PersistenceService _persistence;

  SharedDirectoryService(this._persistence);

  @override
  String? init() => _persistence.getSharedDirectory();

  Future<void> setDirectory(String? directory) async {
    await _persistence.setSharedDirectory(directory);
    state = directory;
  }
}