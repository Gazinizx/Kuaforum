import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class KuaforumFeedPost {
  const KuaforumFeedPost({
    required this.id,
    required this.businessId,
    required this.authorUserId,
    required this.authorName,
    required this.businessName,
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

    return KuaforumFeedPost(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      authorUserId: json['author_user_id'] as String,
      authorName: employeeName.isNotEmpty
          ? employeeName
          : (profileName.isNotEmpty ? profileName : businessName),
      businessName: businessName,
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
