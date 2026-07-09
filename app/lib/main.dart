import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CodSoomaaliApp());
}

class CodSoomaaliApp extends StatelessWidget {
  const CodSoomaaliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cod Soomaali',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4189DD), // Somali blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TtsHomePage(),
    );
  }
}

class TtsHomePage extends StatefulWidget {
  const TtsHomePage({super.key});

  @override
  State<TtsHomePage> createState() => _TtsHomePageState();
}

class _TtsHomePageState extends State<TtsHomePage> {
  final TextEditingController _textController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  bool _modelReady = false;
  bool _generating = false;
  bool _isPlaying = false;
  double _speed = 1.0;
  String? _lastWavPath;
  String _status = 'Diyaarinta codka... (fadlan sug)';

  String _modelPath = '';
  String _tokensPath = '';

  @override
  void initState() {
    super.initState();
    _prepareModel();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Copy the bundled ONNX model + tokens from assets to the app's
  /// documents directory (sherpa-onnx needs real file paths).
  Future<void> _prepareModel() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/model.onnx');
      final tokensFile = File('${dir.path}/tokens.txt');

      if (!await modelFile.exists() || (await modelFile.length()) < 1000000) {
        setState(() => _status = 'Kaydinta modelka markii ugu horreysay...');
        final data = await rootBundle.load('assets/model/model.onnx');
        await modelFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      if (!await tokensFile.exists()) {
        final data = await rootBundle.load('assets/model/tokens.txt');
        await tokensFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }

      _modelPath = modelFile.path;
      _tokensPath = tokensFile.path;

      setState(() {
        _modelReady = true;
        _status = 'Diyaar! Qor qoraal Soomaali ah.';
      });
    } catch (e) {
      setState(() => _status = 'Khalad: $e');
    }
  }

  Future<void> _generate() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !_modelReady || _generating) return;

    await _player.stop();
    setState(() {
      _generating = true;
      _isPlaying = false;
      _lastWavPath = null;
      _status = 'Codka waa la sameynayaa...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/cod_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Run TTS in a background isolate via a TOP-LEVEL helper.
      // Calling Isolate.run directly here would capture this whole State
      // object (including AudioPlayer) -> "object is unsendable" crash.
      final resultPath = await runTtsInIsolate(
        modelPath: _modelPath,
        tokensPath: _tokensPath,
        text: text,
        speed: _speed,
        outPath: outPath,
      );

      setState(() {
        _lastWavPath = resultPath;
        _status = 'Codka waa diyaar! ✅';
      });

      // Auto-play the result.
      await _playPause();
    } catch (e) {
      setState(() => _status = 'Khalad: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _playPause() async {
    if (_lastWavPath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(_lastWavPath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _share() async {
    if (_lastWavPath == null) return;
    await Share.shareXFiles(
      [XFile(_lastWavPath!, mimeType: 'audio/wav')],
      text: 'Cod Soomaali TTS',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cod Soomaali 🇸🇴'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Qoraalka Soomaaliga ah',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 8,
                minLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Halkan ku qor qoraalka aad rabto in codka laga sameeyo...\n\nTusaale: Ku soo dhawoow barnaamijka Cod Soomaali.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.speed),
                  const SizedBox(width: 8),
                  Text('Xawaaraha: ${_speed.toStringAsFixed(1)}x'),
                ],
              ),
              Slider(
                value: _speed,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: '${_speed.toStringAsFixed(1)}x',
                onChanged: (v) => setState(() => _speed = v),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (_modelReady && !_generating) ? _generate : null,
                icon: _generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.record_voice_over),
                label: Text(
                  _generating ? 'Sameynaya...' : 'Samee Codka',
                  style: const TextStyle(fontSize: 18),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              if (_lastWavPath != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _playPause,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Jooji' : 'Dhageyso'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share),
                        label: const Text('Wadaag / Keydi'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _modelReady ? Icons.check_circle : Icons.hourglass_top,
                        color: _modelReady ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_status)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Codkan wuxuu ku shaqeeyaa telefoonka gudihiisa — internet looma baahna. '
                'Model: Meta MMS Somali (VITS/ONNX).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TOP-LEVEL helper: the closure passed to Isolate.run here can only
/// capture these five simple String/double parameters — nothing from the
/// widget State — so the isolate message is always sendable.
Future<String> runTtsInIsolate({
  required String modelPath,
  required String tokensPath,
  required String text,
  required double speed,
  required String outPath,
}) {
  return Isolate.run(() {
    return _runTts(
      modelPath: modelPath,
      tokensPath: tokensPath,
      text: text,
      speed: speed,
      outPath: outPath,
    );
  });
}

/// Runs entirely inside a background isolate.
/// Splits long text into chunks, generates each chunk, concatenates the
/// audio, and writes a single WAV file. Returns the output path.
String _runTts({
  required String modelPath,
  required String tokensPath,
  required String text,
  required double speed,
  required String outPath,
}) {
  sherpa_onnx.initBindings();

  final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
    model: modelPath,
    tokens: tokensPath,
  );
  final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
    vits: vits,
    numThreads: 2,
    debug: false,
    provider: 'cpu',
  );
  final config = sherpa_onnx.OfflineTtsConfig(model: modelConfig);
  final tts = sherpa_onnx.OfflineTts(config);

  try {
    final chunks = _splitText(text, maxLen: 300);

    final allSamples = <double>[];
    var sampleRate = 16000;

    for (final chunk in chunks) {
      final audio = tts.generate(text: chunk, sid: 0, speed: speed);
      sampleRate = audio.sampleRate;
      allSamples.addAll(audio.samples);
      // Short pause (0.25 s of silence) between chunks.
      allSamples.addAll(List.filled(sampleRate ~/ 4, 0.0));
    }

    final samples = Float32List.fromList(allSamples);
    sherpa_onnx.writeWave(
      filename: outPath,
      samples: samples,
      sampleRate: sampleRate,
    );
    return outPath;
  } finally {
    tts.free();
  }
}

/// Split text into sentence-based chunks no longer than [maxLen] chars,
/// so the VITS model stays fast and stable on long text.
List<String> _splitText(String text, {int maxLen = 300}) {
  final sentences = text
      .split(RegExp(r'(?<=[.!?؟\n])\s*'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (sentences.isEmpty) return [text];

  final chunks = <String>[];
  var current = StringBuffer();

  for (final s in sentences) {
    if (current.isNotEmpty && current.length + s.length + 1 > maxLen) {
      chunks.add(current.toString());
      current = StringBuffer();
    }
    // A single very long sentence: hard-split it.
    if (s.length > maxLen) {
      if (current.isNotEmpty) {
        chunks.add(current.toString());
        current = StringBuffer();
      }
      for (var i = 0; i < s.length; i += maxLen) {
        chunks.add(s.substring(i, (i + maxLen).clamp(0, s.length)));
      }
      continue;
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(s);
  }
  if (current.isNotEmpty) chunks.add(current.toString());
  return chunks;
}
