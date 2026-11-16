import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:image_background_remover/image_background_remover.dart';

Uint8List? _composeAndCompressTask(Map<String, dynamic> m) {
  final fg = img.decodeImage(m['fg'] as Uint8List);
  if (fg == null) return null;

  final bool isTransparent = m['isTransparent'] as bool;
  final int? colorVal = m['color'] as int?;
  final Uint8List? bgBytes = m['bgImg'] as Uint8List?;
  final int quality = m['quality'] as int;

  final double scaleFactor = (0.3 + (quality / 100.0) * 0.7).clamp(0.3, 1.0);
  final int targetW = (fg.width * scaleFactor).round().clamp(100, 3000);
  final int targetH = (fg.height * scaleFactor).round().clamp(100, 3000);
  final resizedFg = img.copyResize(fg, width: targetW, height: targetH);

  if (isTransparent) {
    return Uint8List.fromList(img.encodePng(resizedFg, level: 6));
  }

  img.Image canvas = img.Image(width: targetW, height: targetH, numChannels: 4);
  if (bgBytes != null) {
    final bgDecoded = img.decodeImage(bgBytes);
    if (bgDecoded != null) {
      canvas = img.copyResize(bgDecoded, width: targetW, height: targetH).convert(numChannels: 4);
    }
  } else if (colorVal != null) {
    final c = Color(colorVal);
    img.fill(canvas, color: img.ColorRgba8((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), 255));
  }

  img.compositeImage(canvas, resizedFg);
  return Uint8List.fromList(img.encodeJpg(canvas, quality: quality));
}
