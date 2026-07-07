import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const sourcePath = 'assets/app_icon.png';
const previewPath = 'assets/icons/app_icon_preview_1024.png';

const iconSizes = <int>[
  16,
  20,
  24,
  29,
  32,
  40,
  48,
  64,
  72,
  76,
  80,
  96,
  120,
  128,
  144,
  152,
  167,
  180,
  192,
  256,
  384,
  512,
  1024,
];

void main() {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw StateError('Missing icon source: $sourcePath');
  }

  final source = img.decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    throw StateError('Unable to decode PNG icon source: $sourcePath');
  }

  Directory('assets/icons').createSync(recursive: true);

  final iconSource = img.copyResize(
    _centerCropSquare(source),
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );
  File(previewPath).writeAsBytesSync(img.encodePng(iconSource));

  for (final size in iconSizes) {
    final resized = img.copyResize(
      iconSource,
      width: size,
      height: size,
      interpolation: size <= 48
          ? img.Interpolation.average
          : img.Interpolation.cubic,
    );
    File(
      'assets/icons/app_icon_${size}x$size.png',
    ).writeAsBytesSync(img.encodePng(resized));
  }

  stdout.writeln(
    'Generated ${iconSizes.length} PNG icon sizes from $sourcePath.',
  );
  stdout.writeln('Launcher source: $sourcePath');
}

img.Image _centerCropSquare(img.Image source) {
  final side = math.min(source.width, source.height);
  final x = ((source.width - side) / 2).round();
  final y = ((source.height - side) / 2).round();
  return img.copyCrop(source, x: x, y: y, width: side, height: side);
}
