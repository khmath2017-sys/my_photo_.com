
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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
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

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});
  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  final _picker = ImagePicker();
  File? _orig;
  Uint8List? _comp;
  double _q = 50;
  int _s1 = 0, _s2 = 0;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final file = File(f.path);
      final len = await file.length();
      setState(() { _orig = file; _s1 = len; _comp = null; });
      await _run();
    }
  }

  Future<void> _run() async {
    if (_orig == null) return;
    setState(() => _busy = true);
    try {
      final int maxDim = (600 + (_q * 12)).toInt();
      final res = await FlutterImageCompress.compressWithFile(
        _orig!.absolute.path,
        minWidth: maxDim,
        minHeight: maxDim,
        quality: _q.toInt(),
        format: CompressFormat.jpeg,
      );
      if (res != null) setState(() { _comp = res; _s2 = res.length; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_comp == null) return;
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(_comp!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в галерею!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сохранения')));
    }
  }

  String _fmt(int b) => b < 1048576 ? '${(b / 1024).toStringAsFixed(1)} КБ' : '${(b / 1048576).toStringAsFixed(2)} МБ';

  @override
  Widget build(BuildContext context) {
    final int savedPercent = (_s1 > 0 && _s2 > 0) ? (((_s1 - _s2) / _s1) * 100).round() : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Сжать фото')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_orig != null) ...[
              _comp != null ? Image.memory(_comp!, height: 220) : Image.file(_orig!, height: 220),
              const SizedBox(height: 15),
              Text('Было: ${_fmt(_s1)}', style: const TextStyle(fontSize: 16)),
              if (_comp != null)
                Text(
                  'Стало: ${_fmt(_s2)} (${savedPercent > 0 ? "-$savedPercent%" : "мин. размер"})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              const SizedBox(height: 10),
              Text('Качество: ${_q.toInt()}%'),
              Slider(value: _q, min: 10, max: 90, divisions: 16, label: '${_q.toInt()}%', onChanged: (v) => setState(() => _q = v), onChangeEnd: (_) => _run()),
              if (_busy) const CircularProgressIndicator() else ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Сохранить в галерею')),
            ] else const Icon(Icons.image, size: 120, color: Colors.grey),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.photo), label: const Text('Выбрать фото')),
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
  if (im.width > 1200 || im.height > 1200) im = img.copyResize(im, width: 1200);
  final rgba = im.convert(numChannels: 4);
  final bg = rgba.getPixel(0, 0);
  final tol = (m['t'] as int) * 3;
  for (int y = 0; y < rgba.height; y++) {
    for (int x = 0; x < rgba.width; x++) {
      final p = rgba.getPixel(x, y);
      if ((p.r - bg.r).abs() + (p.g - bg.g).abs() + (p.b - bg.b).abs() < tol) rgba.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }
  return Uint8List.fromList(img.encodePng(rgba));
}

class RemoveBgScreen extends StatefulWidget {
  const RemoveBgScreen({super.key});
  @override
  State<RemoveBgScreen> createState() => _RemoveBgScreenState();
}

class _RemoveBgScreenState extends State<RemoveBgScreen> {
  final _picker = ImagePicker();
  Uint8List? _orig, _out;
  double _tol = 35;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await _picker.pickImage(source: ImageSource.gallery);
    if (f != null) {
      final b = await File(f.path).readAsBytes();
      setState(() { _orig = b; _out = null; });
      await _run();
    }
  }

  Future<void> _run() async {
    if (_orig == null) return;
    setState(() => _busy = true);
    try {
      final res = await compute(_bgTask, {'b': _orig!, 't': _tol.toInt()});
      setState(() => _out = res);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_out == null) return;
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(_out!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PNG сохранен!')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Убрать фон')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_out != null) ...[
              Container(color: Colors.grey.shade300, child: Image.memory(_out!, height: 220)),
              Slider(value: _tol, min: 10, max: 90, onChanged: (v) => setState(() => _tol = v), onChangeEnd: (_) => _run()),
              ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Сохранить PNG')),
            ] else if (_busy) const CircularProgressIndicator() else const Icon(Icons.auto_fix_high, size: 120, color: Colors.grey),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.photo), label: const Text('Выбрать фото')),
          ],
        ),
      ),
    );
  }
}
