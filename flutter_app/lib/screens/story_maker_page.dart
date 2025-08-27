// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:async';
import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../config.dart';
import '../models/story_models.dart';
import '../widgets/slide_card.dart';

class StoryMakerPage extends StatefulWidget {
  const StoryMakerPage({super.key});

  @override
  State<StoryMakerPage> createState() => _StoryMakerPageState();
}

class _StoryMakerPageState extends State<StoryMakerPage> {
  final _prompt = TextEditingController();
  int _slides = 6;
  String _lang = 'en';

  bool _loading = false;
  String? _error;

  StoryResponse? _story;
  VideoPlayerController? _videoCtrl;

  // progress state
  String? _runId;
  Timer? _pollTimer;
  double _progress = 0.0; // 0..1
  String _progressMsg = "Starting…";

  bool get _hasSlides => _story?.slides.isNotEmpty == true;

  @override
  void dispose() {
    _prompt.dispose();
    _pollTimer?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ---------- Async flow: start → poll progress → fetch result ----------
  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    final p = _prompt.text.trim();
    if (p.isEmpty) {
      setState(() => _error = 'Please enter a prompt.');
      return;
    }

    // reset UI
    setState(() {
      _loading = true;
      _error = null;
      _story = null;
      _runId = null;
      _progress = 0;
      _progressMsg = "Starting…";
      _videoCtrl?.dispose();
      _videoCtrl = null;
    });

    try {
      // 1) Start async job
      final startRes = await http.post(
        Uri.parse('$kApiBase/api/generate_async'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"prompt": p, "slides": _slides, "lang": _lang}),
      );
      if (startRes.statusCode >= 300) {
        throw Exception('Failed to start: ${startRes.body}');
      }
      final startJson = jsonDecode(startRes.body) as Map<String, dynamic>;
      final runId = startJson['run_id'] as String;
      setState(() => _runId = runId);

      // 2) Poll progress
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _pollProgress());

