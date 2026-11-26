import 'package:supabase_flutter/supabase_flutter.dart';

class KuaforumMessagingRepository {
  KuaforumMessagingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Mesajlaşmak için giriş yapmalısın.');
    return id;
  }


  Future<String> startBusinessConversation(String businessId) async {
    final result = await _client.rpc(
      'start_business_conversation',
      params: {'p_business_id': businessId},
    );
    if (result is String && result.isNotEmpty) return result;
    throw const PostgrestException(message: 'İşletme sohbeti başlatılamadı.');
  }

  Future<List<Map<String, dynamic>>> searchBusinesses(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final rows = await _client
        .from('businesses')
        .select('id,name,address,logo_url')
        .eq('status', 'active')
        .ilike('name', '%$term%')
        .order('name')
        .limit(20);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<String> startEmployeeConversation(String employeeUserId) async {
    final result = await _client.rpc(
      'start_employee_conversation',
      params: {'p_employee_user_id': employeeUserId},
    );
    if (result is String && result.isNotEmpty) return result;
    throw const PostgrestException(message: 'Sohbet başlatılamadı.');
  }

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final rows = await _client
        .from('conversations')
        .select('id,business_id,employee_id,customer_id,updated_at,'
            'businesses(name),sender_business:businesses!conversations_sender_business_id_fkey(name),employees(display_name,user_id)')
        .order('updated_at', ascending: false);

    if (rows.isEmpty) return const [];

    final profileIds = <String>{};
    for (final row in rows) {
      profileIds.add(row['customer_id'] as String);
      final employee = row['employees'];
      if (employee is Map<String, dynamic> && employee['user_id'] is String) {
        profileIds.add(employee['user_id'] as String);
      }
    }

    final profiles = await _client
        .from('public_profiles')
        .select('id,full_name,avatar_url')
        .inFilter('id', profileIds.toList());
    final profileById = <String, Map<String, dynamic>>{
      for (final profile in profiles)
        profile['id'] as String: Map<String, dynamic>.from(profile),
    };

    final conversationIds = rows.map((row) => row['id'] as String).toList();
    final hiddenRows = await _client.from('message_hidden_for_me')
        .select('message_id').eq('user_id', _userId);
    final hiddenIds = hiddenRows.map((row) => row['message_id'] as String).toSet();
    final messages = await _client
        .from('messages')
        .select('id,conversation_id,body,sender_id,created_at')
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false)
        .limit(500);
    final latestByConversation = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      if (hiddenIds.contains(message['id'] as String)) continue;
      latestByConversation.putIfAbsent(
        message['conversation_id'] as String,
        () => Map<String, dynamic>.from(message),
      );
    }

    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw);
      final employee = row['employees'] is Map
          ? Map<String, dynamic>.from(row['employees'] as Map)
          : <String, dynamic>{};
      final business = row['businesses'] is Map
          ? Map<String, dynamic>.from(row['businesses'] as Map)
          : <String, dynamic>{};
      final senderBusiness = row['sender_business'] is Map
          ? Map<String, dynamic>.from(row['sender_business'] as Map)
          : <String, dynamic>{};
      final customerId = row['customer_id'] as String;
      final employeeUserId = employee['user_id'] as String?;
      final peerIsCustomer = _userId != customerId;
      final peerId = peerIsCustomer ? customerId : employeeUserId;
      final peerProfile = peerId == null ? null : profileById[peerId];
      row['peer_name'] = row['sender_business_id'] != null
          ? (peerIsCustomer
              ? (senderBusiness['name'] as String? ?? peerProfile?['full_name'] as String? ?? 'İşletme')
              : (business['name'] as String? ?? 'İşletme'))
          : (peerIsCustomer
              ? (peerProfile?['full_name'] as String? ?? 'Müşteri')
              : (employee['display_name'] as String? ?? business['name'] as String? ?? 'Çalışan'));
      row['business_name'] = business['name'] as String? ?? 'İşletme';
      row['last_message'] =
          latestByConversation[row['id']]?['body'] as String? ?? 'Sohbet başladı';
      row['last_message_at'] =
          latestByConversation[row['id']]?['created_at'] ?? row['updated_at'];
      return row;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    final hiddenRows = await _client.from('message_hidden_for_me')
        .select('message_id').eq('user_id', _userId);
    final hiddenIds = hiddenRows.map((row) => row['message_id'] as String).toSet();
    final rows = await _client
        .from('messages')
        .select('id,conversation_id,sender_id,body,created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return rows.where((row) => !hiddenIds.contains(row['id'] as String))
        .map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> hideMessageForMe(String messageId) async {
    await _client.from('message_hidden_for_me').upsert(
      {'message_id': messageId, 'user_id': _userId},
      onConflict: 'message_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw const PostgrestException(message: 'Mesaj boş olamaz.');
    }
    if (text.length > 2000) {
      throw const PostgrestException(message: 'Mesaj en fazla 2000 karakter olabilir.');
    }
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _userId,
      'body': text,
    });
  }
}
