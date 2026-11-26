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
    required this.isSavedByMe,
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
  final bool isSavedByMe;

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
    final saves = (json['feed_saves'] as List<dynamic>? ?? const []);
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
      isSavedByMe: saves.any((item) => item is Map<String, dynamic> && item['user_id'] == currentUserId),
    );
  }
}

class KuaforumFeedRepository {
  KuaforumFeedRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _postSelection =
      'id,business_id,employee_id,author_user_id,caption,media_url,media_type,created_at,'
      'businesses(name,owner_id,business_reviews(rating)),employees(display_name),'
      'profiles!feed_posts_author_user_id_fkey(full_name),feed_likes(user_id),feed_saves(user_id),feed_comments(id)';

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
        .limit(limit * 3);
    final ranked = List<Map<String, dynamic>>.from(rows);
    final featuredRows = await _client.rpc('get_discover_featured_businesses') as List;
    final featuredBusinessIds = featuredRows
        .map((row) => (row as Map)['business_id'] as String)
        .toSet();
    int boost(Map<String, dynamic> row) =>
        featuredBusinessIds.contains(row['business_id']) ? 1 : 0;
    int engagement(Map<String, dynamic> row) =>
        (row['feed_likes'] as List? ?? const []).length +
        (row['feed_comments'] as List? ?? const []).length;
    double rating(Map<String, dynamic> row) {
      final business = row['businesses'];
      final reviews = business is Map
          ? (business['business_reviews'] as List? ?? const [])
          : const [];
      if (reviews.isEmpty) return 0;
      final total = reviews.fold<double>(0, (sum, item) =>
          sum + ((item is Map ? item['rating'] : null) as num? ?? 0).toDouble());
      return total / reviews.length;
    }
    ranked.sort((a, b) {
      final boosted = boost(b).compareTo(boost(a));
      if (boosted != 0) return boosted;
      final active = engagement(b).compareTo(engagement(a));
      if (active != 0) return active;
      final score = rating(b).compareTo(rating(a));
      if (score != 0) return score;
      return DateTime.parse(b['created_at'] as String)
          .compareTo(DateTime.parse(a['created_at'] as String));
    });
    return _mapRows(ranked.take(limit).toList());
  }

  Future<List<KuaforumFeedPost>> fetchBusinessFeed(
    String businessId, {int limit = 30}
  ) async {
    final rows = await _client
        .from('feed_posts')
        .select(_postSelection)
        .eq('business_id', businessId)
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

    final statusRows = await _client.rpc('get_my_account_status') as List;
    if (statusRows.isEmpty) {
      throw const PostgrestException(message: 'Hesap profili bulunamadı.');
    }
    final profile = Map<String, dynamic>.from(statusRows.first as Map);
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

  Future<void> updateComment(String commentId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw const PostgrestException(message: 'Yorum boş olamaz.');
    }
    if (trimmed.length > 1000) {
      throw const PostgrestException(message: 'Yorum en fazla 1000 karakter olabilir.');
    }
    await _client.from('feed_comments').update({'body': trimmed})
        .eq('id', commentId).eq('user_id', _userId);
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('feed_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId);
  }

  Future<void> toggleSave(String postId, {required bool currentlySaved}) async {
    if (currentlySaved) {
      await _client.from('feed_saves').delete()
          .eq('post_id', postId).eq('user_id', _userId);
    } else {
      await _client.from('feed_saves').upsert(
        {'post_id': postId, 'user_id': _userId},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      );
    }
  }

  Future<void> deletePost(String postId) async {
    final row = await _client.from('feed_posts')
        .select('media_url').eq('id', postId).single();
    final path = row['media_url'] as String;
    try {
      await _client.storage.from('salon-feed').remove([path]);
    } catch (_) {
      // The post is still removed from the feed if media cleanup fails.
    }
    await _client.from('feed_posts').delete().eq('id', postId)
        .eq('author_user_id', _userId);
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
