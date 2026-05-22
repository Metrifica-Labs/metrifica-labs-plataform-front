import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'networking_model.dart';

final networkingContactsProvider =
    FutureProvider<List<NetworkingContact>>((ref) async {
  final data = await supabase
      .from('networking_contacts')
      .select()
      .order('created_at', ascending: false);
  return (data as List).map((e) => NetworkingContact.fromJson(e)).toList();
});

final networkingRepoProvider =
    Provider<NetworkingRepository>((ref) => NetworkingRepository());

class NetworkingRepository {
  Future<NetworkingContact> upsert(NetworkingContact c) async {
    final payload =
        c.id.isEmpty ? c.toJson() : {...c.toJson(), 'id': c.id};
    final data = await supabase
        .from('networking_contacts')
        .upsert(payload)
        .select()
        .single();
    return NetworkingContact.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('networking_contacts').delete().eq('id', id);
  }
}
