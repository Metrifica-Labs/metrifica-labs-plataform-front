import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_client.dart' as config;

enum ToolTestStatus { idle, running, pass, fail }

class ToolTestResult {
  final ToolTestStatus status;
  final String? message;
  final int? durationMs;

  const ToolTestResult({
    this.status = ToolTestStatus.idle,
    this.message,
    this.durationMs,
  });
}

class CalibrationState {
  final Map<String, ToolTestResult> results;
  final bool isRunningAll;

  const CalibrationState({
    this.results = const {},
    this.isRunningAll = false,
  });

  CalibrationState copyWith({
    Map<String, ToolTestResult>? results,
    bool? isRunningAll,
  }) =>
      CalibrationState(
        results: results ?? this.results,
        isRunningAll: isRunningAll ?? this.isRunningAll,
      );

  ToolTestResult resultFor(String toolName) =>
      results[toolName] ?? const ToolTestResult();
}

final calibrationProvider =
    StateNotifierProvider.autoDispose<CalibrationNotifier, CalibrationState>(
  (ref) => CalibrationNotifier(),
);

class CalibrationNotifier extends StateNotifier<CalibrationState> {
  CalibrationNotifier() : super(const CalibrationState());

  Future<void> testTool(String toolName) async {
    state = state.copyWith(
      results: {
        ...state.results,
        toolName: const ToolTestResult(status: ToolTestStatus.running),
      },
    );

    try {
      final uri = Uri.parse(
          '${config.supabaseUrl}/functions/v1/calibrate-tools');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${config.supabaseAnonKey}',
          'apikey': config.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'tool_name': toolName}),
      );

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = json['ok'] as bool? ?? false;
      state = state.copyWith(
        results: {
          ...state.results,
          toolName: ToolTestResult(
            status: ok ? ToolTestStatus.pass : ToolTestStatus.fail,
            message: json['message'] as String?,
            durationMs: json['duration_ms'] as int?,
          ),
        },
      );
    } catch (e) {
      state = state.copyWith(
        results: {
          ...state.results,
          toolName: ToolTestResult(
            status: ToolTestStatus.fail,
            message: e.toString(),
          ),
        },
      );
    }
  }

  Future<void> testAll(List<String> toolNames) async {
    state = state.copyWith(isRunningAll: true);
    final unique = toolNames.toSet().toList();
    for (final tool in unique) {
      if (!mounted) return;
      await testTool(tool);
    }
    if (mounted) state = state.copyWith(isRunningAll: false);
  }

  void reset() => state = const CalibrationState();
}