      // 3) Wait until done → fetch result
      await _waitForCompletion(runId);
      await _fetchResult(runId);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
      _pollTimer?.cancel();
    }
  }

  Future<void> _pollProgress() async {
    if (_runId == null) return;
    try {
      final r = await http.get(Uri.parse('$kApiBase/api/progress/$_runId'));
      if (r.statusCode >= 300) return;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final percent = (j['percent'] as num?)?.toDouble() ?? 0.0;
      final msg = (j['message'] as String?) ?? '';
      if (!mounted) return;
      setState(() {
        _progress = percent / 100.0;
        _progressMsg = msg.isEmpty ? 'Working…' : msg;
      });
    } catch (_) {
      // ignore transient polling errors
    }
  }

  Future<void> _waitForCompletion(String runId) async {
    // simple loop that checks "done" flag
    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final r = await http.get(Uri.parse('$kApiBase/api/progress/$runId'));
      if (r.statusCode >= 300) break;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['error'] != null) {
        throw Exception('Backend error: ${j['error']}');
      }
      if (j['done'] == true) {
        if (!mounted) return;
        setState(() {
          _progress = 1.0;
          _progressMsg = "Finalizing…";
        });
        break;
      }
    }
  }

  Future<void> _fetchResult(String runId) async {
    // fetch final story JSON and render
    for (;;) {
      final r = await http.get(Uri.parse('$kApiBase/api/result/$runId'));
      if (r.statusCode == 202) {
        await Future.delayed(const Duration(milliseconds: 400));
        continue; // still pending
      }
      if (r.statusCode >= 300) {
        throw Exception('Failed to fetch result: ${r.body}');
      }
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final story = _storyFromJson(j); // map to your models
      if (!mounted) return;
      setState(() => _story = story);

      // init video player if available
      if (story.videoUrl != null && story.videoUrl!.isNotEmpty) {
        final ctrl = VideoPlayerController.networkUrl(
          Uri.parse('$kApiBase${story.videoUrl}'),
        );
        await ctrl.initialize();
        ctrl.setLooping(false);
        if (!mounted) return;
        setState(() => _videoCtrl = ctrl);
      }
      break;
    }
  }

  // Map API result → your model classes
  StoryResponse _storyFromJson(Map<String, dynamic> j) {
  final slides = (j['slides'] as List<dynamic>).map((e) {
    final m = e as Map<String, dynamic>;
    return StorySlide(
      index: (m['index'] as num).toInt(),
      title: m['title'] as String? ?? '',
      text: m['text'] as String? ?? '',
      imageUrl: m['image_url'] as String? ?? '',
      audioUrl: m['audio_url'] as String? ?? '',
    );
  }).toList();

  return StoryResponse(
    // If your model expects non-nullable String, keep the `?? ''`.
    // If you later switch to nullable in the model, you can remove the fallback.
    runId: (j['run_id'] as String?) ?? '',
    videoUrl: j['video_url'] as String?,
    slides: slides,
  );
}


  // ---- Direct download (no new tab) via Blob ----
  Future<void> _downloadBinary(String url, String filename) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download: $url')));
      return;
    }
    try {
      final req = await html.HttpRequest.request(
        url,
        method: 'GET',
        responseType: 'blob',
      );
      final blob = req.response as html.Blob;
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: objectUrl)
        ..download = filename
        ..style.display = 'none';
      html.document.body!.append(a);
      a.click();
      a.remove();
      html.Url.revokeObjectUrl(objectUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0F12),
      appBar: AppBar(
        title: const Text('Story Teller'),
        backgroundColor: const Color(0xFF171A1F),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input card
            Card(
              color: const Color(0xFF171A1F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Prompt',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _prompt,
                      minLines: 3,
                      maxLines: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g., A shy cat learns to fly a hot-air balloon over Jaipur at sunrise',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(.5)),
                        filled: true,
                        fillColor: const Color(0xFF0F1216),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2F36)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Labeled(
                            label: 'Slides',
                            child: DropdownButtonFormField<int>(
                              value: _slides,
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5')),
                                DropdownMenuItem(value: 6, child: Text('6')),
                              ],
                              onChanged: (v) => setState(() => _slides = v ?? 6),
                              decoration: _ddDecoration(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Labeled(
                            label: 'Voice / Language',
                            child: DropdownButtonFormField<String>(
                              value: _lang,
                              items: const [
                                DropdownMenuItem(value: 'en', child: Text('English (realistic)')),
                                DropdownMenuItem(value: 'hi', child: Text('Hindi (realistic)')),
                              ],
                              onChanged: (v) => setState(() => _lang = v ?? 'en'),
                              decoration: _ddDecoration(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _generate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_loading ? 'Working…' : 'Generate Story'),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
            ),

            // Live progress bar
            if (_loading && _runId != null) ...[
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF1F2937),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Generating…', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toStringAsFixed(0)}% — $_progressMsg',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Results (slides + video) – unchanged except for download button using Blob
            if (_story != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Slides',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),

              if (_hasSlides)
                CarouselSlider(
                  items: _story!.slides
                      .map((s) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: SlideCard(slide: s),
                          ))
                      .toList(),
                  options:  CarouselOptions(
                    enlargeCenterPage: true,
                    enableInfiniteScroll: false,
                    viewportFraction: 0.82,
                  ),
                )
              else
                const Text('No slides available for this run.', style: TextStyle(color: Colors.white70)),

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Video',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),

              if (_videoCtrl != null && _videoCtrl!.value.isInitialized)
                Card(
                  color: const Color(0xFF1F2937),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoCtrl!.value.aspectRatio,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: VideoPlayer(_videoCtrl!),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _VideoControlsBelow(controller: _videoCtrl!),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _story!.videoUrl == null
                                ? null
                                : () => _downloadBinary(
                                      '$kApiBase${_story!.videoUrl!}',
                                      'story_${_runId ?? DateTime.now().millisecondsSinceEpoch}.mp4',
                                    ),
                            icon: const Icon(Icons.file_download),
                            label: const Text('Download MP4'),
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Text(
                  'Video is not available (ffmpeg missing on backend or generation failed).',
                  style: TextStyle(color: Colors.white70),
                ),

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _ddDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0F1216),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2F36)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF9AA7B6), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _VideoControlsBelow extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControlsBelow({required this.controller});

  @override
  State<_VideoControlsBelow> createState() => _VideoControlsBelowState();
}

class _VideoControlsBelowState extends State<_VideoControlsBelow> {
  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final pos = c.value.position;
    final dur = c.value.duration;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 3),
            spreadRadius: -6,
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            color: primary,
            onPressed: () async {
              if (c.value.isPlaying) {
                await c.pause();
              } else {
                await c.play();
              }
              if (mounted) setState(() {});
            },
            icon: Icon(
              c.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              size: 32,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: primary,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                min: 0.0,
                max: (dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0),
                value: pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                onChanged: (v) async => c.seekTo(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          Text(
            '${_fmt(pos)} / ${_fmt(dur)}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => c.seekTo(Duration.zero),
            icon: const Icon(Icons.replay, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
