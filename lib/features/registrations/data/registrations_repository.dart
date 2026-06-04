import 'package:mindrain_admin/features/registrations/data/model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationsRepository {
  final SupabaseClient _supabase;

  RegistrationsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Registration>> fetchRegistrations() async {
    final results = await Future.wait([
      _supabase
          .from('registrations')
          .select()
          .order('created_at', ascending: false),
      _supabase.from('events').select('id, title, code_name'),
      _supabase
          .from('user_info')
          .select('id, name, role, institute, academic_year, academic_level'),
      _supabase.from('members').select(
            'id, registration_id, name, email, institute, academic_year, institute_id, phone, code',
          ),
      _supabase
          .from('payments')
          .select(
            'payment_id, registration_id, amount, currency, status, method, mindrain_fee, razorpay_fee, tax, razorpay_order_id, razorpay_payment_id, razorpay_signature',
          )
          .eq('status', 'paid'),
    ]);

    final eventMap = <String, RegistrationEvent>{
      for (final e in results[1] as List)
        (e as Map<String, dynamic>)['id'] as String:
            RegistrationEvent.fromJson(e),
    };

    final userMap = <String, RegistrationUser>{
      for (final u in results[2] as List)
        (u as Map<String, dynamic>)['id'] as String:
            RegistrationUser.fromJson(u),
    };

    final membersByReg = <String, List<RegistrationMember>>{};
    for (final m in results[3] as List) {
      final row = m as Map<String, dynamic>;
      final regId = row['registration_id'] as String;
      membersByReg.putIfAbsent(regId, () => []);
      membersByReg[regId]!.add(RegistrationMember.fromJson(row));
    }

    final paymentMap = <String, RegistrationPayment>{};
    for (final p in results[4] as List) {
      final row = p as Map<String, dynamic>;
      final regId = row['registration_id'] as String;
      paymentMap.putIfAbsent(regId, () => RegistrationPayment.fromJson(row));
    }

    final registrations = (results[0] as List).map((e) {
      final reg = Registration.fromJson(e as Map<String, dynamic>);
      reg.user = userMap[reg.registrationBy];
      reg.event = eventMap[reg.eventId];
      reg.members = membersByReg[reg.id] ?? [];
      reg.payment = paymentMap[reg.id];
      return reg;
    }).toList();

    return registrations;
  }

  Future<void> updateRegistration(String id, Map<String, dynamic> data) async {
    await _supabase.from('registrations').update(data).eq('id', id);
  }

  Future<RegistrationPayment> createPayment(Map<String, dynamic> data) async {
    final row = await _supabase
        .from('payments')
        .insert(data)
        .select('payment_id, registration_id, amount, currency, status, method, mindrain_fee, razorpay_fee, tax, razorpay_order_id, razorpay_payment_id, razorpay_signature')
        .single();
    return RegistrationPayment.fromJson(row);
  }

  Future<void> updatePayment(String paymentId, Map<String, dynamic> data) async {
    await _supabase.from('payments').update(data).eq('payment_id', paymentId);
  }

  Future<RegistrationMember> createMember(Map<String, dynamic> data) async {
    final row = await _supabase
        .from('members')
        .insert(data)
        .select(
          'id, registration_id, name, email, institute, academic_year, institute_id, phone, code',
        )
        .single();
    return RegistrationMember.fromJson(row);
  }

  Future<void> updateMember(String memberId, Map<String, dynamic> data) async {
    await _supabase.from('members').update(data).eq('id', memberId);
  }

  Future<void> deleteMember(String memberId) async {
    await _supabase.from('members').delete().eq('id', memberId);
  }
}
