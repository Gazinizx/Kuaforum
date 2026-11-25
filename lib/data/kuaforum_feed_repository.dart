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
    required this.authorAvatarUrl,
    required this.businessLogoUrl,
    required this.isEmployeePost,
    required this.isOwnPost,
    required this.caption,
    required this.category,
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
  final String? authorAvatarUrl;
  final String? businessLogoUrl;
  final bool isEmployeePost;
  final bool isOwnPost;
  final String caption;
  final String category;
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
    String? authorAvatarUrl,
    String? businessLogoUrl,
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
      authorAvatarUrl: authorAvatarUrl,
      businessLogoUrl: businessLogoUrl,
      isEmployeePost: employeeName.isNotEmpty,
      isOwnPost: authorUserId == currentUserId,
      caption: json['caption'] as String? ?? '',
      category: json['category'] as String? ?? 'Genel',
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
      'businesses(name,owner_id,logo_url),employees(display_name),'
      'profiles!feed_posts_author_user_id_fkey(full_name,avatar_url),feed_likes(user_id),category';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Önce giriş yapmalısın.');
    return id;
  }

  Future<List<KuaforumFeedPost>> fetchDiscoverFeed({
    int limit = 40,
    String searchQuery = '',
    String category = 'Tümü',
  }) async {
    final term = searchQuery.trim();
    List<String>? matchedPostIds;
    if (term.isNotEmpty) {
      final results = await Future.wait([
        _client.from('feed_posts').select('id').ilike('caption', '%$term%'),
        _client.from('businesses').select('id').eq('status', 'active').ilike('name', '%$term%'),
        _client.from('public_employee_profiles').select('user_id').ilike('display_name', '%$term%'),
      ]);
      final businessIds = (results[1] as List)
          .map((row) => row['id'] as String)
          .toList();
      final employeeIds = (results[2] as List)
          .map((row) => row['user_id'] as String)
          .toList();
      final idSet = <String>{
        ...(results[0] as List).map((row) => row['id'] as String),
      };
      if (businessIds.isNotEmpty) {
        final rows = await _client
            .from('feed_posts')
            .select('id')
            .inFilter('business_id', businessIds);
        idSet.addAll(rows.map((row) => row['id'] as String));
      }
      if (employeeIds.isNotEmpty) {
        final rows = await _client
            .from('feed_posts')
            .select('id')
            .inFilter('author_user_id', employeeIds);
        idSet.addAll(rows.map((row) => row['id'] as String));
      }
      matchedPostIds = idSet.toList();
      if (matchedPostIds.isEmpty) return const [];
    }

    var query = _client.from('feed_posts').select(_postSelection);
    if (matchedPostIds != null) {
      query = query.inFilter('id', matchedPostIds);
    }
    if (category != 'Tümü') {
      query = query.eq('category', category);
    }
    final rows = await query
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
    String category = 'Genel',
  }) async {
    final userId = _userId;
    final trimmedCaption = caption.trim();
    if (trimmedCaption.length > 500) {
      throw const PostgrestException(message: 'Açıklama en fazla 500 karakter olabilir.');
    }
    const allowedCategories = {'Genel', 'Saç Kesimi', 'Boyama', 'Ombre', 'Topuz', 'Bakım'};
    if (!allowedCategories.contains(category)) {
      throw const PostgrestException(message: 'Geçersiz paylaşım kategorisi.');
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
        'category': category,
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
        .select('id,full_name,account_type,avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'Bu profil bulunamadı veya erişime kapalı.');
    }
    final profile = Map<String, dynamic>.from(row);
    final avatarPath = profile['avatar_url'] as String?;
    profile['avatar_url'] = avatarPath == null || avatarPath.isEmpty
        ? null
        : _client.storage.from('salon-avatars').getPublicUrl(avatarPath);
    return profile;
  }

  Future<Map<String, dynamic>> fetchOwnedBusinessProfile() async {
    final row = await _client
        .from('businesses')
        .select('id,name,address,owner_id,status,logo_url,appointment_interval_minutes')
        .eq('owner_id', _userId)
        .maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'Bu hesaba bağlı işletme bulunamadı.');
    }
    final business = Map<String, dynamic>.from(row);
    final logoPath = business['logo_url'] as String?;
    business['logo_url'] = logoPath == null || logoPath.isEmpty
        ? null
        : _client.storage.from('salon-avatars').getPublicUrl(logoPath);
    return business;
  }

  Future<List<Map<String, dynamic>>> fetchActiveBusinesses({
    String searchQuery = '',
    int limit = 50,
  }) async {
    var query = _client
        .from('businesses')
        .select('id,name,address,logo_url')
        .eq('status', 'active');
    final term = searchQuery.trim();
    if (term.isNotEmpty) {
      query = query.ilike('name', '%$term%');
    }
    final rows = await query.order('name').limit(limit);
    return rows.map((row) {
      final business = Map<String, dynamic>.from(row);
      final logoPath = business['logo_url'] as String?;
      business['logo_url'] = logoPath == null || logoPath.isEmpty
          ? null
          : _client.storage.from('salon-avatars').getPublicUrl(logoPath);
      return business;
    }).toList();
  }

  Future<Map<String, dynamic>> fetchBusinessProfile(String businessId) async {
    final row = await _client
        .from('businesses')
        .select('id,name,address,owner_id,status,logo_url')
        .eq('id', businessId)
        .maybeSingle();
    if (row == null || (row['status'] != 'active' &&
        row['owner_id'] != _userId)) {
      throw const PostgrestException(message: 'Bu işletme profili şu anda görüntülenemiyor.');
    }
    final business = Map<String, dynamic>.from(row);
    final logoPath = business['logo_url'] as String?;
    business['logo_url'] = logoPath == null || logoPath.isEmpty
        ? null
        : _client.storage.from('salon-avatars').getPublicUrl(logoPath);
    return business;
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
        .select('id,full_name,account_type,avatar_url')
        .inFilter('id', ids);
    return profiles.map((row) {
      final profile = Map<String, dynamic>.from(row);
      final avatarPath = profile['avatar_url'] as String?;
      profile['avatar_url'] = avatarPath == null || avatarPath.isEmpty
          ? null
          : _client.storage.from('salon-avatars').getPublicUrl(avatarPath);
      return profile;
    }).toList();
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
          .select('id,full_name,account_type,avatar_url')
          .inFilter('id', userIds.toList());
      result.addAll(profiles.map((row) {
        final avatarPath = row['avatar_url'] as String?;
        return {
          'id': row['id'],
          'name': row['full_name'],
          'account_type': row['account_type'],
          'kind': 'user',
          'avatar_url': avatarPath == null || avatarPath.isEmpty
              ? null
              : _client.storage.from('salon-avatars').getPublicUrl(avatarPath),
        };
      }));
    }
    if (businessIds.isNotEmpty) {
      final businesses = await _client
          .from('businesses')
          .select('id,name,address,status,logo_url')
          .inFilter('id', businessIds.toList())
          .eq('status', 'active');
      result.addAll(businesses.map((row) {
        final logoPath = row['logo_url'] as String?;
        return {
          'id': row['id'],
          'name': row['name'],
          'account_type': 'business',
          'kind': 'business',
          'address': row['address'],
          'avatar_url': logoPath == null || logoPath.isEmpty
              ? null
              : _client.storage.from('salon-avatars').getPublicUrl(logoPath),
        };
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
        .select('id,full_name,account_type,avatar_url')
        .inFilter('id', ids);
    return profiles.map((row) {
      final profile = Map<String, dynamic>.from(row);
      final avatarPath = profile['avatar_url'] as String?;
      profile['avatar_url'] = avatarPath == null || avatarPath.isEmpty
          ? null
          : _client.storage.from('salon-avatars').getPublicUrl(avatarPath);
      return profile;
    }).toList();
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

  Future<String> uploadBusinessLogo(File imageFile) async {
    if (await imageFile.length() > 5 * 1024 * 1024) {
      throw const PostgrestException(message: 'İşletme logosu en fazla 5 MB olabilir.');
    }
    final extension = imageFile.path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const PostgrestException(
          message: 'İşletme logosu JPG, PNG veya WEBP olmalı.',
        ),
    };
    final business = await _client
        .from('businesses')
        .select('id,logo_url')
        .eq('owner_id', _userId)
        .maybeSingle();
    if (business == null) {
      throw const PostgrestException(message: 'İşletme hesabı bulunamadı.');
    }
    final businessId = business['id'] as String;
    final objectPath =
        'businesses/$businessId/logo_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage.from('salon-avatars').upload(
      objectPath,
      imageFile,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    try {
      await _client.rpc('set_my_business_logo', params: {
        'p_business_id': businessId,
        'p_logo_path': objectPath,
      });
    } catch (_) {
      await _client.storage.from('salon-avatars').remove([objectPath]);
      rethrow;
    }
    final previousPath = business['logo_url'] as String?;
    if (previousPath != null && previousPath.isNotEmpty) {
      try {
        await _client.storage.from('salon-avatars').remove([previousPath]);
      } catch (_) {}
    }
    return _client.storage.from('salon-avatars').getPublicUrl(objectPath);
  }

  Future<String> uploadProfileAvatar(File imageFile) async {
    if (await imageFile.length() > 5 * 1024 * 1024) {
      throw const PostgrestException(message: 'Profil fotoğrafı en fazla 5 MB olabilir.');
    }
    final extension = imageFile.path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const PostgrestException(
          message: 'Profil fotoğrafı JPG, PNG veya WEBP olmalı.',
        ),
    };
    final userId = _userId;
    final objectPath =
        'profiles/$userId/avatar_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final previous = await _client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();
    await _client.storage.from('salon-avatars').upload(
      objectPath,
      imageFile,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    try {
      await _client
          .from('profiles')
          .update({'avatar_url': objectPath})
          .eq('id', userId);
    } catch (_) {
      await _client.storage.from('salon-avatars').remove([objectPath]);
      rethrow;
    }
    final previousPath = previous?['avatar_url'] as String?;
    if (previousPath != null && previousPath.isNotEmpty) {
      try {
        await _client.storage.from('salon-avatars').remove([previousPath]);
      } catch (_) {}
    }
    return _client.storage.from('salon-avatars').getPublicUrl(objectPath);
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final rows = await _client
        .from('notifications')
        .select('id,appointment_id,title,body,created_at,read_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  Future<void> markAllNotificationsRead() async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _userId)
        .isFilter('read_at', null);
  }

  Future<Map<String, dynamic>> fetchMyEmployeeContext() async {
    final row = await _client
        .from('employees')
        .select('id,business_id,display_name')
        .eq('user_id', _userId)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'Aktif çalışan kaydı bulunamadı.');
    }
    return Map<String, dynamic>.from(row);
  }

  Future<String> joinBusinessByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const PostgrestException(message: 'İşletme kodunu gir.');
    }
    final result = await _client.rpc(
      'join_business_by_code',
      params: {'p_code': trimmed},
    );
    if (result == null) {
      throw const PostgrestException(message: 'İşletmeye katılma işlemi tamamlanamadı.');
    }
    return result.toString();
  }

  Future<String?> fetchMyBusinessMembership() async {
    final row = await _client
        .from('business_memberships')
        .select('business_id')
        .eq('customer_id', _userId)
        .maybeSingle();
    return row?['business_id'] as String?;
  }

  Future<List<Map<String, dynamic>>> fetchBusinessEmployees(
    String businessId,
  ) async {
    final rows = await _client
        .from('public_employee_profiles')
        .select('id,user_id,business_id,display_name,avatar_url')
        .eq('business_id', businessId);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCustomerAppointments() async {
    final rows = await _client
        .from('appointments')
        .select(
          'id,business_id,employee_id,service_id,starts_at,ends_at,status,'
          'customer_note,requires_business_approval,'
          'businesses(name),services(name,price,duration_minutes),employees(display_name)',
        )
        .eq('customer_id', _userId)
        .order('starts_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchBusinessAppointments(
    String businessId, {
    required bool mineOnly,
  }) async {
    final rows = await _client.rpc('get_business_appointments', params: {
      'p_business_id': businessId,
      'p_mine_only': mineOnly,
    });
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAvailableAppointmentSlots({
    required String businessId,
    required String employeeId,
    required String serviceId,
    required DateTime date,
  }) async {
    final dateText = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final rows = await _client.rpc('get_available_appointment_slots', params: {
      'p_business_id': businessId,
      'p_employee_id': employeeId,
      'p_service_id': serviceId,
      'p_date': dateText,
    });
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<String> bookAppointment({
    required String businessId,
    required String employeeId,
    required String serviceId,
    required String startsAt,
    String? customerNote,
  }) async {
    final result = await _client.rpc('book_appointment', params: {
      'p_business_id': businessId,
      'p_employee_id': employeeId,
      'p_service_id': serviceId,
      'p_starts_at': startsAt,
      'p_customer_note': customerNote?.trim().isEmpty == true ? null : customerNote?.trim(),
    });
    if (result == null) {
      throw const PostgrestException(message: 'Randevu oluşturulamadı.');
    }
    return result.toString();
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await _client.rpc('cancel_appointment', params: {
      'p_appointment_id': appointmentId,
    });
  }

  Future<void> reviewAppointmentRequest(
    String appointmentId, {
    required bool approve,
  }) async {
    await _client.rpc('review_appointment_request', params: {
      'p_appointment_id': appointmentId,
      'p_decision': approve ? 'approve' : 'reject',
    });
  }

  Future<void> updateAppointmentStatus(
    String appointmentId, {
    required String status,
  }) async {
    if (!{'completed', 'no_show'}.contains(status)) {
      throw const PostgrestException(message: 'Geçersiz randevu durumu.');
    }
    await _client.rpc('update_appointment_status', params: {
      'p_appointment_id': appointmentId,
      'p_status': status,
    });
  }

  Future<void> updateAppointmentInterval(
    String businessId,
    int minutes,
  ) async {
    await _client.rpc('update_appointment_interval', params: {
      'p_business_id': businessId,
      'p_interval_minutes': minutes,
    });
  }

  Future<List<Map<String, dynamic>>> fetchBusinessHours(
    String businessId,
  ) async {
    var rows = await _client
        .from('business_hours')
        .select('id,weekday,opens_at,closes_at,is_closed')
        .eq('business_id', businessId)
        .order('weekday');
    if (rows.isEmpty) {
      final defaults = List.generate(7, (weekday) => {
        'business_id': businessId,
        'weekday': weekday,
        'opens_at': '09:00:00',
        'closes_at': '20:00:00',
        'is_closed': false,
      });
      await _client
          .from('business_hours')
          .upsert(defaults, onConflict: 'business_id,weekday');
      rows = await _client
          .from('business_hours')
          .select('id,weekday,opens_at,closes_at,is_closed')
          .eq('business_id', businessId)
          .order('weekday');
    }
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> saveBusinessHours({
    required String businessId,
    required int weekday,
    required String opensAt,
    required String closesAt,
    required bool isClosed,
  }) async {
    if (!isClosed && opensAt.compareTo(closesAt) >= 0) {
      throw const PostgrestException(message: 'Kapanış saati açılış saatinden sonra olmalı.');
    }
    await _client.from('business_hours').upsert({
      'business_id': businessId,
      'weekday': weekday,
      'opens_at': opensAt,
      'closes_at': closesAt,
      'is_closed': isClosed,
    }, onConflict: 'business_id,weekday');
  }

  Future<List<Map<String, dynamic>>> fetchBusinessCustomers(
    String businessId,
  ) async {
    final rows = await _client.rpc('get_business_customers', params: {
      'p_business_id': businessId,
    });
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> setCustomerBlacklist({
    required String businessId,
    required String customerId,
    required bool blocked,
    String? reason,
  }) async {
    await _client.rpc('set_customer_blacklist', params: {
      'p_business_id': businessId,
      'p_customer_id': customerId,
      'p_blocked': blocked,
      'p_reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchOwnedEmployees(
    String businessId,
  ) async {
    final rows = await _client
        .from('employees')
        .select('id,display_name,user_id,is_active,employee_invites(invite_code,expires_at,claimed_at)')
        .eq('business_id', businessId)
        .order('display_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<String> createEmployeeInvite({
    required String businessId,
    required String displayName,
  }) async {
    final result = await _client.rpc('create_employee_invite', params: {
      'p_business_id': businessId,
      'p_display_name': displayName.trim(),
    });
    if (result == null) {
      throw const PostgrestException(message: 'Çalışan daveti oluşturulamadı.');
    }
    return result.toString();
  }

  Future<void> setEmployeeActive(String employeeId, bool isActive) async {
    await _client.rpc('set_employee_active', params: {
      'p_employee_id': employeeId,
      'p_is_active': isActive,
    });
  }

  Future<List<Map<String, dynamic>>> fetchBusinessServices(
    String businessId,
  ) async {
    final rows = await _client
        .from('services')
        .select('id,name,price,duration_minutes,is_active')
        .eq('business_id', businessId)
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createBusinessService({
    required String businessId,
    required String name,
    required double price,
    required int durationMinutes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || price < 0 || durationMinutes < 5) {
      throw const PostgrestException(message: 'Hizmet bilgilerini kontrol et.');
    }
    await _client.from('services').insert({
      'business_id': businessId,
      'name': trimmed,
      'price': price,
      'duration_minutes': durationMinutes,
      'is_active': true,
    });
  }

  Future<void> updateBusinessService({
    required String serviceId,
    required String name,
    required double price,
    required int durationMinutes,
    required bool isActive,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || price < 0 || durationMinutes < 5) {
      throw const PostgrestException(message: 'Hizmet bilgilerini kontrol et.');
    }
    await _client.from('services').update({
      'name': trimmed,
      'price': price,
      'duration_minutes': durationMinutes,
      'is_active': isActive,
    }).eq('id', serviceId);
  }

  Future<void> deleteBusinessService(String serviceId) async {
    await _client.from('services').delete().eq('id', serviceId);
  }

  Future<bool> canMessageEmployee(String employeeUserId) async {
    final result = await _client.rpc(
      'can_message_employee',
      params: {'p_employee_user_id': employeeUserId},
    );
    return result == true;
  }

  Future<String> startEmployeeConversation(String employeeUserId) async {
    final result = await _client.rpc(
      'start_employee_conversation',
      params: {'p_employee_user_id': employeeUserId},
    );
    if (result == null) {
      throw const PostgrestException(message: 'Sohbet başlatılamadı.');
    }
    return result.toString();
  }

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final currentUserId = _userId;
    final rows = await _client
        .from('conversations')
        .select(
          'id,business_id,employee_id,customer_id,updated_at,'
          'businesses(name),customer:profiles!conversations_customer_id_fkey(full_name,avatar_url)',
        )
        .order('updated_at', ascending: false);

    final employeeIds = rows
        .map((row) => row['employee_id'] as String)
        .toSet()
        .toList();
    final employeeRows = employeeIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
            .from('public_employee_profiles')
            .select('id,user_id,business_id,display_name,avatar_url')
            .inFilter('id', employeeIds))
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    final employeesById = {
      for (final employee in employeeRows) employee['id'] as String: employee,
    };

    final result = <Map<String, dynamic>>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final employee = employeesById[row['employee_id']] ?? <String, dynamic>{};
      final customer = row['customer'];
      final business = row['businesses'];
      final customerId = row['customer_id'] as String;
      final employeeUserId = employee['user_id'] as String?;
      // Business owners may see the conversation row for management, but this
      // customer-to-employee inbox is visible only to its two participants.
      if (customerId != currentUserId && employeeUserId != currentUserId) {
        continue;
      }
      final customerAvatarPath = customer is Map<String, dynamic>
          ? customer['avatar_url'] as String?
          : null;
      final employeeAvatarPath = employee['avatar_url'] as String?;
      result.add({
        'id': row['id'],
        'business_id': row['business_id'],
        'customer_id': customerId,
        'employee_user_id': employeeUserId,
        'business_name': business is Map<String, dynamic>
            ? business['name'] as String? ?? 'Kuaförüm'
            : 'Kuaförüm',
        'customer_name': customer is Map<String, dynamic>
            ? customer['full_name'] as String? ?? 'Müşteri'
            : 'Müşteri',
        'employee_name': employee['display_name'] as String? ?? 'Çalışan',
        'customer_avatar_url': customerAvatarPath == null || customerAvatarPath.isEmpty
            ? null
            : _client.storage.from('salon-avatars').getPublicUrl(customerAvatarPath),
        'employee_avatar_url': employeeAvatarPath == null || employeeAvatarPath.isEmpty
            ? null
            : _client.storage.from('salon-avatars').getPublicUrl(employeeAvatarPath),
        'updated_at': row['updated_at'],
      });
    }
    return result;
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId);
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 4000) {
      throw const PostgrestException(message: 'Mesaj en fazla 4000 karakter olabilir.');
    }
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _userId,
      'body': trimmed,
    });
  }

  Future<void> updatePostCaption(String postId, String caption) async {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      throw const PostgrestException(message: 'Paylaşım açıklaması boş olamaz.');
    }
    if (trimmed.length > 500) {
      throw const PostgrestException(message: 'Açıklama en fazla 500 karakter olabilir.');
    }
    await _client
        .from('feed_posts')
        .update({
          'caption': trimmed,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId)
        .eq('author_user_id', _userId);
  }

  Future<void> deletePost(String postId) async {
    final row = await _client
        .from('feed_posts')
        .select('media_url')
        .eq('id', postId)
        .maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'Paylaşım bulunamadı.');
    }
    final mediaPath = row['media_url'] as String;
    await _client.storage.from('salon-feed').remove([mediaPath]);
    await _client
        .from('feed_posts')
        .delete()
        .eq('id', postId)
        .eq('author_user_id', _userId);
  }

  Future<void> reportPost(String postId, String reason) async {
    const allowedReasons = {
      'Spam',
      'Uygunsuz içerik',
      'Taciz veya hakaret',
      'Sahte hesap / yanıltıcı',
      'Diğer',
    };
    if (!allowedReasons.contains(reason)) {
      throw const PostgrestException(message: 'Geçersiz şikâyet nedeni.');
    }
    await _client.from('feed_reports').upsert(
      {
        'post_id': postId,
        'reporter_user_id': _userId,
        'reason': reason,
      },
      onConflict: 'post_id,reporter_user_id',
      ignoreDuplicates: true,
    );
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
      final profile = row['profiles'];
      final business = row['businesses'];
      final avatarPath = profile is Map<String, dynamic>
          ? profile['avatar_url'] as String?
          : null;
      final logoPath = business is Map<String, dynamic>
          ? business['logo_url'] as String?
          : null;
      result.add(KuaforumFeedPost.fromJson(
        row,
        currentUserId: userId,
        signedMediaUrl: signedUrl,
        authorAvatarUrl: avatarPath == null || avatarPath.isEmpty
            ? null
            : _client.storage.from('salon-avatars').getPublicUrl(avatarPath),
        businessLogoUrl: logoPath == null || logoPath.isEmpty
            ? null
            : _client.storage.from('salon-avatars').getPublicUrl(logoPath),
      ));
    }
    return result;
  }
}
