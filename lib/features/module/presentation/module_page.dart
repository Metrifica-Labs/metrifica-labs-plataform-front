import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/modules_repository.dart';

class ModulePage extends ConsumerWidget {
  final String slug;
  const ModulePage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moduleBySlugProvider(slug));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar módulo: $e')),
      data: (module) {
        if (module == null) {
          return const Center(child: Text('Módulo não encontrado.'));
        }
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (module.moduleRef != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Módulo ${module.moduleRef}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              Text(
                module.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: module.content != null
                    ? Markdown(
                        data: module.content!,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                          Theme.of(context),
                        ).copyWith(
                          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.7,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                          h1: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          h2: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          h3: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          tableHead: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                          tableBody: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75)),
                          blockquote:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                          code: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text('Este módulo ainda não tem conteúdo.')),
              ),
            ],
          ),
        );
      },
    );
  }
}
