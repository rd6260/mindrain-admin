import 'dart:convert';
import 'package:mindrain_admin/secret.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' as io;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum UserRole {
  student,
  faculty,
  admin,
  staff;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.student,
    );
  }

  String toJson() => name;
}

enum AcademicLevel {
  ug,
  pg,
  phd;

  static AcademicLevel? fromString(String? value) {
    if (value == null) return null;
    return AcademicLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AcademicLevel.ug,
    );
  }

  String toJson() => name;

  String get label {
    switch (this) {
      case AcademicLevel.ug:
        return 'Undergraduate';
      case AcademicLevel.pg:
        return 'Postgraduate';
      case AcademicLevel.phd:
        return 'Doctorate / PhD';
    }
  }
}

/// Maps to Supabase Auth `app_metadata.provider` / `identities[].provider`
enum AuthProvider {
  email,
  google,
  github,
  apple,
  facebook,
  twitter,
  unknown;

  static AuthProvider fromString(String? value) {
    if (value == null) return AuthProvider.unknown;
    return AuthProvider.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AuthProvider.unknown,
    );
  }
}

// ---------------------------------------------------------------------------
// UserModel
// ---------------------------------------------------------------------------

class UserModel {
  // ── auth.users fields ────────────────────────────────────────────────────
  final String id;
  final String? email;
  final String? phone;
  final DateTime? emailConfirmedAt;
  final DateTime? phoneConfirmedAt;
  final DateTime? lastSignInAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool? isAnonymous;

  /// `app_metadata` from auth.users – e.g. {"provider":"google","providers":["google"]}
  final Map<String, dynamic> appMetadata;

  /// `user_metadata` / `raw_user_meta_data` – arbitrary user-supplied data
  final Map<String, dynamic> userMetadata;

  /// Primary OAuth / email provider derived from app_metadata
  final AuthProvider provider;

  // ── public.user_info fields ──────────────────────────────────────────────
  final String name;
  final UserRole role;
  final String? institute;
  final int? academicYear;
  final AcademicLevel? academicLevel;
  final bool earnAccount;

  // ---------------------------------------------------------------------------
  const UserModel({
    required this.id,
    this.email,
    this.phone,
    this.emailConfirmedAt,
    this.phoneConfirmedAt,
    this.lastSignInAt,
    required this.createdAt,
    required this.updatedAt,
    this.isAnonymous,
    this.appMetadata = const {},
    this.userMetadata = const {},
    this.provider = AuthProvider.unknown,
    required this.name,
    required this.role,
    this.institute,
    this.academicYear,
    this.academicLevel,
    this.earnAccount = false,
  });

  // ---------------------------------------------------------------------------
  // Factory: build from user_info row + User object (auth.users)
  // ---------------------------------------------------------------------------

  factory UserModel.fromSupabase({
    required Map<String, dynamic> userInfoRow,
    required User authUser,
  }) {
    final appMeta = authUser.appMetadata;
    final providerStr =
        appMeta['provider'] as String? ??
        appMeta['providers']?.first as String?;

    return UserModel(
      // auth.users
      id: authUser.id,
      email: authUser.email,
      phone: authUser.phone,
      emailConfirmedAt: authUser.emailConfirmedAt != null
          ? DateTime.parse(authUser.emailConfirmedAt!)
          : null,
      phoneConfirmedAt: authUser.phoneConfirmedAt != null
          ? DateTime.parse(authUser.phoneConfirmedAt!)
          : null,
      lastSignInAt: authUser.lastSignInAt != null
          ? DateTime.parse(authUser.lastSignInAt!)
          : null,
      createdAt: DateTime.parse(authUser.createdAt),
      updatedAt: DateTime.parse(authUser.updatedAt ?? authUser.createdAt),
      isAnonymous: authUser.isAnonymous,
      appMetadata: Map<String, dynamic>.from(appMeta),
      userMetadata: Map<String, dynamic>.from(authUser.userMetadata ?? {}),
      provider: AuthProvider.fromString(providerStr),

      // public.user_info
      name: userInfoRow['name'] as String,
      role: UserRole.fromString(userInfoRow['role'] as String),
      institute: userInfoRow['institute'] as String?,
      academicYear: userInfoRow['academic_year'] as int?,
      academicLevel: AcademicLevel.fromString(
        userInfoRow['academic_level'] as String?,
      ),
      earnAccount: (userInfoRow['earn_account'] as bool?) ?? false,
    );
  }

  // ---------------------------------------------------------------------------
  // Factory: fromId — fetches both tables and assembles the model
  // ---------------------------------------------------------------------------

