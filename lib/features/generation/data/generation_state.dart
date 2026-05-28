enum GenerationStatus { idle, connecting, thinking, streaming, done, error }

enum ImageStatus { idle, generating, done, error }

class ChatTurn {
  final String userMessage;
  final String output;
  const ChatTurn({required this.userMessage, required this.output});
}

class GenerationState {
  final GenerationStatus status;
  final String thinking;
  final String output;
  final String? flowName;
  final String? error;

  // Chat history: turns that completed before the current one
  final List<ChatTurn> turns;
  // The user message that triggered the current output
  final String currentUserMessage;

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
    this.turns = const [],
    this.currentUserMessage = '',
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
  bool get isRefinement => turns.isNotEmpty;

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
    List<ChatTurn>? turns,
    String? currentUserMessage,
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
        turns: turns ?? this.turns,
        currentUserMessage: currentUserMessage ?? this.currentUserMessage,
        imageStatus: imageStatus ?? this.imageStatus,
        imageUrl: imageUrl ?? this.imageUrl,
        imageError: imageError ?? this.imageError,
      );
}
