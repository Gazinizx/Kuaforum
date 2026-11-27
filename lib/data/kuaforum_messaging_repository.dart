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

  Future<String> startDirectConversation(String targetUserId) async {
    final result = await _client.rpc(
      'start_direct_conversation',
      params: {'p_target_user_id': targetUserId},
    );
    if (result is String && result.isNotEmpty) return result;
    throw const PostgrestException(message: 'Sohbet başlatılamadı.');
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
    final rows = await _client.from('businesses')
        .select('id,name,address,logo_url,owner_id')
        .eq('status', 'active').ilike('name', '%$term%')
        .order('name').limit(20);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> searchAccounts(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final rows = await _client.from('public_profiles')
        .select('id,full_name,account_type,avatar_url')
        .neq('id', _userId).neq('account_type', 'admin')
        .ilike('full_name', '%$term%').order('full_name').limit(30);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<String> startEmployeeConversation(String employeeUserId) =>
      startDirectConversation(employeeUserId);

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final rows = await _client.from('conversations')
        .select('id,updated_at')
        .order('updated_at', ascending: false).limit(200);
    if (rows.isEmpty) return const [];

    final ids = rows.map((row) => row['id'] as String).toList();
    final participants = await _client.from('conversation_participants')
        .select('conversation_id,user_id,account_type,business_id')
        .inFilter('conversation_id', ids);
    final mine = participants.where((p) => p['user_id'] == _userId).toList();
    final peers = participants.where((p) => p['user_id'] != _userId).toList();
    final peerIds = peers.map((p) => p['user_id'] as String).toSet().toList();
    final profileRows = peerIds.isEmpty ? <Map<String, dynamic>>[] :
      await _client.from('public_profiles')
        .select('id,full_name,account_type,avatar_url')
        .inFilter('id', peerIds);
    final profileById = {for (final p in profileRows) p['id'] as String: Map<String,dynamic>.from(p)};

    final businessIds = peers.map((p) => p['business_id'] as String?)
        .whereType<String>().toSet().toList();
    final businesses = businessIds.isEmpty ? <Map<String,dynamic>>[] :
      await _client.from('businesses').select('id,name,logo_url')
        .inFilter('id', businessIds);
    final businessById = {for (final b in businesses) b['id'] as String: Map<String,dynamic>.from(b)};

    final employeeRows = peerIds.isEmpty ? <Map<String,dynamic>>[] :
      await _client.from('employees').select('user_id,display_name,business_id')
        .inFilter('user_id', peerIds);
    final employeeById = {for (final e in employeeRows) e['user_id'] as String: Map<String,dynamic>.from(e)};

    final hiddenRows = await _client.from('message_hidden_for_me')
        .select('message_id').eq('user_id', _userId);
    final hiddenIds = hiddenRows.map((row) => row['message_id'] as String).toSet();
    final messages = await _client.from('messages')
        .select('id,conversation_id,body,sender_id,created_at')
        .inFilter('conversation_id', ids)
        .order('created_at', ascending: false).limit(1000);
    final latest = <String,Map<String,dynamic>>{};
    for (final message in messages) {
      if (!hiddenIds.contains(message['id'] as String)) {
        latest.putIfAbsent(message['conversation_id'] as String,
            () => Map<String,dynamic>.from(message));
      }
    }

    final peerByConversation = {for (final p in peers) p['conversation_id'] as String: p};
    final mineByConversation = {for (final p in mine) p['conversation_id'] as String: p};
    return rows.map((raw) {
      final row = Map<String,dynamic>.from(raw);
      final peer = peerByConversation[row['id']] as Map<String,dynamic>?;
      final own = mineByConversation[row['id']] as Map<String,dynamic>?;
      final peerId = peer?['user_id'] as String?;
      final profile = peerId == null ? null : profileById[peerId];
      final businessId = peer?['business_id'] as String?;
      final business = businessId == null ? null : businessById[businessId];
      final employee = peerId == null ? null : employeeById[peerId];
      final type = peer?['account_type'] ?? profile?['account_type'];
      row['peer_user_id'] = peerId;
      row['peer_account_type'] = type;
      row['peer_name'] = type == 'business_owner'
          ? (business?['name'] ?? profile?['full_name'] ?? 'İşletme')
          : (employee?['display_name'] ?? profile?['full_name'] ?? 'Kullanıcı');
      row['peer_avatar_url'] = business?['logo_url'] ?? profile?['avatar_url'];
      row['my_account_type'] = own?['account_type'];
      row['last_message'] = latest[row['id']]?['body'] ?? 'Sohbet başladı';
      row['last_message_at'] = latest[row['id']]?['created_at'] ?? row['updated_at'];
      return row;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    final hiddenRows = await _client.from('message_hidden_for_me')
        .select('message_id').eq('user_id', _userId);
    final hiddenIds = hiddenRows.map((row) => row['message_id'] as String).toSet();
    final rows = await _client.from('messages')
        .select('id,conversation_id,sender_id,body,created_at')
        .eq('conversation_id', conversationId).order('created_at', ascending: true);
    return rows.where((row) => !hiddenIds.contains(row['id'] as String))
        .map((row) => Map<String,dynamic>.from(row)).toList();
  }

  Future<void> hideMessageForMe(String messageId) async {
    await _client.from('message_hidden_for_me').upsert(
      {'message_id': messageId, 'user_id': _userId},
      onConflict: 'message_id,user_id', ignoreDuplicates: true,
    );
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final text = body.trim();
    if (text.isEmpty) throw const PostgrestException(message: 'Mesaj boş olamaz.');
    if (text.length > 2000) throw const PostgrestException(message: 'Mesaj en fazla 2000 karakter olabilir.');
    await _client.from('messages').insert({
      'conversation_id': conversationId, 'sender_id': _userId, 'body': text,
    });
  }
}
