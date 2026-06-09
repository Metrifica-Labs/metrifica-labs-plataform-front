import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/organization_provider.dart';
import '../data/copy_chat_notifier.dart';
import '../data/persona_model.dart';
import '../data/personas_repository.dart';

class CopyPage extends ConsumerStatefulWidget {
  const CopyPage({super.key});

  @override
  ConsumerState<CopyPage> createState() => _CopyPageState();
}

class _CopyPageState extends ConsumerState<CopyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: onSurface.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.25),
                      primary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: primary.withValues(alpha: 0.18)),
                ),
                child: Icon(Icons.person_pin_outlined, size: 17, color: primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personagens',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface.withValues(alpha: 0.95),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Construa e gerencie o perfil do seu cliente ideal',
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.4),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Tabs ─────────────────────────────────────────────────────────────
        Container(
          color: isDark ? const Color(0xFF0A0A12) : theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: TabBar(
            controller: _tab,
            labelColor: primary,
            unselectedLabelColor: onSurface.withValues(alpha: 0.4),
            indicatorColor: primary,
            indicatorWeight: 1.5,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 15),
                    SizedBox(width: 6),
                    Text('Personagens'),
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 15),
                    SizedBox(width: 6),
                    Text('Ferramentas'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: onSurface.withValues(alpha: 0.08)),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _PersonasTab(),
              _ToolsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Personas Tab
// ─────────────────────────────────────────────────────────────────────────────

enum _PersonasView { list, chat, edit }

class _PersonasTab extends ConsumerStatefulWidget {
  const _PersonasTab();

  @override
  ConsumerState<_PersonasTab> createState() => _PersonasTabState();
}

