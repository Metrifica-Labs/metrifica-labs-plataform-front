import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_client.dart' as config;
import 'generation_state.dart';

final generationProvider =
    StateNotifierProvider.autoDispose<GenerationNotifier, GenerationState>(
  (ref) => GenerationNotifier(),
);

class GenerationNotifier extends StateNotifier<GenerationState> {
  GenerationNotifier() : super(const GenerationState());

  http.Client? _client;

  Future<void> generate({
    required String flowSlug,
    required String userMessage,
    String? extraContext,
  }) async {
    _client?.close();
    _client = http.Client();

    state = const GenerationState(status: GenerationStatus.connecting);

    final uri = Uri.parse(
        '${config.supabaseUrl}/functions/v1/run-flow');

    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${config.supabaseAnonKey}'
      ..headers['apikey'] = config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'flow_slug': flowSlug,
        'user_message': userMessage,
        if (extraContext != null && extraContext.isNotEmpty)
          'extra_context': extraContext,
      });

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        state = state.copyWith(
          status: GenerationStatus.error,
          error: 'Erro ${response.statusCode}: $body',
        );
        return;
      }

      String buffer = '';

      await for (final chunk
          in response.stream.transform(utf8.decoder)) {
        if (!mounted) return;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (final line in lines.take(lines.length - 1)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed == 'data: [DONE]') {
            state = state.copyWith(status: GenerationStatus.done);
            return;
          }
          if (!trimmed.startsWith('data: ')) continue;

          try {
            final json =
                jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
            final type = json['type'] as String?;

            switch (type) {
              case 'flow_start':
                state = state.copyWith(
                  status: GenerationStatus.thinking,
                  flowName: json['flow'] as String?,
                );
              case 'thinking':
                state = state.copyWith(
                  status: GenerationStatus.thinking,
                  thinking: state.thinking + (json['text'] as String? ?? ''),
                );
              case 'text':
                state = state.copyWith(
                  status: GenerationStatus.streaming,
                  output: state.output + (json['text'] as String? ?? ''),
                );
              case 'error':
                state = state.copyWith(
                  status: GenerationStatus.error,
                  error: json['message'] as String? ?? 'Erro desconhecido',
                );
                return;
            }
          } catch (_) {
            // linha malformada, ignora
          }
        }
      }

      if (mounted && state.status != GenerationStatus.done) {
        state = state.copyWith(status: GenerationStatus.done);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          status: GenerationStatus.error,
          error: e.toString(),
        );
      }
    }
  }

  void clear() {
    _client?.close();
    _client = null;
    state = const GenerationState();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
