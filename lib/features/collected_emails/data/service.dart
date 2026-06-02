import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mindrain_admin/features/collected_emails/data/model.dart';
import 'package:mindrain_admin/features/registrations/data/model.dart';
import 'package:mindrain_admin/secret.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectedEmailsService {
  final _supabase = Supabase.instance.client;

  Future<List<dynamic>> _fetchAuthUsers() async {
    final response = await http.get(
      Uri.parse('$SUPABASE_URL/auth/v1/admin/users?page=1&per_page=1000'),
      headers: {
        'Authorization': 'Bearer $SUPABASE_SERVICE_ROLE_KEY',
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
      },
    );

    final data = jsonDecode(response.body);
    return data['users'] as List;
  }

  Future<List<CollectedEmail>> getCollectedEmails() async {
    // 1. Fetch brief_emails joined with events
    final emailsRes = await _supabase
        .from('brief_emails')
        .select('id, email, created_at, event_id, events(title, created_at)')
        .order('created_at', ascending: false);

    final List emails = emailsRes as List;

    // 2. Fetch paid emails from registrations_2
    final paidEmailsRes = await _supabase
        .from('registrations_2')
        .select('email')
        .eq('paid', true);

    final Set<String> paidEmails = {
      for (final r in (paidEmailsRes as List)) (r['email'] as String).toLowerCase(),
    };

    // 3. Fetch auth users
    final authUsersRes = await _fetchAuthUsers();
    final Map<String, String> idByEmail = {};
    for (final u in authUsersRes) {
      final email = u['email'] as String?;
      final id = u['id'] as String;
      if (email != null) {
        idByEmail[email.toLowerCase()] = id;
      }
    }

    // 4. Fetch user_info
    final userInfoRes = await _supabase
        .from('user_info')
        .select('id, name, role, institute, academic_year, academic_level');

    final Map<String, RegistrationUser> userInfoById = {};
    for (final u in (userInfoRes as List)) {
      final id = u['id'] as String;
      userInfoById[id] = RegistrationUser.fromJson(u);
    }

    // 5. Map to CollectedEmail
    return emails.map<CollectedEmail>((e) {
      final emailStr = e['email'] as String;
      final emailLower = emailStr.toLowerCase();
      final event = e['events'] as Map<String, dynamic>?;

      RegistrationUser? user;
      final authId = idByEmail[emailLower];
      if (authId != null) {
        user = userInfoById[authId];
        // Ensure email is set in RegistrationUser even if not present in user_info table
        if (user != null && user.email == null) {
          user = RegistrationUser(
            id: user.id,
            name: user.name,
            email: emailStr,
            phone: user.phone,
            role: user.role,
            institute: user.institute,
            academicYear: user.academicYear,
            academicLevel: user.academicLevel,
          );
        }
      }

      return CollectedEmail(
        id: e['id'] as int,
        email: emailStr,
        createdAt: DateTime.parse(e['created_at'] as String).toLocal(),
        eventName: event?['title'] as String? ?? '—',
        isPaid: paidEmails.contains(emailLower),
        user: user,
      );
    }).toList();
  }
}