class _PersonasTabState extends ConsumerState<_PersonasTab> {
  _PersonasView _view = _PersonasView.list;
  PersonaModel? _editing;
  final _nameController = TextEditingController();
  final _editContentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _editContentController.dispose();
    super.dispose();
  }

  void _openNew() {
    ref.read(avatarChatProvider.notifier).clear();
    _nameController.clear();
    setState(() {
      _view = _PersonasView.chat;
      _editing = null;
    });
  }

  void _openEdit(PersonaModel p) {
    _editing = p;
    _editContentController.text = p.content;
    setState(() => _view = _PersonasView.edit);
  }

  void _back() {
    setState(() {
      _view = _PersonasView.list;
      _editing = null;
    });
  }

  // Usado na view de edição direta (texto já pronto).
  Future<void> _save(String content) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || content.isEmpty) return;
    final org = ref.read(activeOrgProvider);
    if (org == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(personasRepoProvider);
      PersonaModel saved;
      if (_editing != null) {
        saved = await repo.update(
            id: _editing!.id, name: name, content: content);
      } else {
        saved = await repo.create(
            orgId: org.id, name: name, content: content);
      }
      ref.invalidate(personasProvider);
      ref.read(selectedPersonaProvider.notifier).state = saved;
      if (mounted) {
        setState(() {
          _view = _PersonasView.list;
          _editing = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Usado na view de chat: gera a ficha técnica via API antes de salvar.
  Future<void> _generateAndSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final org = ref.read(activeOrgProvider);
    if (org == null) return;

    setState(() => _saving = true);
    try {
      final content =
          await ref.read(avatarChatProvider.notifier).generatePersonaSheet();
      final repo = ref.read(personasRepoProvider);
      final saved =
          await repo.create(orgId: org.id, name: name, content: content);
      ref.invalidate(personasProvider);
      ref.read(selectedPersonaProvider.notifier).state = saved;
      if (mounted) {
        setState(() {
          _view = _PersonasView.list;
          _editing = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar ficha técnica: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PersonaModel p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir personagem'),
        content: Text('Excluir "${p.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(personasRepoProvider).delete(p.id);
    final sel = ref.read(selectedPersonaProvider);
    if (sel?.id == p.id) {
      ref.read(selectedPersonaProvider.notifier).state = null;
    }
    ref.invalidate(personasProvider);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _PersonasView.list => _buildList(),
      _PersonasView.chat => _buildChat(),
      _PersonasView.edit => _buildEditContent(),
    };
  }

  Widget _buildList() {
    final personas = ref.watch(personasProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
          child: Row(
            children: [
              Text(
                'Seus personagens',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openNew,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Novo'),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: personas.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (list) => list.isEmpty
                ? _EmptyPersonas(onCreate: _openNew)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => _PersonaCard(
                      persona: list[i],
                      onEdit: () => _openEdit(list[i]),
                      onDelete: () => _delete(list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildChat() {
    final state = ref.watch(avatarChatProvider);
    final lastContent = state.lastAssistantContent;
    final canSave = lastContent != null;

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return _ChatScaffold(
      headerLeft: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            onPressed: _back,
            tooltip: 'Voltar',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: onSurface.withValues(alpha: 0.1)),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Nome do personagem…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      headerRight: _saving
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gerando ficha…',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            )
          : FilledButton.icon(
              onPressed: canSave
                  ? () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Informe um nome para o personagem')),
                        );
                        return;
                      }
                      _generateAndSave();
                    }
                  : null,
              icon: const Icon(Icons.save_outlined, size: 15),
              label: const Text('Salvar'),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(0, 32),
              ),
            ),
      agentProvider: avatarChatProvider,
      hintText: 'Converse com o agente Jornada do Avatar…',
      emptySuggestions: const [
        ('Iniciar jornada',
            'Quero construir a jornada completa do meu avatar de marketing. Pode começar?'),
        ('Público B2B',
            'Preciso definir o avatar de um produto B2B para gestores de marketing'),
        ('Mercado fitness',
            'Quero criar o avatar de um produto no nicho fitness e emagrecimento'),
      ],
    );
  }

  Widget _buildEditContent() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: _back,
              ),
              Expanded(
                child: TextField(
                  controller: _nameController
                    ..text = _editing?.name ?? '',
                  decoration: const InputDecoration(
                    hintText: 'Nome do personagem…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    isDense: true,
                  ),
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 1.5))
                  : FilledButton(
                      onPressed: () => _save(_editContentController.text),
                      style: FilledButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 12)),
                      child: const Text('Salvar'),
                    ),
            ],
          ),
        ),
        Divider(height: 1, color: onSurface.withValues(alpha: 0.1)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _editContentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.85),
                  height: 1.6),
              decoration: InputDecoration(
                hintText: 'Conteúdo do personagem (markdown)…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: onSurface.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPersonas extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyPersonas({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.18),
                    primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.person_pin_outlined, size: 26, color: primary.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              'Nenhum personagem ainda',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: onSurface.withValues(alpha: 0.75),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Construa o perfil profundo do seu cliente ideal\ncom a Jornada do Avatar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: onSurface.withValues(alpha: 0.4),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Criar personagem'),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final PersonaModel persona;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonaCard({
    required this.persona,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    // Primeira letra do nome para o avatar
    final initials = persona.name.isNotEmpty
        ? persona.name.trim()[0].toUpperCase()
        : '?';

    // Preview limpo: sem markdown e truncado
    final rawPreview = persona.content
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll('\n', ' ')
        .trim();
    final preview = rawPreview.length > 100
        ? '${rawPreview.substring(0, 100)}…'
        : rawPreview;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111119) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar com inicial
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.28),
                        primary.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nome + preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.9),
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: onSurface.withValues(alpha: 0.38),
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Ações
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  tooltip: 'Excluir',
                  style: IconButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.28),
                    padding: const EdgeInsets.all(8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tools Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ToolsTab extends ConsumerStatefulWidget {
  const _ToolsTab();

  @override
  ConsumerState<_ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends ConsumerState<_ToolsTab> {
  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionHistorySheet(
        onLoad: (sessionId, messages) {
          ref.read(toolsChatProvider.notifier).loadSession(sessionId, messages);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personas = ref.watch(personasProvider);
    final selected = ref.watch(selectedPersonaProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      children: [
        // Persona picker strip
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: onSurface.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline,
                        size: 12, color: onSurface.withValues(alpha: 0.45)),
                    const SizedBox(width: 5),
                    Text(
                      'Personagem',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: onSurface.withValues(alpha: 0.45),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: personas.when(
                  loading: () => const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5)),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => list.isEmpty
                      ? Text(
                          'Crie um personagem na aba Personagens',
                          style: TextStyle(
                            fontSize: 12,
                            color: onSurface.withValues(alpha: 0.35),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : DropdownButton<PersonaModel>(
                          value: selected,
                          isExpanded: true,
                          hint: Text(
                            'Selecionar…',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                          underline: const SizedBox.shrink(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: onSurface.withValues(alpha: 0.85),
                          ),
                          items: list
                              .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.name,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (p) => ref
                              .read(selectedPersonaProvider.notifier)
                              .state = p,
                        ),
                ),
              ),
              if (selected != null)
                IconButton(
                  onPressed: () => _showHistory(context),
                  icon: Icon(Icons.history_rounded,
                      size: 17, color: onSurface.withValues(alpha: 0.35)),
                  tooltip: 'Histórico de conversas',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        // Chat
        Expanded(
          child: _ChatScaffold(
            agentProvider: toolsChatProvider,
            hintText: selected == null
                ? 'Selecione um personagem acima para começar…'
                : 'Mensagem para o Copy Tools (${selected.name})…',
            emptySuggestions: selected == null
                ? const []
                : [
                    ('Dualidades',
                        'Analise as dualidades estratégicas do personagem ${selected.name} e construa narrativas de posicionamento'),
                    ('12 Passos',
                        'Crie o plano de conteúdo de 12 passos para o personagem ${selected.name}'),
                    ('Criativos IAD',
                        'Crie anúncios usando a metodologia IAD para o personagem ${selected.name}'),
                    ('Capitão Gancho',
                        'Crie 10 ganchos de vídeo impactantes para o personagem ${selected.name}'),
                    ('VSL completa',
                        'Crie uma Video Sales Letter de alta conversão para o personagem ${selected.name}'),
                    ('Narrative Canvas',
                        'Construa o Pilot Narrative Canvas para o personagem ${selected.name}'),
                  ],
            enabled: selected != null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session history bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SessionHistorySheet extends ConsumerWidget {
  final void Function(String sessionId, List<CopyChatMessage> messages) onLoad;

  const _SessionHistorySheet({required this.onLoad});

  String _preview(List<dynamic> messages) {
    for (final m in messages) {
      if ((m['role'] as String?) == 'user') {
        final text = (m['content'] as String?) ?? '';
        return text.length > 80 ? '${text.substring(0, 80)}…' : text;
      }
    }
    return 'Conversa sem mensagens';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hoje, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(personaSessionsProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111118) : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Histórico de conversas',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onSurface.withValues(alpha: 0.85)),
            ),
          ),
          Divider(height: 1, color: onSurface.withValues(alpha: 0.1)),
          Expanded(
            child: sessions.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Erro ao carregar: $e')),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma conversa salva ainda.',
                        style: TextStyle(
                            fontSize: 13,
                            color: onSurface.withValues(alpha: 0.4)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: onSurface.withValues(alpha: 0.06)),
                      itemBuilder: (ctx, i) {
                        final s = list[i];
                        final rawMsgs =
                            (s['messages'] as List).cast<Map<String, dynamic>>();
                        final preview = _preview(rawMsgs);
                        final date = _formatDate(
                            s['updated_at'] as String?);
                        final msgCount = rawMsgs.length;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          title: Text(
                            preview,
                            style: TextStyle(
                                fontSize: 13,
                                color: onSurface.withValues(alpha: 0.85)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$date · $msgCount mensagens',
                            style: TextStyle(
                                fontSize: 11,
                                color: onSurface.withValues(alpha: 0.4)),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              size: 18,
                              color: onSurface.withValues(alpha: 0.3)),
                          onTap: () {
                            final messages =
                                rawMsgs.map(CopyChatMessage.fromJson).toList();
                            onLoad(s['id'] as String, messages);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chat scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _ChatScaffold extends ConsumerStatefulWidget {
  final StateNotifierProvider<CopyChatNotifier, CopyChatState> agentProvider;
  final String hintText;
  final List<(String, String)> emptySuggestions;
  final Widget? headerLeft;
  final Widget? headerRight;
  final bool enabled;

  const _ChatScaffold({
    required this.agentProvider,
    required this.hintText,
    required this.emptySuggestions,
    this.headerLeft,
    this.headerRight,
    this.enabled = true,
  });

  @override
  ConsumerState<_ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends ConsumerState<_ChatScaffold> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    ref.read(widget.agentProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.agentProvider);
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;

    ref.listen(widget.agentProvider, (prev, next) {
      // só rola ao final quando a geração termina
      if (prev?.isGenerating == true && !next.isGenerating) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        if (widget.headerLeft != null || widget.headerRight != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                if (widget.headerLeft != null)
                  Expanded(child: widget.headerLeft!),
                if (widget.headerRight != null) widget.headerRight!,
              ],
            ),
          ),
          Divider(height: 1, color: outline.withValues(alpha: 0.4)),
        ],
        Expanded(
          child: state.isEmpty
              ? _EmptyChat(
                  suggestions: widget.emptySuggestions,
                  onTap: widget.enabled
                      ? (text) {
                          _controller.text = text;
                          _send();
                        }
                      : null,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: state.messages.length,
                  itemBuilder: (ctx, i) =>
                      _MessageBubble(message: state.messages[i]),
                ),
        ),
        _InputBar(
          controller: _controller,
          focusNode: _focusNode,
          isGenerating: state.isGenerating,
          enabled: widget.enabled,
          hintText: widget.hintText,
          onSend: _send,
          onClear: state.isEmpty
              ? null
              : () => ref.read(widget.agentProvider.notifier).clear(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state with suggestions
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final List<(String, String)> suggestions;
  final void Function(String)? onTap;

  const _EmptyChat({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                size: 28, color: onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text(
              'Selecione um personagem para começar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: primary.withValues(alpha: 0.13)),
                ),
                child: Icon(Icons.auto_awesome_outlined,
                    size: 20, color: primary.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 16),
              Text(
                'O que criamos hoje?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: onSurface.withValues(alpha: 0.8),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escolha uma ferramenta abaixo ou escreva sua solicitação',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.35),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                alignment: WrapAlignment.center,
                children: suggestions
                    .map((s) => _Chip(
                        label: s.$1,
                        onTap: onTap != null ? () => onTap!(s.$2) : null))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _Chip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final active = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.22)
                : onSurface.withValues(alpha: 0.1),
          ),
          color: active
              ? primary.withValues(alpha: 0.05)
              : onSurface.withValues(alpha: 0.03),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active
                ? onSurface.withValues(alpha: 0.7)
                : onSurface.withValues(alpha: 0.3),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble with markdown
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final CopyChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == CopyChatRole.user;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final showCopy = !isUser && !message.isStreaming && message.content.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.draw_outlined,
                  size: 14, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : (isDark
                            ? const Color(0xFF1A1A28)
                            : theme.colorScheme.surface),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isUser ? 14 : 4),
                      topRight: Radius.circular(isUser ? 4 : 14),
                      bottomLeft: const Radius.circular(14),
                      bottomRight: const Radius.circular(14),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: onSurface.withValues(alpha: 0.08)),
                  ),
                  child: message.isStreaming && message.content.isEmpty
                      ? _TypingIndicator()
                      : isUser
                          ? SelectableText(
                              message.content,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: onSurface.withValues(alpha: 0.9),
                                  height: 1.55),
                            )
                          : _MarkdownMessage(
                              text: message.content,
                              onSurface: onSurface,
                            ),
                ),
                if (showCopy)
                  _CopyButton(content: message.content, onSurface: onSurface),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String content;
  final Color onSurface;

  const _CopyButton({required this.content, required this.onSurface});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check_rounded : Icons.copy_outlined,
                size: 13,
                color: widget.onSurface.withValues(alpha: _copied ? 0.6 : 0.35),
              ),
              const SizedBox(width: 4),
              Text(
                _copied ? 'Copiado' : 'Copiar',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.onSurface.withValues(alpha: _copied ? 0.6 : 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkdownMessage extends StatelessWidget {
  final String text;
  final Color onSurface;

  const _MarkdownMessage({required this.text, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final textColor = onSurface.withValues(alpha: 0.85);
    final dimColor = onSurface.withValues(alpha: 0.55);

    final styleSheet = MarkdownStyleSheet(
      p: TextStyle(fontSize: 13, color: textColor, height: 1.6),
      strong: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
      h1: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
      h2: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
      h3: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
      code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: textColor,
          backgroundColor: onSurface.withValues(alpha: 0.07)),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: onSurface.withValues(alpha: 0.3), width: 3),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: TextStyle(fontSize: 13, color: dimColor),
      tableHead: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor),
      tableBody: TextStyle(fontSize: 12, color: textColor),
      tableBorder: TableBorder.all(
          color: onSurface.withValues(alpha: 0.2), width: 0.8),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tableHeadAlign: TextAlign.left,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: onSurface.withValues(alpha: 0.2), width: 1),
        ),
      ),
    );

    return MarkdownBody(
      data: text,
      styleSheet: styleSheet,
      selectable: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final opacity = ((_anim.value + i / 3) % 1.0) < 0.5 ? 1.0 : 0.3;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: opacity,
              child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final bool enabled;
  final String hintText;
  final VoidCallback onSend;
  final VoidCallback? onClear;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.enabled,
    required this.hintText,
    required this.onSend,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: onSurface.withValues(alpha: 0.07))),
        color: isDark ? const Color(0xFF09090F) : theme.scaffoldBackgroundColor,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onClear != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: IconButton(
                onPressed: onClear,
                icon: Icon(Icons.refresh_rounded,
                    size: 15, color: onSurface.withValues(alpha: 0.3)),
                tooltip: 'Nova conversa',
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(7),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: onSurface.withValues(alpha: 0.1)),
              ),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed &&
                      enabled &&
                      !isGenerating) {
                    onSend();
                  }
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: null,
                  enabled: enabled,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: onSurface.withValues(alpha: 0.28)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 10),
                  ),
                  style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.9),
                      height: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: isGenerating
                ? Padding(
                    key: const ValueKey('loading'),
                    padding: const EdgeInsets.only(bottom: 3),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: primary.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : Container(
                    key: const ValueKey('send'),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: enabled
                          ? primary.withValues(alpha: 0.12)
                          : onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: IconButton(
                      onPressed: enabled ? onSend : null,
                      padding: EdgeInsets.zero,
                      tooltip: 'Enviar (Enter)',
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        size: 17,
                        color: enabled
                            ? primary
                            : onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
