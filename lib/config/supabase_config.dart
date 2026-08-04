class SupabaseConfig {
  static const String url = 'https://rhaajmrgwuodjynwjcwj.supabase.co';
  static const String anonKey = 'sb_publishable_T6M3ZHhUVd6coy1V1Y0Rlg_Dou0c3Yi';

  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' &&
      anonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      url.startsWith('https://');
}
