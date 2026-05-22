import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'event_model.dart';

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final data = await supabase
      .from('events')
      .select()
      .order('date', ascending: false);
  return (data as List).map((e) => Event.fromJson(e)).toList();
});

final eventsRepoProvider =
    Provider<EventsRepository>((ref) => EventsRepository());

class EventsRepository {
  Future<Event> upsert(Event e) async {
    final payload =
        e.id.isEmpty ? e.toJson() : {...e.toJson(), 'id': e.id};
    final data =
        await supabase.from('events').upsert(payload).select().single();
    return Event.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('events').delete().eq('id', id);
  }
}
