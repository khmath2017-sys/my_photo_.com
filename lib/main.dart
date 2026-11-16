
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Фото Утилиты',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.blue),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главная'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _btn(context, 'Сжать фото', Icons.compress, const CompressScreen()),
            const SizedBox(height: 20),
            _btn(context, 'В PDF', Icons.picture_as_pdf, const PdfScreen()),
            const SizedBox(height: 20),
            _btn(context, 'Убрать фон', Icons.auto_fix_high, const RemoveBgScreen()),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, String txt, IconData ic, Widget page) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => page)),
      icon: Icon(ic, size: 28),
      label: Text(txt, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(minimumSize: const Size(250, 65)),
    );
  }
}

Map<String, dynamic>? _compressTask(Map<String, dynamic> m) {
  var im = img.decodeImage(m['bytes'] as Uint8List);
  if (im == null) return null;
  final int scale = m['scale'] as int;
  final int quality = m['quality'] as int;

  final int newW = ((im.width * scale) / 100).round().clamp(50, 4000);
  final int newH = ((im.height * scale) / 100).round().clamp(50, 4000);
  im = img.copyResize(im, width: newW, height: newH);

  final outBytes = Uint8List.fromList(img.encodeJpg(im, quality: quality));
  return {'bytes': outBytes, 'w': im.width, 'h': im.height};
}

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});
  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  final _picker = ImagePicker();
  Uint8List? _origBytes, _compBytes;
  double _quality = 70;
  double _scale = 75;
  int _s1 = 0, _s2 = 0, _w = 0, _h = 0;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final bytes = await File(f.path).readAsBytes();
      setState(() {
        _origBytes = bytes;
        _s1 = bytes.length;
        _compBytes = null;
      });
      await _run();
    }
  }

  Future<void> _run() async {
    if (_origBytes == null) return;
    setState(() => _busy = true);
    try {
      final res = await compute(_compressTask, {
        'bytes': _origBytes!,
        'quality': _quality.toInt(),
        'scale': _scale.toInt(),
      });
      if (res != null && mounted) {
        setState(() {
          _compBytes = res['bytes'] as Uint8List;
          _s2 = _compBytes!.length;
          _w = res['w'] as int;
          _h = res['h'] as int;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_compBytes == null) return;
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/comp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(_compBytes!);
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в галерею!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сохранения')));
      }
    }
  }

  String _fmt(int b) => b < 1048576 ? '${(b / 1024).toStringAsFixed(1)} КБ' : '${(b / 1048576).toStringAsFixed(2)} МБ';

  @override
  Widget build(BuildContext context) {
    final int savedPercent = (_s1 > 0 && _s2 > 0) ? (((_s1 - _s2) / _s1) * 100).round() : 0;
    final double previewHeight = (100 + (_scale * 1.4)).clamp(110, 240);
    return Scaffold(
      appBar: AppBar(title: const Text('Сжать фото')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_origBytes != null) ...[
              SizedBox(
                height: 245,
                child: Center(
                  child: Image.memory(_compBytes ?? _origBytes!, height: previewHeight),
                ),
              ),
              const SizedBox(height: 10),
              Text('Было: ${_fmt(_s1)}', style: const TextStyle(fontSize: 16)),
              if (_compBytes != null) ...[
                Text(
                  'Стало: ${_fmt(_s2)} (${savedPercent > 0 ? "-$savedPercent%" : "сжато"})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                Text('Разрешение: $_w × $_h пикс.', style: const TextStyle(color: Colors.grey)),
              ],
              const SizedBox(height: 10),
              Text('Качество: ${_quality.toInt()}%'),
              Slider(
                value: _quality,
                min: 10,
                max: 95,
                divisions: 17,
                onChanged: (v) => setState(() => _quality = v),
                onChangeEnd: (_) => _run(),
              ),
              Text('Размер (масштаб): ${_scale.toInt()}%'),
              Slider(
                value: _scale,
                min: 10,
                max: 100,
                divisions: 9,
                onChanged: (v) => setState(() => _scale = v),
                onChangeEnd: (_) => _run(),
              ),
              if (_busy)
                const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить в галерею'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Icon(Icons.image, size: 120, color: Colors.grey),
              ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo),
              label: const Text('Выбрать фото'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(220, 48)),
            ),
          ],
        ),
      ),
    );
  }
}


Future<Uint8List> _pdfTask(List<String> paths) async {
  final pdf = pw.Document();
  for (final p in paths) {
    var im = img.decodeImage(await File(p).readAsBytes());
    if (im != null) {
      if (im.width > 1600 || im.height > 1600) im = img.copyResize(im, width: 1600);
      final jpg = Uint8List.fromList(img.encodeJpg(im, quality: 85));
      pdf.addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(jpg)))));
    }
  }
  return pdf.save();
}

class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key});
  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  final _picker = ImagePicker();
  List<XFile> _imgs = [];
  bool _busy = false;

  Future<void> _pick() async {
    final s = await _picker.pickMultiImage();
    if (s.isNotEmpty) setState(() => _imgs = s);
  }

  Future<void> _make() async {
    if (_imgs.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await compute(_pdfTask, _imgs.map((e) => e.path).toList());
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/doc_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)]);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('В PDF')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _imgs.isEmpty
                  ? const Center(child: Text('Выберите фото'))
                  : ListView.builder(
                      itemCount: _imgs.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: Image.file(File(_imgs[i].path), width: 50, height: 50, fit: BoxFit.cover),
                        title: Text('Фото ${i + 1}'),
                      ),
                    ),
            ),
            if (_busy) const CircularProgressIndicator() else ...[
              OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.add_photo_alternate), label: const Text('Выбрать фото')),
              const SizedBox(height: 10),
              if (_imgs.isNotEmpty) ElevatedButton.icon(onPressed: _make, icon: const Icon(Icons.share), label: Text('Создать PDF (${_imgs.length})')),
            ],
          ],
        ),
      ),
    );
  }
}

