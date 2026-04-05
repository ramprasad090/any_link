import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Token counts and estimated cost for an LLM response.
class LLMUsage {
  final int promptTokens;
  final int completionTokens;
  final double? estimatedCost;

  const LLMUsage({
    required this.promptTokens,
    required this.completionTokens,
    this.estimatedCost,
  });
}

/// A tool/function call detected mid-stream by the LLM.
class LLMToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  const LLMToolCall({required this.name, required this.arguments});
}

/// A single streamed token from an LLM completion API.
class LLMToken {
  final String text;
  final String? finishReason;
  final LLMUsage? usage;
  final LLMToolCall? toolCall;

  const LLMToken({
    required this.text,
    this.finishReason,
    this.usage,
    this.toolCall,
  });
}

/// Streams LLM token responses from OpenAI, Anthropic, Gemini, or any
/// compatible API.
///
/// Parses `data: {"choices":[{"delta":{"content":"..."}}]}` (OpenAI) and
/// `data: {"type":"content_block_delta","delta":{"text":"..."}}` (Anthropic).
///
/// ```dart
/// final llm = LLMStreamClient();
/// final stream = llm.streamCompletion(
///   'https://api.openai.com/v1/chat/completions',
///   headers: {'Authorization': 'Bearer $key'},
///   body: {
///     'model': 'gpt-4',
///     'stream': true,
///     'messages': [{'role': 'user', 'content': 'Hello'}],
///   },
/// );
///
/// await for (final token in stream) {
///   stdout.write(token.text);
/// }
/// ```
class LLMStreamClient {
  HttpClient? _httpClient;

  Stream<LLMToken> streamCompletion(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async* {
    _httpClient = HttpClient();
    final uri = Uri.parse(url);
    final request = await _httpClient!.openUrl('POST', uri);

    request.headers.contentType = ContentType.json;
    request.headers.set('Accept', 'text/event-stream');
    headers?.forEach((k, v) => request.headers.set(k, v));

    final bodyBytes = utf8.encode(jsonEncode(body));
    request.add(bodyBytes);
    final response = await request.close();

    await for (final line in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6).trim();
      if (data == '[DONE]') break;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final token = _parse(json);
        if (token != null) yield token;
      } catch (_) {
        continue;
      }
    }

    _httpClient?.close();
  }

  LLMToken? _parse(Map<String, dynamic> json) {
    // OpenAI format: {"choices":[{"delta":{"content":"..."},"finish_reason":null}]}
    if (json.containsKey('choices')) {
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final choice = choices.first as Map<String, dynamic>;
      final delta = choice['delta'] as Map<String, dynamic>? ?? {};
      final content = delta['content'] as String? ?? '';
      final finishReason = choice['finish_reason'] as String?;
      final toolCalls = delta['tool_calls'] as List?;

      LLMToolCall? toolCall;
      if (toolCalls != null && toolCalls.isNotEmpty) {
        final tc = toolCalls.first as Map<String, dynamic>;
        final fn = tc['function'] as Map<String, dynamic>? ?? {};
        toolCall = LLMToolCall(
          name: fn['name'] as String? ?? '',
          arguments: _parseArgs(fn['arguments'] as String? ?? '{}'),
        );
      }

      return LLMToken(text: content, finishReason: finishReason, toolCall: toolCall);
    }

    // Anthropic format: {"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
    if (json['type'] == 'content_block_delta') {
      final delta = json['delta'] as Map<String, dynamic>? ?? {};
      final text = delta['text'] as String? ?? '';
      return LLMToken(text: text);
    }

    // Usage event (Anthropic): {"type":"message_delta","usage":{"output_tokens":42}}
    if (json['type'] == 'message_delta') {
      final usage = json['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        return LLMToken(
          text: '',
          finishReason: 'stop',
          usage: LLMUsage(
            promptTokens: 0,
            completionTokens: usage['output_tokens'] as int? ?? 0,
          ),
        );
      }
    }

    return null;
  }

  Map<String, dynamic> _parseArgs(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void close() => _httpClient?.close(force: true);
}
