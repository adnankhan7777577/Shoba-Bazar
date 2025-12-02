import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInit {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://mfavkupfimvttobxknwy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1mYXZrdXBmaW12dHRvYnhrbnd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI0MDg0MzksImV4cCI6MjA3Nzk4NDQzOX0.oMmPaQS5Ki1d5DW9Sfv9Q34EqXOYWvz1qMy6_JmV1kQ',
    );
  }
}

