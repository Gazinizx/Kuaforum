import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class KuaforumFeedPost {
  const KuaforumFeedPost({
    required this.id,
    required this.businessId,
    required this.authorUserId,
    required this.authorName,
    required this.businessName,
    required this.businessOwnerId,
    required this.isEmployeePost,
    required this.isOwnPost,
    required this.caption,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.likeCount,
    required this.isLikedByMe,
  });

  final String id;
  final String businessId;
  final String authorUserId;
  final String authorName;
  final String businessName;
  final String businessOwnerId;
  final bool isEmployeePost;
  final bool isOwnPost;
  final String caption;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final int likeCount;
  final bool isLikedByMe;

  bool get isVideo => mediaType == 'video';

  factory KuaforumFeedPost.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
    required String signedMediaUrl,
  }) {
    final business = json['businesses'];
    final employee = json['employees'];
    final profile = json['profiles'];
    final likes = (json['feed_likes'] as List<dynamic>? ?? const []);
    final liked = likes.any((item) =>
        item is Map<String, dynamic> && item['user_id'] == currentUserId);

    final employeeName = employee is Map<String, dynamic>
        ? (employee['display_name'] as String? ?? '')
        : '';
    final profileName = profile is Map<String, dynamic>
        ? (profile['full_name'] as String? ?? '')
        : '';
    final businessName = business is Map<String, dynamic>
        ? (business['name'] as String? ?? '')
        : '';
    final businessOwnerId = business is Map<String, dynamic>
        ? (business['owner_id'] as String? ?? '')
        : '';
    final authorUserId = json['author_user_id'] as String;

    return KuaforumFeedPost(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      authorUserId: authorUserId,
      authorName: employeeName.isNotEmpty
          ? employeeName
          : (profileName.isNotEmpty ? profileName : businessName),
      businessName: businessName,
      businessOwnerId: businessOwnerId,
      isEmployeePost: employeeName.isNotEmpty,
      isOwnPost: authorUserId == currentUserId,
      caption: json['caption'] as String? ?? '',
      mediaUrl: signedMediaUrl,
      mediaType: json['media_type'] as String? ?? 'image',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      likeCount: likes.length,
      isLikedByMe: liked,
    );
  }
}

