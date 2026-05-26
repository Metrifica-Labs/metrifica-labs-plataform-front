import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/organization_model.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/repositories/flows_repository.dart';

class OrgPickerPage extends ConsumerWidget {
  const OrgPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrgsProvider);

    return orgsAsync.when(
      loading: () => const _LoadingScreen(),
      error: (e, _) => _ErrorScreen(message: e.toString()),
      data: (orgs) {
        if (orgs.isEmpty) {
          return const _ErrorScreen(
            message: 'Você não tem acesso a nenhuma empresa.\nContate o administrador.',
          );
        }
        if (orgs.length == 1) {
          return _AutoSelect(org: orgs.first);
        }
        return _OrgPickerScreen(orgs: orgs);
      },
    );
  }
}

// Auto-seleciona a única org e redireciona para o app
class _AutoSelect extends ConsumerWidget {
  final OrganizationModel org;
  const _AutoSelect({required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(flowsProvider, (_, flowsAsync) {
      final flows = flowsAsync.valueOrNull;
      if (flows == null) return;
      ref.read(activeOrgProvider.notifier).setOrg(org);
      final first = flows.firstOrNull;
      if (context.mounted) {
        context.go(first != null ? '/flows/${first.slug}' : '/squads/dev-squad');
      }
    });

    // Dispara na primeira build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flows = ref.read(flowsProvider).valueOrNull;
      if (flows != null && context.mounted) {
        ref.read(activeOrgProvider.notifier).setOrg(org);
        final first = flows.firstOrNull;
        context.go(first != null ? '/flows/${first.slug}' : '/squads/dev-squad');
      }
    });

    return const _LoadingScreen();
  }
}

class _OrgPickerScreen extends ConsumerStatefulWidget {
  final List<OrganizationModel> orgs;
  const _OrgPickerScreen({required this.orgs});

  @override
  ConsumerState<_OrgPickerScreen> createState() => _OrgPickerScreenState();
}

class _OrgPickerScreenState extends ConsumerState<_OrgPickerScreen> {
  late OrganizationModel _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.orgs.first;
  }

  void _enter() {
    ref.read(activeOrgProvider.notifier).setOrg(_selected);
    final flows = ref.read(flowsProvider).valueOrNull ?? [];
    final first = flows.firstOrNull;
    context.go(first != null ? '/flows/${first.slug}' : '/squads/dev-squad');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, theme.colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Selecione a empresa',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Você tem acesso a mais de uma empresa.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ...widget.orgs.map((org) => _OrgOption(
                      org: org,
                      selected: _selected.id == org.id,
                      onTap: () => setState(() => _selected = org),
                    )),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _enter,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Entrar',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrgOption extends StatelessWidget {
  final OrganizationModel org;
  final bool selected;
  final VoidCallback onTap;

  const _OrgOption({
    required this.org,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? primary : Colors.white.withValues(alpha: 0.3),
                    width: selected ? 5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      org.slug,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}