Uint8List? _bgTask(Map<String, dynamic> m) {
  var im = img.decodeImage(m['b'] as Uint8List);
  if (im == null) return null;
  if (im.width > 1000 || im.height > 1000) im = img.copyResize(im, width: 1000);
  final rgba = im.convert(numChannels: 4);
  final int w = rgba.width;
  final int h = rgba.height;

  final bg = rgba.getPixel(0, 0);
  final num bgR = bg.r, bgG = bg.g, bgB = bg.b;
  final int tol = (m['t'] as int) * 3;

  final visited = Uint8List(w * h);
  final queue = <int>[];

  void tryAdd(int x, int y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final idx = y * w + x;
    if (visited[idx] == 1) return;
    visited[idx] = 1;
    final p = rgba.getPixel(x, y);
    final diff = (p.r - bgR).abs() + (p.g - bgG).abs() + (p.b - bgB).abs();
    if (diff < tol) {
      queue.add(idx);
    }
  }

  for (int x = 0; x < w; x++) {
    tryAdd(x, 0);
    tryAdd(x, h - 1);
  }
  for (int y = 0; y < h; y++) {
    tryAdd(0, y);
    tryAdd(w - 1, y);
  }

  int head = 0;
  while (head < queue.length) {
    final idx = queue[head++];
    final x = idx % w;
    final y = idx ~/ w;
    rgba.setPixelRgba(x, y, 0, 0, 0, 0);
    tryAdd(x + 1, y);
    tryAdd(x - 1, y);
    tryAdd(x, y + 1);
    tryAdd(x, y - 1);
  }

  return Uint8List.fromList(img.encodePng(rgba));
}

Uint8List? _mergeBgTask(Map<String, dynamic> m) {
  final fg = img.decodeImage(m['fg'] as Uint8List);
  if (fg == null) return null;
  final int? colorVal = m['color'] as int?;
  final Uint8List? bgBytes = m['bgImg'] as Uint8List?;

  if (colorVal == null && bgBytes == null) {
    return m['fg'] as Uint8List;
  }

  img.Image canvas = img.Image(width: fg.width, height: fg.height, numChannels: 4);
  if (bgBytes != null) {
    final bgDecoded = img.decodeImage(bgBytes);
    if (bgDecoded != null) {
      canvas = img.copyResize(bgDecoded, width: fg.width, height: fg.height).convert(numChannels: 4);
    }
  } else if (colorVal != null) {
    final c = Color(colorVal);
    img.fill(canvas, color: img.ColorRgba8((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), 255));
  }

  img.compositeImage(canvas, fg);
  return Uint8List.fromList(img.encodePng(canvas));
}

class RemoveBgScreen extends StatefulWidget {
  const RemoveBgScreen({super.key});
  @override
  State<RemoveBgScreen> createState() => _RemoveBgScreenState();
}

class _RemoveBgScreenState extends State<RemoveBgScreen> {
  final _picker = ImagePicker();
  Uint8List? _orig, _cutout, _finalOut, _bgImageBytes;
  Color? _selectedColor;
  double _tol = 35;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final b = await File(f.path).readAsBytes();
      setState(() {
        _orig = b;
        _cutout = null;
        _finalOut = null;
        _selectedColor = null;
        _bgImageBytes = null;
      });
      await _runCutout();
    }
  }

  Future<void> _runCutout() async {
    if (_orig == null) return;
    setState(() => _busy = true);
    try {
      final res = await compute(_bgTask, {'b': _orig!, 't': _tol.toInt()});
      _cutout = res;
      await _applyBackground();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyBackground() async {
    if (_cutout == null) return;
    setState(() => _busy = true);
    try {
      final merged = await compute(_mergeBgTask, {
        'fg': _cutout!,
        'color': _selectedColor?.toARGB32(),
        'bgImg': _bgImageBytes,
      });
      if (mounted) setState(() => _finalOut = merged);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBgImage() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final b = await File(f.path).readAsBytes();
      setState(() {
        _bgImageBytes = b;
        _selectedColor = null;
      });
      await _applyBackground();
    }
  }

  Future<void> _save() async {
    if (_finalOut == null) return;
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_finalOut!);
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в галерею!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сохранения')));
      }
    }
  }

  Widget _colorDot(Color? color, String label) {
    final isSelected = (_selectedColor == color && _bgImageBytes == null);
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedColor = color;
          _bgImageBytes = null;
        });
        await _applyBackground();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: 36,
        height: 36,
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
      appBar: AppBar(title: const Text('Убрать и заменить фон')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_finalOut != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.memory(_finalOut!, height: 220),
              ),
              const SizedBox(height: 12),
              Text('Чувствительность удаления: ${_tol.toInt()}'),
              Slider(value: _tol, min: 5, max: 80, onChanged: (v) => setState(() => _tol = v), onChangeEnd: (_) => _runCutout()),
              const Text('Выберите новый фон:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _colorDot(null, 'Прозрачный'),
                    _colorDot(Colors.white, 'Белый'),
                    _colorDot(Colors.blue, 'Синий'),
                    _colorDot(Colors.red, 'Красный'),
                    _colorDot(Colors.amber, 'Желтый'),
                    _colorDot(Colors.green, 'Зеленый'),
                    _colorDot(Colors.black, 'Черный'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickBgImage,
                icon: const Icon(Icons.wallpaper),
                label: const Text('Фон из галереи'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить фото'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
              ),
            ] else if (_busy)
              const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Icon(Icons.auto_fix_high, size: 120, color: Colors.grey),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo),
              label: const Text('Выбрать основное фото'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(220, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
