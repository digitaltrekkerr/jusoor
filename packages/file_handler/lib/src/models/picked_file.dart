import 'dart:typed_data';

/// Represents a file picked by the user via the system file picker.
///
/// Contains the file's metadata and optionally its raw bytes when
/// [FilePickerService.pickFile] is called with `withData: true`.
class PickedFile {
  /// The name of the file including its extension (e.g. `document.html`).
  final String name;

  /// The file extension without a leading dot (e.g. `html`, `txt`).
  final String extension;

  /// The raw bytes of the file, or `null` if bytes were not requested
  /// or the file could not be read.
  final Uint8List? bytes;

  /// Creates a [PickedFile] with the given [name], [extension], and optional
  /// [bytes].
  const PickedFile({required this.name, required this.extension, this.bytes});
}
