import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> createAuditLog({
    required String action,
    required String target,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final String actor = user?.email ?? 'anonymous_scholar';

      await _supabase.from('audit_logs').insert({
        'actor': actor,
        'action': action,
        'target': target,
        'ip_address': 'mobile_app',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('ℹ️ [Audit Log Success]: $action -> $target');
    } catch (e) {
      debugPrint('⚠️ [Audit Log Error]: $e');
    }
  }
}
