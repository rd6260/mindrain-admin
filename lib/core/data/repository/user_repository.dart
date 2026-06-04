import 'package:mindrain_admin/core/data/model/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Abstract interface — swap implementation for testing/mocking
// ---------------------------------------------------------------------------

abstract class IUserRepository {
  Future<UserModel> fetchById(String userId);
  Future<UserModel> fetchCurrent();
  Future<void> update(UserModel user);
  Future<void> updateFields(String userId, Map<String, dynamic> fields);
  Future<void> delete(String userId);
  Future<List<UserModel>> fetchAll();
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class UserRepository implements IUserRepository {
  final SupabaseClient _client;

  UserRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Fetch by ID ────────────────────────────────────────────────────────────

  @override
  Future<UserModel> fetchById(String userId) async {
    return UserModel.fromId(userId);
  }

  // ── Fetch currently signed-in user ────────────────────────────────────────

  @override
  Future<UserModel> fetchCurrent() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw const UnauthenticatedException();
    return fetchById(authUser.id);
  }

  // ── Update all user_info fields from a UserModel ──────────────────────────

  @override
  Future<void> update(UserModel user) async {
    await _client
        .from('user_info')
        .update(user.toUserInfoJson()..remove('id')) // id stays in .eq()
        .eq('id', user.id);
  }

  // ── Update specific fields only (partial update) ──────────────────────────
  //
  // Example:
  //   repo.updateFields(userId, {'institute': 'IIT', 'academic_year': 3});

  @override
  Future<void> updateFields(
      String userId, Map<String, dynamic> fields) async {
    assert(fields.isNotEmpty, 'fields must not be empty');
    await _client.from('user_info').update(fields).eq('id', userId);
  }

  // ── Delete user_info row ───────────────────────────────────────────────────
  // Note: deleting auth.users requires admin API — handle separately if needed.

  @override
  Future<void> delete(String userId) async {
    await _client.from('user_info').delete().eq('id', userId);
  }

  // ── Fetch all users (admin use) ────────────────────────────────────────────

  @override
  Future<List<UserModel>> fetchAll() async {
    final rows = await _client.from('user_info').select();
    // auth data not available in bulk without N+1 calls;
    // returns user_info-only models for list/admin views.
    return (rows as List)
        .map((row) =>
            UserModel.fromUserInfoJson(row as Map<String, dynamic>))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Convenience extension — call .save() or .updateField() on any UserModel
// ---------------------------------------------------------------------------

extension UserModelX on UserModel {
  /// Persists all user_info fields to Supabase.
  Future<void> save([UserRepository? repo]) =>
      (repo ?? UserRepository()).update(this);

  /// Updates a single field on this user.
  ///
  /// Example:  user.updateField('institute', 'NIT Silchar');
  Future<void> updateField(String field, dynamic value,
      [UserRepository? repo]) =>
      (repo ?? UserRepository()).updateFields(id, {field: value});
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

class UnauthenticatedException implements Exception {
  const UnauthenticatedException();
  @override
  String toString() => 'UnauthenticatedException: No user is signed in.';
}
