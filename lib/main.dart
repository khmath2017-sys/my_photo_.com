import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'ai_bg_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Фоторедактор ИИ и PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF1E88E5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Фоторедактор ИИ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1A237E)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите инструмент:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              _buildProCard(
                context,
                title: 'Убрать и заменить фон (ИИ)',
                subtitle: 'Умное удаление фона и замена на цвет или фото',
                icon: Icons.auto_fix_high,
                color: const Color(0xFF1E88E5),
                page: const RemoveBgScreen(),
              ),
              const SizedBox(height: 16),
              _buildProCard(
                context,
                title: 'Сжать фото',
                subtitle: 'Уменьшение размера файла без потери качества',
                icon: Icons.compress,
                color: const Color(0xFF00897B),
                page: const CompressScreen(),
              ),
              const SizedBox(height: 16),
              _buildProCard(
                context,
                title: 'Фото в PDF',
                subtitle: 'Объединение нескольких снимков в один документ',
                icon: Icons.picture_as_pdf,
                color: const Color(0xFFE53935),
                page: const PdfScreen(),
              ),
              const Spacer(),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Работает офлайн • Без сбора данных',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1C2434)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.3),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
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
