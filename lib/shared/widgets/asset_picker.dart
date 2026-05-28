import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../core/models/org_asset_model.dart';
import '../../core/repositories/org_assets_repository.dart';

// Retorna o asset selecionado (ou null se cancelado)
Future<OrgAssetModel?> showAssetPicker(BuildContext context) {
  return showModalBottomSheet<OrgAssetModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111118),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _AssetPickerSheet(),
  );
}

class _AssetPickerSheet extends ConsumerWidget {
  const _AssetPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(orgAssetsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
            child: Row(
              children: [
                const Text(
                  'Assets da empresa',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const Spacer(),
                _UploadButton(
                  onUploaded: (asset) => Navigator.of(context).pop(asset),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E1E28), height: 1),
          Expanded(
            child: assetsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4))),
              ),
              data: (assets) => assets.isEmpty
                  ? _EmptyState(
                      onUploaded: (a) => Navigator.of(context).pop(a))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: assets.length,
                      itemBuilder: (_, i) => _AssetTile(
                        asset: assets[i],
                        onTap: () => Navigator.of(context).pop(assets[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetTile extends ConsumerWidget {
  final OrgAssetModel asset;
  final VoidCallback onTap;

  const _AssetTile({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: asset.publicUrl != null
            ? Image.network(
                asset.publicUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ImageFallback(),
              )
            : const _ImageFallback(),
      ),
      title: Text(
        asset.name,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        asset.alias != null
            ? '{{asset:${asset.alias}}}'
            : asset.assetType,
        style: TextStyle(
            fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            size: 18, color: Colors.white.withValues(alpha: 0.25)),
        onPressed: () async {
          await ref.read(orgAssetsProvider.notifier).delete(asset);
        },
      ),
    );
  }
}

class _UploadButton extends ConsumerStatefulWidget {
  final ValueChanged<OrgAssetModel> onUploaded;
  const _UploadButton({required this.onUploaded});

  @override
  ConsumerState<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends ConsumerState<_UploadButton> {
  bool _uploading = false;

  Future<void> _pick() async {
    final picked = await _pickImageFromBrowser();
    if (picked == null) return;

    // Pergunta o alias antes do upload
    final alias = await _askAlias(context, picked.name);
    // alias == null → usuário cancelou o dialog
    if (alias == null) return;

    setState(() => _uploading = true);
    try {
      final asset = await ref.read(orgAssetsProvider.notifier).upload(
            fileName: picked.name,
            bytes: picked.data,
            mimeType: picked.mime,
            alias: alias.isEmpty ? null : alias,
          );
      if (mounted && asset != null) widget.onUploaded(asset);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer upload: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _uploading ? null : _pick,
      icon: _uploading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.upload_rounded, size: 16),
      label: Text(_uploading ? 'Enviando...' : 'Upload'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ValueChanged<OrgAssetModel> onUploaded;
  const _EmptyState({required this.onUploaded});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined,
              size: 40, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            'Nenhum asset ainda',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
          ),
          const SizedBox(height: 16),
          _UploadButton(onUploaded: onUploaded),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: Colors.white.withValues(alpha: 0.06),
      child: Icon(Icons.image_outlined,
          size: 20, color: Colors.white.withValues(alpha: 0.2)),
    );
  }
}

Future<String?> _askAlias(BuildContext context, String fileName) async {
  final defaultAlias = fileName
      .replaceAll(RegExp(r'\.[^.]+$'), '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  final ctrl = TextEditingController(text: defaultAlias);
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF111118),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Alias do asset',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referencie no markdown como {{asset:<alias>}}',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ex: logo, banner, hero',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

// ── File picker (Flutter Web via package:web) ───────────────────────────────

class _PickedFile {
  final String name;
  final Uint8List data;
  final String mime;
  const _PickedFile(
      {required this.name, required this.data, required this.mime});
}

Future<_PickedFile?> _pickImageFromBrowser() async {
  final input =
      web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/png,image/jpeg,image/webp,image/svg+xml,image/gif';

  final completer = Completer<_PickedFile?>();

  input.addEventListener(
    'change',
    (web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.addEventListener(
        'load',
        (web.Event __) {
          final buffer = (reader.result as JSArrayBuffer).toDart;
          completer.complete(_PickedFile(
            name: file.name,
            data: Uint8List.view(buffer),
            mime: file.type.isEmpty ? 'image/png' : file.type,
          ));
        }.toJS,
      );

      reader.addEventListener(
        'error',
        (web.Event __) {
          completer.complete(null);
        }.toJS,
      );

      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  // Clique programático para abrir o dialog de arquivo
  input.click();
  return completer.future;
}
