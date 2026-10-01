import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to a model straight from the device. No server of ours in between.
abstract class AiClient {
  static const timeout = Duration(seconds: 45);

  static AiClient of(AiConfig c, String key) => switch (c.provider) {
        Provider.groq => OpenAiCompatible('https://api.groq.com/openai/v1', key, c.model),
        Provider.gemini => Gemini(key, c.model),
        Provider.custom => OpenAiCompatible(_trimSlash(c.baseUrl), key, c.model),
      };

  /// Sends a system + user prompt and returns the parsed JSON object.
  Future<Map<String, dynamic>> json(String system, String user);

  /// Model ids this key can use. Doubles as the key check.
  Future<List<String>> models();
}

String _trimSlash(String s) => s.trim().replaceAll(RegExp(r'/+$'), '');

/// Groq, OpenRouter, Ollama, LM Studio, vLLM… anything speaking /chat/completions.
class OpenAiCompatible extends AiClient {
  OpenAiCompatible(this.base, this.key, this.model);

  final String base;
  final String key;
  final String model;
  bool _jsonMode = true;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (key.isNotEmpty) 'Authorization': 'Bearer $key',
      };

  @override
  Future<Map<String, dynamic>> json(String system, String user) async {
    final body = {
      'model': model,
      'temperature': 0,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      if (_jsonMode) 'response_format': {'type': 'json_object'},
    };
    final res = await _send(() => http.post(Uri.parse('$base/chat/completions'),
        headers: _headers, body: jsonEncode(body)));
    // Some local servers reject response_format; retry once without it.
    if (res.statusCode == 400 && _jsonMode && res.body.contains('response_format')) {
      _jsonMode = false;
      return json(system, user);
    }
    final data = _decode(res);
    final text = (data['choices'] as List?)?.firstOrNull?['message']?['content'] as String?;
    return extractJson(text);
  }

  @override
  Future<List<String>> models() async {
    final res = await _send(() => http.get(Uri.parse('$base/models'), headers: _headers));
    final data = _decode(res);
    final ids = [for (final m in (data['data'] as List? ?? [])) m['id'] as String];
    return ids.where(_isChatModel).toList()..sort();
  }
}

class Gemini extends AiClient {
  Gemini(this.key, this.model);

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  final String key;
  final String model;

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'x-goog-api-key': key};

  @override
  Future<Map<String, dynamic>> json(String system, String user) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        // Thinking adds seconds and little for this task on Flash.
        if (model.contains('2.5-flash')) 'thinkingConfig': {'thinkingBudget': 0},
      },
    };
    final res = await _send(() => http.post(
        Uri.parse('$_base/models/$model:generateContent'),
        headers: _headers,
        body: jsonEncode(body)));
    final data = _decode(res);
    final parts = (data['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?;
    final text = parts?.map((p) => p['text'] ?? '').join();
    return extractJson(text);
  }

  @override
  Future<List<String>> models() async {
    final res = await _send(
        () => http.get(Uri.parse('$_base/models?pageSize=200'), headers: _headers));
    final data = _decode(res);
    final out = <String>[];
    for (final m in (data['models'] as List? ?? [])) {
      final methods = (m['supportedGenerationMethods'] as List?) ?? const [];
      final id = (m['name'] as String).replaceFirst('models/', '');
      if (methods.contains('generateContent') && id.startsWith('gemini') && _isChatModel(id)) {
        out.add(id);
      }
    }
    return out..sort();
  }
}

bool _isChatModel(String id) {
  const skip = ['whisper', 'tts', 'guard', 'embed', 'playai', 'orpheus', 'image', 'live',
      'audio', 'vision-preview', 'aqa', 'compound', 'distil'];
  final l = id.toLowerCase();
  return !skip.any(l.contains);
}

/// Best default from what the key can see.
String pickModel(Provider p, List<String> available) {
  const prefs = {
    Provider.groq: [
      'llama-3.3-70b-versatile',
      'openai/gpt-oss-120b',
      'moonshotai/kimi-k2-instruct',
      'meta-llama/llama-4-maverick-17b-128e-instruct',
      'openai/gpt-oss-20b',
    ],
    Provider.gemini: ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.5-flash-lite'],
    Provider.custom: <String>[],
  };
  for (final m in prefs[p]!) {
    if (available.contains(m)) return m;
  }
  return available.isEmpty ? '' : available.first;
}

Future<http.Response> _send(Future<http.Response> Function() req) async {
  try {
    return await req().timeout(AiClient.timeout);
  } on TimeoutException {
    throw const AiException('The model took too long. Try again, or pick a faster model.');
  } catch (e) {
    if (e is AiException) rethrow;
    throw const AiException("Couldn't reach the AI. Check your connection or endpoint.");
  }
}

Map<String, dynamic> _decode(http.Response res) {
  Map<String, dynamic>? body;
  try {
    body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  } catch (_) {}
  if (res.statusCode >= 200 && res.statusCode < 300 && body != null) return body;

  final err = body?['error'];
  final msg = (err is Map ? err['message'] : err)?.toString() ?? '';
  switch (res.statusCode) {
    case 400 when msg.toLowerCase().contains('api key'):
    case 401:
    case 403:
      throw const AiException('That key was rejected. Double-check it in settings.');
    case 404:
      throw const AiException('Model or endpoint not found. Pick another model.');
    case 429:
      throw const AiException('Rate limit hit on the free tier. Wait a moment, or switch model.');
  }
  if (res.statusCode >= 500) {
    throw const AiException('The AI service is having trouble. Try again shortly.');
  }
  throw AiException(msg.isEmpty ? 'Unexpected reply (${res.statusCode}).' : _short(msg));
}

String _short(String s) => s.length > 160 ? '${s.substring(0, 160)}…' : s;

/// Pulls the first JSON object out of a model reply, tolerating code fences
/// and `<think>` blocks.
Map<String, dynamic> extractJson(String? text) {
  if (text == null || text.trim().isEmpty) {
    throw const AiException('The model sent an empty reply. Try again.');
  }
  final cleaned = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const AiException("The model's reply wasn't readable. Try again.");
  }
  try {
    return jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    throw const AiException("The model's reply wasn't readable. Try again.");
  }
}
