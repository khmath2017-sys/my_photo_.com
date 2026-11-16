import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(
                context,
                title: 'Сжать фото',
                icon: Icons.compress,
                page: const CompressScreen(),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                title: 'В PDF',
                icon: Icons.picture_as_pdf,
                page: const PdfScreen(),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                title: 'Убрать фон',
                icon: Icons.auto_fix_high,
                page: const RemoveBgScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required String title, required IconData icon, required Widget page}) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      icon: Icon(icon, size: 28),
      label: Text(title, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(250, 65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

// ==========================================
// 1. شاشة ضغط الصور (Сжать фото)
// ==========================================
class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _originalImage;
  Uint8List? _compressedBytes;
  double _quality = 70;
  int _originalSize = 0;
  int _compressedSize = 0;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = File(image.path);
      final bytes = await file.length();
      setState(() {
        _originalImage = file;
        _originalSize = bytes;
        _compressedBytes = null;
      });
      await _compressImage();
    }
  }

  Future<void> _compressImage() async {
    if (_originalImage == null) return;
    setState(() => _isProcessing = true);
    try {
      final result = await FlutterImageCompress.compressWithFile(
        _originalImage!.absolute.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: _quality.toInt(),
      );
      if (result != null) {
        setState(() {
          _compressedBytes = result;
          _compressedSize = result.length;
        });
      }
    } catch (e) {
      _showMsg('Ошибка сжатия: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_compressedBytes == null) return;
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImageBytes(_compressedBytes!);
      _showMsg('Фото сохранено в галерею!');
    } catch (e) {
      _showMsg('Нет доступа к галерее или ошибка сохранения');
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 КБ';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} МБ';
  }

  void _showMsg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сжать фото')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_originalImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_originalImage!, height: 220, fit: BoxFit.contain),
              ),
              const SizedBox(height: 15),
              Text('Исходный размер: ${_formatSize(_originalSize)}',
                  style: const TextStyle(fontSize: 16)),
              if (_compressedBytes != null)
                Text('После сжатия: ${_formatSize(_compressedSize)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 20),
              Text('Качество: ${_quality.toInt()}%'),
              Slider(
                value: _quality,
                min: 10,
                max: 95,
                divisions: 17,
                label: '${_quality.toInt()}%',
                onChanged: (val) => setState(() => _quality = val),
                onChangeEnd: (_) => _compressImage(),
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Сохранить в галерею'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(220, 50)),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Icon(Icons.image_outlined, size: 120, color: Colors.grey),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Выбрать фото'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(220, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. شاشة التحويل إلى PDF (В PDF)
// ==========================================
class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key});

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

// دالة المعالجة في الخلفية لحماية الواجهة من التجمد
Future<Uint8List> _generatePdfInBackground(List<String> paths) async {
  final pdf = pw.Document();
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded != null) {
      if (decoded.width > 1600 || decoded.height > 1600) {
        decoded = img.copyResize(decoded, width: 1600);
      }
      final resizedBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
      final pdfImage = pw.MemoryImage(resizedBytes);
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(child: pw.Image(pdfImage)),
        ),
      );
    }
  }
  return pdf.save();
}

class _PdfScreenState extends State<PdfScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];
  bool _isBuilding = false;

  Future<void> _pickImages() async {
    final List<XFile> selected = await _picker.pickMultiImage();
    if (selected.isNotEmpty) {
      setState(() => _images = selected);
    }
  }

  Future<void> _createAndSharePdf() async {
    if (_images.isEmpty) return;
    setState(() => _isBuilding = true);
    try {
      final paths = _images.map((e) => e.path).toList();
      final pdfBytes = await compute(_generatePdfInBackground, paths);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/document_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Мой PDF документ');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка создания PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBuilding = false);
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
              child: _images.isEmpty
                  ? const Center(
                      child: Text('Выберите одно или несколько фото',
                          style: TextStyle(fontSize: 16, color: Colors.grey)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
