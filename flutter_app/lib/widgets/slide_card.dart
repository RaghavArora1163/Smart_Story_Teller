// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/story_models.dart';

class SlideCard extends StatefulWidget {
  final StorySlide slide;
  const SlideCard({super.key, required this.slide});

  @override
  State<SlideCard> createState() => _SlideCardState();
}

class _SlideCardState extends State<SlideCard> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ---- Direct download (no new tab) via Blob ----
  Future<void> _downloadBinary(String url, String filename) async {
    if (!kIsWeb) {
      // Optional: use url_launcher for mobile; for now just notify.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download: $url')),
      );
      return;
    }
    try {
      final req = await html.HttpRequest.request(
        url,
        method: 'GET',
        responseType: 'blob',
        requestHeaders: const {
          // let CORS proceed; your backend already enables CORS
        },
      );
      final blob = req.response as html.Blob;
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: objectUrl)
        ..download = filename
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(objectUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
    });
    _player.setSourceUrl('$kApiBase${widget.slide.audioUrl}');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slide;
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      color: const Color(0xFF111418),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                '$kApiBase${s.imageUrl}',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator()),
                errorBuilder: (c, e, st) => Container(
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.index}. ${s.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(s.text, style: TextStyle(color: Colors.white.withOpacity(.95), height: 1.35)),
                    const SizedBox(height: 12),

                    // Audio panel
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3), spreadRadius: -6)],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              if (_isPlaying) {
                                await _player.pause();
                              } else {
                                await _player.resume();
                              }
                            },
                            icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 34, color: primary),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                inactiveTrackColor: Colors.white24,
                                activeTrackColor: primary,
                              ),
                              child: Slider(
                                min: 0,
                                max: _dur.inMilliseconds <= 0 ? 1.0 : _dur.inMilliseconds.toDouble(),
                                value: _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble(),
                                onChanged: (v) async => _player.seek(Duration(milliseconds: v.toInt())),
                              ),
                            ),
                          ),
                          Text(_fmt(_pos), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Downloads (image + audio) — direct to disk
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: () => _downloadBinary(
                            '$kApiBase${s.imageUrl}',
                            'slide_${s.index.toString().padLeft(2, '0')}.jpg',
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('Download image'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: () => _downloadBinary(
                            '$kApiBase${s.audioUrl}',
                            'slide_${s.index.toString().padLeft(2, '0')}.mp3',
                          ),
                          icon: const Icon(Icons.library_music),
                          label: const Text('Download audio'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
