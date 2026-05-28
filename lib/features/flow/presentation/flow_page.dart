import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/flows_repository.dart';
import '../../generation/presentation/generation_panel.dart';

class FlowPage extends ConsumerWidget {
  final String slug;
  const FlowPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowAsync = ref.watch(flowBySlugProvider(slug));

    return flowAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (flow) {
        if (flow == null) {
          return const Center(child: Text('Flow não encontrado.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                flow.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
              ),
              if (flow.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  flow.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              GenerationPanel(flowSlug: flow.slug),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
