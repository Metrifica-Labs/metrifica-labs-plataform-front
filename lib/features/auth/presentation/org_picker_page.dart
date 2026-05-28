import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            message:
                'Você não tem acesso a nenhuma empresa.\nContate o administrador.',
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
        context
            .go(first != null ? '/flows/${first.slug}' : '/squads/dev-squad');
      }
    });

    // Dispara na primeira build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flows = ref.read(flowsProvider).valueOrNull;
      if (flows != null && context.mounted) {
        ref.read(activeOrgProvider.notifier).setOrg(org);
        final first = flows.firstOrNull;
        context
            .go(first != null ? '/flows/${first.slug}' : '/squads/dev-squad');
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
  int _focusedIndex = 0;
  final FocusNode _keyboardFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selected = widget.orgs.first;
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedIndex = (_focusedIndex + 1) % widget.orgs.length;
        _selected = widget.orgs[_focusedIndex];
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedIndex =
            (_focusedIndex - 1 + widget.orgs.length) % widget.orgs.length;
        _selected = widget.orgs[_focusedIndex];
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _enter();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      body: Focus(
        autofocus: true,
        focusNode: _keyboardFocus,
        onKeyEvent: _handleKey,
        child: Center(
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
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ...widget.orgs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final org = entry.value;
                    return _OrgOption(
                      org: org,
                      selected: _selected.id == org.id,
                      focused: _focusedIndex == index,
                      onTap: () => setState(() {
                        _selected = org;
                        _focusedIndex = index;
                      }),
                    );
                  }),
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
      ),
    );
  }
}

class _OrgOption extends StatelessWidget {
  final OrganizationModel org;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;

  const _OrgOption({
    required this.org,
    required this.selected,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: onSurface.withValues(alpha: 0.04),
          focusColor: primary.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.1)
                  : onSurface.withValues(alpha: 0.03),
              border: Border.all(
                color: focused
                    ? primary.withValues(alpha: 0.75)
                    : selected
                        ? primary.withValues(alpha: 0.5)
                        : outline.withValues(alpha: 0.65),
                width: focused ? 1.5 : 1,
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
                      color:
                          selected ? primary : onSurface.withValues(alpha: 0.4),
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
                              ? onSurface.withValues(alpha: 0.95)
                              : onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                      Text(
                        org.slug,
                        style: TextStyle(
                          fontSize: 11,
                          color: onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: onSurface.withValues(alpha: 0.65)),
          ),
        ),
      ),
    );
  }
}
