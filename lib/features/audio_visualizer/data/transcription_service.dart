import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_client.dart' as config;
import 'captions.dart';

/// Chama a edge function `transcribe-audio` (proxy para o serviço Whisper
/// próprio) e devolve as legendas já parseadas.
Future<Captions> transcribeAudio(Uint8List bytes, String mimeType) async {
  final uri = Uri.parse('${config.supabaseUrl}/functions/v1/transcribe-audio');
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer ${config.supabaseAnonKey}',
      'apikey': config.supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'audio_base64': base64Encode(bytes),
      'mime_type': mimeType,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Erro ${response.statusCode}: ${response.body}');
  }

  return Captions.parse(response.body);
}
