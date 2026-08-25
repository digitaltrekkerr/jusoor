import 'package:file_picker/file_picker.dart';

import '../models/picked_file.dart';

/// Service responsible for invoking the platform file picker and returning
/// a [PickedFile] with the selected file's metadata and bytes.
class FilePickerService {
  /// File extensions that the picker accepts.
  static const List<String> supportedExtensions = [
    'html',
    'htm',
    'md',
    'markdown',
    'txt',
  ];

  /// Opens the platform file picker filtered to [supportedExtensions].
  ///
  /// Returns a [PickedFile] containing the file's name, extension, and bytes
  /// when the user selects a file, or `null` if the user cancels the picker.
  Future<PickedFile?> pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      return PickedFile(
        name: file.name,
        extension: file.extension ?? '',
        bytes: file.bytes,
      );
    }

    return null;
  }
}
