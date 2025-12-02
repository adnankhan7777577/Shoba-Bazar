import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Storage buckets
  static const String sellerStorageBucket = 'seller-profiles';
  static const String customerStorageBucket = 'customer-profiles';
  static const String productStorageBucket = 'product-images';
}

