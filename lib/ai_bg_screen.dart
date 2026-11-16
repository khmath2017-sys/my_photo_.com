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

class RemoveBgScreen extends StatefulWidget {
  const RemoveBgScreen({super.key});
  @override
  State<RemoveBgScreen> createState() => _RemoveBgScreenState();
}

class _RemoveBgScreenState extends State<RemoveBgScreen> {
  final _picker = ImagePicker();
  Uint8List? _cutoutPngBytes, _finalOutBytes, _bgImageBytes;
  Color? _selectedColor;
  double _quality = 80;
  bool _busy = false;
  bool _engineReady = false;

  @override
  void initState() {
    super.initState();
    _initAiEngine();
  }

  Future<void> _initAiEngine() async {
    await BackgroundRemover.instance.initializeOrt();
    if (mounted) setState(() => _engineReady = true);
  }

  @override
  void dispose() {
    BackgroundRemover.instance.dispose();
    super.dispose();
  }

    Future<void> _pickAndCutout() async {
    if (!_engineReady) return;
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f == null) return;
    setState(() { _busy = true; _cutoutPngBytes = null; _finalOutBytes = null; });
    try {
      final rawBytes = await File(f.path).readAsBytes();
      // تصغير الصورة الضخمة لحماية الرام قبل العزل
      final safeBytes = await compute((Uint8List b) {
        var im = img.decodeImage(b);
        if (im == null) return b;
        if (im.width > 1024 || im.height > 1024) {
          im = img.copyResize(im, width: im.width >= im.height ? 1024 : null, height: im.height > im.width ? 1024 : null);
        }
        return Uint8List.fromList(img.encodeJpg(im, quality: 90));
      }, rawBytes);

      final uiImage = await BackgroundRemover.instance.removeBg(safeBytes);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        _cutoutPngBytes = byteData.buffer.asUint8List();
        await _rebuildFinalImage();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка ИИ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rebuildFinalImage() async {
    if (_cutoutPngBytes == null) return;
    setState(() => _busy = true);
    try {
      final bool isTransparent = (_selectedColor == null && _bgImageBytes == null);
      final out = await compute(_composeAndCompressTask, {
        'fg': _cutoutPngBytes!,
        'isTransparent': isTransparent,
        'color': _selectedColor?.toARGB32(),
        'bgImg': _bgImageBytes,
        'quality': _quality.toInt(),
      });
      if (mounted) setState(() => _finalOutBytes = out);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBgImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final b = await File(f.path).readAsBytes();
      setState(() { _bgImageBytes = b; _selectedColor = null; });
      await _rebuildFinalImage();
    }
  }

  Future<void> _save() async {
    if (_finalOutBytes == null) return;
    final bool isTransparent = (_selectedColor == null && _bgImageBytes == null);
    final String ext = isTransparent ? 'png' : 'jpg';
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ai_bg_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(_finalOutBytes!);
      await Gal.putImage(file.path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Сохранено (.$ext)!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сохранения')));
    }
  }

  String _fmt(int b) => b < 1048576 ? '${(b / 1024).toStringAsFixed(1)} КБ' : '${(b / 1048576).toStringAsFixed(2)} МБ';

  Widget _colorDot(Color? color) {
    final isSelected = (_selectedColor == color && _bgImageBytes == null);
    return GestureDetector(
      onTap: () async {
        setState(() { _selectedColor = color; _bgImageBytes = null; });
        await _rebuildFinalImage();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.blue : Colors.black26, width: isSelected ? 3 : 1),
        ),
        child: color == null ? const Icon(Icons.grid_off, size: 18, color: Colors.black54) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Убрать фон (ИИ)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!_engineReady)
              const Padding(padding: EdgeInsets.all(40), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Загрузка ИИ модели...')]))
            else if (_finalOutBytes != null) ...[
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueGrey.shade800, borderRadius: BorderRadius.circular(12)), child: Image.memory(_finalOutBytes!, height: 220)),
              const SizedBox(height: 8),
              Text('Размер: ${_fmt(_finalOutBytes!.length)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_colorDot(null), _colorDot(Colors.white), _colorDot(Colors.blue), _colorDot(Colors.red), _colorDot(Colors.black)]),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _pickBgImage, icon: const Icon(Icons.wallpaper), label: const Text('Фон из галереи')),
              const SizedBox(height: 12),
              Text('Качество и размер: ${_quality.toInt()}%'),
              Slider(value: _quality, min: 20, max: 100, divisions: 16, onChanged: (v) => setState(() => _quality = v), onChangeEnd: (_) => _rebuildFinalImage()),
              if (_busy) const CircularProgressIndicator() else ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Сохранить')),
            ] else if (_busy)
              const Padding(padding: EdgeInsets.all(50), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Удаление фона...')]))
                        else
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 30, bottom: 25),
                padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: const Color(0xFF1E88E5).withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_fix_high, size: 54, color: Color(0xFF1E88E5)),
                    ),
                    const SizedBox(height: 18),
                    const Text('Загрузите фото для ИИ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Нейросеть автоматически удалит фон за пару секунд', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _engineReady && !_busy ? _pickAndCutout : null,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 24),
                label: const Text('Выбрать фото из галереи', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
