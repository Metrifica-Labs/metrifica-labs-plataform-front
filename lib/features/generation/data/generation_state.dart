enum GenerationStatus { idle, connecting, thinking, streaming, done, error }

enum ImageStatus { idle, generating, done, error }

class GenerationState {
  final GenerationStatus status;
  final String thinking;
  final String output;
  final String? flowName;
  final String? error;

  // Geração de imagem
  final ImageStatus imageStatus;
  final String? imageUrl;
  final String? imageError;

  const GenerationState({
    this.status = GenerationStatus.idle,
    this.thinking = '',
    this.output = '',
    this.flowName,
    this.error,
    this.imageStatus = ImageStatus.idle,
    this.imageUrl,
    this.imageError,
  });

  bool get isGenerating =>
      status == GenerationStatus.connecting ||
      status == GenerationStatus.thinking ||
      status == GenerationStatus.streaming;

  bool get hasOutput => output.isNotEmpty;
  bool get hasThinking => thinking.isNotEmpty;

  // Extrai o primeiro bloco de código do output (prompt de imagem gerado pelo LLM)
  String? get extractedImagePrompt {
    final match = RegExp(r'```(?:\w*\n)?([\s\S]+?)```').firstMatch(output);
    return match?.group(1)?.trim();
  }

  bool get hasImagePrompt => extractedImagePrompt != null;

  GenerationState copyWith({
    GenerationStatus? status,
    String? thinking,
    String? output,
    String? flowName,
    String? error,
    ImageStatus? imageStatus,
    String? imageUrl,
    String? imageError,
  }) =>
      GenerationState(
        status: status ?? this.status,
        thinking: thinking ?? this.thinking,
        output: output ?? this.output,
        flowName: flowName ?? this.flowName,
        error: error ?? this.error,
        imageStatus: imageStatus ?? this.imageStatus,
        imageUrl: imageUrl ?? this.imageUrl,
        imageError: imageError ?? this.imageError,
      );
}
