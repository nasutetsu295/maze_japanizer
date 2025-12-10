import 'dart:convert';
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RCJ Map Converter',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const ConverterPage(),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  String? _fileName;
  String? _statusMessage;
  Map<String, dynamic>? _processedJson;
  bool _isProcessing = false;

  Future<void> _pickAndProcessFile() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _processedJson = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        final bytes = result.files.first.bytes!;
        final name = result.files.first.name;
        final jsonString = utf8.decode(bytes);
        final Map<String, dynamic> data = jsonDecode(jsonString);

        // リーグタイプを entry に
        String oldLeague = data['leagueType'] ?? 'unknown';
        data['leagueType'] = 'entry'; 

        int blueCount = 0;
        int redCount = 0;

        if (data.containsKey('cells') && data['cells'] is Map) {
          final Map<String, dynamic> cells = data['cells'];
          
          cells.forEach((key, cellData) {
            if (cellData['tile'] != null) {
              final tile = cellData['tile'];
              _ensureVictimsObj(tile);

              //壁の被災者を削除
              final victims = tile['victims'];
              if (victims['top'] != 'None' || victims['right'] != 'None' || 
                  victims['bottom'] != 'None' || victims['left'] != 'None') {
                wallVictimsRemoved++;
              }
              
              victims['top'] = 'None';
              victims['right'] = 'None';
              victims['bottom'] = 'None';
              victims['left'] = 'None';

              // 青タイルを緑被災者に
              if (tile['blue'] == true) {
                tile['blue'] = false;
                tile['victims']['floor'] = 'Green';
                blueCount++;
              }

              // 赤タイルを赤被災者に
              if (tile['red'] == true) {
                tile['red'] = false;
                tile['victims']['floor'] = 'Red';
                redCount++;
              }

              // 坂と階段の処理
              if ((tile ['ramp'] = true) || (tile['steps'] == true )) {
                tile['ramp'] = false;
                tile['steps'] = false;
              }
            }
          });
        }

        setState(() {
          _fileName = name;
          _processedJson = data;
          _statusMessage = "処理完了！\n"
                          "リーグ設定: $oldLeague → entry\n"
                          "青 → 緑被災者: ${blueCount}件\n"
                          "赤 → 赤被災者: ${redCount}件";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "エラーが発生しました: $e";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _ensureVictimsObj(Map<String, dynamic> tile) {
    if (tile['victims'] == null) {
      tile['victims'] = {
        "top": "None", "right": "None", "bottom": "None", "left": "None", "floor": "None"
      };
    }
  }

  void _downloadFile() {
    if (_processedJson == null || _fileName == null) return;

    final jsonString = const JsonEncoder.withIndent('  ').convert(_processedJson);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    html.AnchorElement(href: url)
      ..setAttribute("download", "entry_$_fileName")
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RCJ Map Converter (Entry)')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cleaning_services_outlined, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "maze map japanizer",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "・League Type → Entry\n・壁の被災者 → 削除 (None)\n・Color Tile → Floor Victim",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAndProcessFile,
                icon: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: const Text("JSONを選択して変換"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                ),
              ),

              const SizedBox(height: 30),

              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 30),

              if (_processedJson != null)
                FilledButton.icon(
                  onPressed: _downloadFile,
                  icon: const Icon(Icons.download),
                  label: const Text("変換ファイルをダウンロード"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}