  /// Fetches the full [UserModel] for [userId] by querying:
  ///   1. `public.user_info` via the normal Supabase client.
  ///   2. `auth.users` via the Admin REST API using the service-role key.
  ///
  /// Throws [UserNotFoundException] if the user_info row doesn't exist.
  /// Throws [AuthAdminException] if the auth lookup fails.
  static Future<UserModel> fromId(String userId) async {
    final client = Supabase.instance.client;

    // 1. Fetch public.user_info ──────────────────────────────────────────────
    final infoResponse = await client
        .from('user_info')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (infoResponse == null) {
      throw UserNotFoundException('No user_info row found for id: $userId');
    }

    // 2. Fetch auth.users via Admin API (service role) ───────────────────────
    //    Endpoint: GET /auth/v1/admin/users/{uid}
    final uri = Uri.parse('$SUPABASE_URL/auth/v1/admin/users/$userId');
    final httpClient = client.rest; // underlying http client is not exposed;
    // use dart:io HttpClient or http package instead:

    final response = await _adminGet(uri, SUPABASE_SERVICE_ROLE_KEY);

    if (response.statusCode != 200) {
      throw AuthAdminException(
        'Failed to fetch auth user ($userId): '
        'HTTP ${response.statusCode} — ${response.body}',
      );
    }

    final authJson = jsonDecode(response.body) as Map<String, dynamic>;
    final authUser = User.fromJson(authJson);

    return UserModel.fromSupabase(
      userInfoRow: infoResponse,
      authUser: authUser!,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON serialization — user_info table only
  // ---------------------------------------------------------------------------

  /// Serializes only the `public.user_info` columns (suitable for upsert).
  Map<String, dynamic> toUserInfoJson() => {
    'id': id,
    'name': name,
    'role': role.toJson(),
    'institute': institute,
    'academic_year': academicYear,
    'academic_level': academicLevel?.toJson(),
    'earn_account': earnAccount,
  };

  factory UserModel.fromUserInfoJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      role: UserRole.fromString(json['role'] as String),
      institute: json['institute'] as String?,
      academicYear: json['academic_year'] as int?,
      academicLevel: AcademicLevel.fromString(
        json['academic_level'] as String?,
      ),
      earnAccount: (json['earn_account'] as bool?) ?? false,
      // auth fields are unavailable in user_info-only context
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    DateTime? emailConfirmedAt,
    DateTime? phoneConfirmedAt,
    DateTime? lastSignInAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAnonymous,
    Map<String, dynamic>? appMetadata,
    Map<String, dynamic>? userMetadata,
    AuthProvider? provider,
    String? name,
    UserRole? role,
    String? institute,
    int? academicYear,
    AcademicLevel? academicLevel,
    bool? earnAccount,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emailConfirmedAt: emailConfirmedAt ?? this.emailConfirmedAt,
      phoneConfirmedAt: phoneConfirmedAt ?? this.phoneConfirmedAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      appMetadata: appMetadata ?? this.appMetadata,
      userMetadata: userMetadata ?? this.userMetadata,
      provider: provider ?? this.provider,
      name: name ?? this.name,
      role: role ?? this.role,
      institute: institute ?? this.institute,
      academicYear: academicYear ?? this.academicYear,
      academicLevel: academicLevel ?? this.academicLevel,
      earnAccount: earnAccount ?? this.earnAccount,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & toString
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, role: $role, email: $email)';
}

// ---------------------------------------------------------------------------
// Helper: Admin REST GET
// (Uses dart:io — swap for `http` package if preferred)
// ---------------------------------------------------------------------------

Future<({int statusCode, String body})> _adminGet(
  Uri uri,
  String serviceRoleKey,
) async {
  final request = await io.HttpClient().getUrl(uri);
  request.headers
    ..set('apikey', serviceRoleKey)
    ..set('Authorization', 'Bearer $serviceRoleKey');

  final ioResponse = await request.close();
  final body = await ioResponse.transform(utf8.decoder).join();
  return (statusCode: ioResponse.statusCode, body: body);
}

// ---------------------------------------------------------------------------
// Custom exceptions
// ---------------------------------------------------------------------------

class UserNotFoundException implements Exception {
  final String message;
  const UserNotFoundException(this.message);
  @override
  String toString() => 'UserNotFoundException: $message';
}

class AuthAdminException implements Exception {
  final String message;
  const AuthAdminException(this.message);
  @override
  String toString() => 'AuthAdminException: $message';
}
