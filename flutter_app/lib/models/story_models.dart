class StorySlide {
  final int index;
  final String title;
  final String text;
  final String imageUrl;
  final String audioUrl;

  StorySlide({
    required this.index,
    required this.title,
    required this.text,
    required this.imageUrl,
    required this.audioUrl,
  });

  factory StorySlide.fromJson(Map<String, dynamic> j) => StorySlide(
        index: j['index'] ?? 0,
        title: j['title'] ?? '',
        text: j['text'] ?? '',
        imageUrl: j['image_url'] ?? '',
        audioUrl: j['audio_url'] ?? '',
      );
}

class StoryResponse {
  final String runId;
  final List<StorySlide> slides;
  final String? videoUrl;

  StoryResponse({required this.runId, required this.slides, this.videoUrl});

  factory StoryResponse.fromJson(Map<String, dynamic> j) => StoryResponse(
        runId: j['run_id'] ?? '',
        slides: (j['slides'] as List? ?? [])
            .map((e) => StorySlide.fromJson(e as Map<String, dynamic>))
            .toList(),
        videoUrl: j['video_url'],
      );
}
