import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// Armazenados em main() antes de Supabase.initialize()
String supabaseUrl = '';
String supabaseAnonKey = '';
