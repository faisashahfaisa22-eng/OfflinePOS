import 'package:supabase_flutter/supabase_flutter.dart';

/// Transport only: does NOT apply remote operations to the local database.
///
/// The server migration must be deployed separately. Callers must encrypt
/// operation payloads before enqueueing them; no plaintext business rows.
class DeviceSyncTransport {
  const DeviceSyncTransport(this.client);

  final SupabaseClient client;

  String get _owner {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to cloud before syncing.');
    return id;
  }

  /// Insert is idempotent for the same operation ID. An operation must never
  /// be regenerated with a new ID during a retry.
  Future<void> pushEncrypted({
    required String operationId,
    required String deviceId,
    required int deviceSequence,
    required String entityType,
    required String entityId,
    required String operationKind,
    required Map<String, dynamic> encryptedPayload,
  }) async {
    if (deviceSequence <= 0) {
      throw ArgumentError.value(deviceSequence, 'deviceSequence');
    }
    if (encryptedPayload['enc'] != 'aes-gcm-256' ||
        encryptedPayload['iv'] is! String ||
        encryptedPayload['ct'] is! String) {
      throw ArgumentError('Sync payload must be AES-GCM encrypted.');
    }
    await client.from('qamvio_sync_operations').upsert({
      'owner_uid': _owner,
      'operation_id': operationId,
      'device_id': deviceId,
      'device_sequence': deviceSequence,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation_kind': operationKind,
      'payload': encryptedPayload,
    }, onConflict: 'owner_uid,operation_id', ignoreDuplicates: true);
  }

  /// Fetch a deterministic page after a previously acknowledged operation.
  /// Cursor is acknowledged only AFTER the caller has durably applied rows.
  /// The pair (created_at, operation_id) is used to break timestamp ties.
  Future<List<Map<String, dynamic>>> pullPage({
    DateTime? afterTime,
    String? afterOperationId,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 500) {
      throw RangeError.range(limit, 1, 500, 'limit');
    }
    if ((afterTime == null) != (afterOperationId == null)) {
      throw ArgumentError('Cursor time and ID must both be set or absent.');
    }
    var query = client
        .from('qamvio_sync_operations')
        .select('operation_id,device_id,device_sequence,entity_type,entity_id,operation_kind,payload,created_at')
        .eq('owner_uid', _owner);
    if (afterTime != null) {
      final stamp = afterTime.toUtc().toIso8601String();
      // Supabase/PostgREST OR filter for lexicographic composite cursor.
      query = query.or('created_at.gt.$stamp,and(created_at.eq.$stamp,operation_id.gt.$afterOperationId)');
    }
    final rows = await query
        .order('created_at', ascending: true)
        .order('operation_id', ascending: true)
        .limit(limit);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }
}
