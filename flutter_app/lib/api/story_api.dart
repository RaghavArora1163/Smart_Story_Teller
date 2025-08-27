import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/story_models.dart';

class StoryApi {
  static Future<StoryResponse> generate({
    required String prompt,
    int slides = 6,
    String lang = 'en',
  }) async {
    final uri = Uri.parse('$kApiBase/api/generate');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt, 'slides': slides, 'lang': lang}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return StoryResponse.fromJson(data);
  }
}
