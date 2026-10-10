import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'access_api.dart';

const flyerPickerAvailable = true;
const _maximumInputBytes = 10 * 1024 * 1024;
const _maximumOutputBytes = 256 * 1024;

/// Decode and re-encode pixels to remove EXIF and other source metadata.
Future<String> sanitizeMobileFlyer(Uint8List bytes) async {
  final png =
      bytes.length >= 8 &&
      bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  if (bytes.length > _maximumInputBytes || (!png && !jpeg)) {
    throw const ApiFailure('Bitte eine JPG- oder PNG-Datei bis 10 MB wählen.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 40000000) {
      throw const ApiFailure('Das Bild hat zu viele Bildpunkte.');
    }
    var edge = math.min(1600, math.max(descriptor.width, descriptor.height));
    do {
      final ratio = edge / math.max(descriptor.width, descriptor.height);
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * ratio).round()),
        targetHeight: math.max(1, (descriptor.height * ratio).round()),
      );
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final encoded = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (encoded != null && encoded.lengthInBytes <= _maximumOutputBytes) {
            return 'data:image/png;base64,${base64Encode(encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes))}';
          }
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
      edge = (edge * 0.75).floor();
    } while (edge >= 128);
    throw const ApiFailure(
      'Das Bild lässt sich nicht auf höchstens 256 KB verkleinern.',
    );
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

Future<String?> pickEventFlyer() async {
  try {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'JPG / PNG',
          extensions: ['jpg', 'jpeg', 'png'],
          mimeTypes: ['image/jpeg', 'image/png'],
          uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > _maximumInputBytes) {
      throw const ApiFailure(
        'Bitte eine JPG- oder PNG-Datei bis 10 MB wählen.',
      );
    }
    return await sanitizeMobileFlyer(await file.readAsBytes());
  } on ApiFailure {
    rethrow;
  } catch (_) {
    throw const ApiFailure(
      'Das Bild konnte nicht gelesen werden. Bitte eine JPG- oder PNG-Datei wählen.',
    );
  }
}
