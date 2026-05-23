import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proposal_template_model.dart';
import '../supabase/supabase_client.dart';

/// Retorna apenas os templates associados ao flow.
/// Se nenhum for encontrado, retorna lista vazia (sem mostrar templates).
final proposalTemplatesProvider =
    FutureProvider.family<List<ProposalTemplateModel>, String>(
        (ref, flowSlug) async {
  final data = await supabase
      .from('proposal_templates')
      .select()
      .eq('flow_slug', flowSlug)
      .order('created_at');
  return (data as List).map((e) => ProposalTemplateModel.fromJson(e)).toList();
});