class KuaforumFeedRepository {
  KuaforumFeedRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _postSelection =
      'id,business_id,employee_id,author_user_id,caption,media_url,media_type,created_at,'
      'businesses(name),employees(display_name),'
      'profiles!feed_posts_author_user_id_fkey(full_name),feed_likes(user_id)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Önce giriş yapmalısın.');
    return id;
  }

  Future<List<KuaforumFeedPost>> fetchDiscoverFeed({int limit = 40}) async {
    final rows = await _client
        .from('feed_posts')
        .select(_postSelection)
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapRows(rows);
  }

  Future<List<KuaforumFeedPost>> fetchFollowingFeed({int limit = 40}) async {
    final follows = await _client
        .from('feed_follows')
        .select('followed_user_id,followed_business_id')
        .eq('follower_user_id', _userId);

    final userIds = <String>{};
    final businessIds = <String>{};
    for (final row in follows) {
      final userId = row['followed_user_id'] as String?;
      final businessId = row['followed_business_id'] as String?;
      if (userId != null) userIds.add(userId);
      if (businessId != null) businessIds.add(businessId);
    }
    if (userIds.isEmpty && businessIds.isEmpty) return const [];

    final filters = <String>[];
    if (userIds.isNotEmpty) {
      filters.add('author_user_id.in.(${userIds.join(',')})');
    }
    if (businessIds.isNotEmpty) {
      filters.add('business_id.in.(${businessIds.join(',')})');
    }

    final rows = await _client
        .from('feed_posts')
        .select(_postSelection)
        .or(filters.join(','))
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapRows(rows);
  }

  Future<void> followUser(String userId) async {
    if (userId == _userId) {
      throw const PostgrestException(message: 'Kendi hesabını takip edemezsin.');
    }
    await _client.from('feed_follows').upsert(
      {'follower_user_id': _userId, 'followed_user_id': userId},
      onConflict: 'follower_user_id,followed_user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> followBusiness(String businessId) async {
    await _client.from('feed_follows').upsert(
      {'follower_user_id': _userId, 'followed_business_id': businessId},
      onConflict: 'follower_user_id,followed_business_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> unfollowUser(String userId) async {
    await _client
        .from('feed_follows')
        .delete()
        .eq('follower_user_id', _userId)
        .eq('followed_user_id', userId);
  }

  Future<bool> isFollowingUser(String userId) async {
    final row = await _client
        .from('feed_follows')
        .select('id')
        .eq('follower_user_id', _userId)
        .eq('followed_user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> isFollowingBusiness(String businessId) async {
    final row = await _client
        .from('feed_follows')
        .select('id')
        .eq('follower_user_id', _userId)
        .eq('followed_business_id', businessId)
        .maybeSingle();
    return row != null;
  }

  Future<void> unfollowBusiness(String businessId) async {
    await _client
        .from('feed_follows')
        .delete()
        .eq('follower_user_id', _userId)
        .eq('followed_business_id', businessId);
  }

  Future<void> publishPost({
    required File mediaFile,
    required String caption,
  }) async {
    final userId = _userId;
    final trimmedCaption = caption.trim();
    if (trimmedCaption.length > 500) {
      throw const PostgrestException(message: 'Açıklama en fazla 500 karakter olabilir.');
    }

    final profile = await _client
        .from('profiles')
        .select('account_type,is_admin,is_blocked')
        .eq('id', userId)
        .single();
    if (profile['is_blocked'] == true || profile['is_admin'] == true) {
      throw const PostgrestException(
        message: 'Bu hesap paylaşım yapma yetkisine sahip değil.',
      );
    }

    final accountType = profile['account_type'] as String? ?? 'customer';
    String businessId;
    String? employeeId;

    if (accountType == 'business_owner') {
      final business = await _client
          .from('businesses')
          .select('id')
          .eq('owner_id', userId)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();
      if (business == null) {
        throw const PostgrestException(
          message: 'Paylaşım yapmak için onaylı bir işletmen olmalı.',
        );
      }
      businessId = business['id'] as String;
    } else {
      final employee = await _client
          .from('employees')
          .select('id,business_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      if (employee == null) {
        throw const PostgrestException(
          message: 'Aktif çalışan hesabı bulunamadı.',
        );
      }
      employeeId = employee['id'] as String;
      businessId = employee['business_id'] as String;
    }

    final extension = mediaFile.path.split('.').last.toLowerCase();
    const videoExtensions = {'mp4', 'mov'};
    final isVideo = videoExtensions.contains(extension);
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => throw const PostgrestException(
          message: 'Desteklenmeyen dosya türü. JPG, PNG, WEBP, MP4 veya MOV seç.',
        ),
    };

    final objectPath =
        '$businessId/$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage.from('salon-feed').upload(
          objectPath,
          mediaFile,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    try {
      await _client.from('feed_posts').insert({
        'business_id': businessId,
        'employee_id': employeeId,
        'author_user_id': userId,
        'caption': trimmedCaption,
        'media_url': objectPath,
        'media_type': isVideo ? 'video' : 'image',
      });
    } catch (_) {
      await _client.storage.from('salon-feed').remove([objectPath]);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchComments(String postId) async {
    final rows = await _client
        .from('feed_comments')
        .select('id,user_id,author_name,body,created_at')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> addComment(String postId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const PostgrestException(message: 'Yorum boş olamaz.');
    }
    if (trimmed.length > 1000) {
      throw const PostgrestException(message: 'Yorum en fazla 1000 karakter olabilir.');
    }
    await _client.from('feed_comments').insert({
      'post_id': postId,
      'user_id': _userId,
      'body': trimmed,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('feed_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId);
  }

  Future<Map<String, dynamic>> fetchPublicProfile(String userId) async {
    final row = await _client
        .from('public_profiles')
        .select('id,full_name,account_type')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'Bu profil bulunamadı veya erişime kapalı.');
    }
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> fetchBusinessProfile(String businessId) async {
    final row = await _client
        .from('businesses')
        .select('id,name,address,owner_id,status')
        .eq('id', businessId)
        .maybeSingle();
    if (row == null || (row['status'] != 'active' &&
        row['owner_id'] != _userId)) {
      throw const PostgrestException(message: 'Bu işletme profili şu anda görüntülenemiyor.');
    }
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, int>> fetchSocialStats({
    String? userId,
    String? businessId,
  }) async {
    if ((userId == null) == (businessId == null)) {
      throw ArgumentError('Bir kullanıcı veya işletme kimliği verilmelidir.');
    }
    final rows = await _client.rpc('get_social_profile_stats', params: {
      'p_user_id': userId,
      'p_business_id': businessId,
    });
    final row = (rows as List).first as Map<String, dynamic>;
    return {
      'followers': (row['follower_count'] as num).toInt(),
      'following': (row['following_count'] as num).toInt(),
      'posts': (row['post_count'] as num).toInt(),
    };
  }

  Future<List<Map<String, dynamic>>> fetchUserFollowers(String userId) async {
    final rows = await _client
        .from('feed_follows')
        .select('follower_user_id')
        .eq('followed_user_id', userId);
    final ids = rows
        .map((row) => row['follower_user_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final profiles = await _client
        .from('public_profiles')
        .select('id,full_name,account_type')
        .inFilter('id', ids);
    return profiles.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchUserFollowing(String userId) async {
    final rows = await _client
        .from('feed_follows')
        .select('followed_user_id,followed_business_id')
        .eq('follower_user_id', userId);
    final userIds = <String>{};
    final businessIds = <String>{};
    for (final row in rows) {
      final followedUser = row['followed_user_id'] as String?;
      final followedBusiness = row['followed_business_id'] as String?;
      if (followedUser != null) userIds.add(followedUser);
      if (followedBusiness != null) businessIds.add(followedBusiness);
    }

    final result = <Map<String, dynamic>>[];
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('public_profiles')
          .select('id,full_name,account_type')
          .inFilter('id', userIds.toList());
      result.addAll(profiles.map((row) => {
        'id': row['id'],
        'name': row['full_name'],
        'account_type': row['account_type'],
        'kind': 'user',
      }));
    }
    if (businessIds.isNotEmpty) {
      final businesses = await _client
          .from('businesses')
          .select('id,name,address,status')
          .inFilter('id', businessIds.toList())
          .eq('status', 'active');
      result.addAll(businesses.map((row) => {
        'id': row['id'],
        'name': row['name'],
        'account_type': 'business',
        'kind': 'business',
        'address': row['address'],
      }));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchBusinessFollowers(
    String businessId,
  ) async {
    final rows = await _client
        .from('feed_follows')
        .select('follower_user_id')
        .eq('followed_business_id', businessId);
    final ids = rows
        .map((row) => row['follower_user_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];
    final profiles = await _client
        .from('public_profiles')
        .select('id,full_name,account_type')
        .inFilter('id', ids);
    return profiles.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<KuaforumFeedPost>> fetchProfilePosts({
    String? userId,
    String? businessId,
    int limit = 30,
  }) async {
    if ((userId == null) == (businessId == null)) {
      throw ArgumentError('Bir kullanıcı veya işletme kimliği verilmelidir.');
    }
    var query = _client.from('feed_posts').select(_postSelection);
    query = userId != null
        ? query.eq('author_user_id', userId)
        : query.eq('business_id', businessId!);
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapRows(rows);
  }

  Future<void> toggleLike(String postId, {required bool currentlyLiked}) async {
    if (currentlyLiked) {
      await _client
          .from('feed_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _userId);
    } else {
      await _client.from('feed_likes').upsert(
        {'post_id': postId, 'user_id': _userId},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      );
    }
  }

  Future<List<KuaforumFeedPost>> _mapRows(List<dynamic> rows) async {
    final userId = _userId;
    final result = <KuaforumFeedPost>[];
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final path = row['media_url'] as String;
      final signedUrl = await _client.storage
          .from('salon-feed')
          .createSignedUrl(path, 3600);
      result.add(KuaforumFeedPost.fromJson(
        row,
        currentUserId: userId,
        signedMediaUrl: signedUrl,
      ));
    }
    return result;
  }
}
