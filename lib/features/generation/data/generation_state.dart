enum GenerationStatus { idle, connecting, thinking, streaming, done, error }

class GenerationState {
  final GenerationStatus status;
  final String thinking;
  final String output;
  final String? flowName;
  final String? error;

  const GenerationState({
    this.status = GenerationStatus.idle,
    this.thinking = '',
    this.output = '',
    this.flowName,
    this.error,
  });

  bool get isGenerating =>
      status == GenerationStatus.connecting ||
      status == GenerationStatus.thinking ||
      status == GenerationStatus.streaming;

  bool get hasOutput => output.isNotEmpty;
  bool get hasThinking => thinking.isNotEmpty;

  GenerationState copyWith({
    GenerationStatus? status,
    String? thinking,
    String? output,
    String? flowName,
    String? error,
  }) =>
      GenerationState(
        status: status ?? this.status,
        thinking: thinking ?? this.thinking,
        output: output ?? this.output,
        flowName: flowName ?? this.flowName,
        error: error ?? this.error,
      );
}
