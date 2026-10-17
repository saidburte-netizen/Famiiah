import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/client.dart';

/// Typed wrappers over the Supabase client. Mirrors `apps/mobile/features/api.ts`:
/// reads go through the REST layer (RLS enforces access); mutations go through
/// SECURITY DEFINER RPCs so business rules and the audit trail stay server-side.
SupabaseClient get _db => getSupabase();

List<Map<String, dynamic>> _rows(dynamic data) {
  if (data is List) return data.cast<Map<String, dynamic>>();
  return const [];
}

// ---------------------------------------------------------------- Dashboard

Future<Map<String, dynamic>> dashboardSummary(String orgId) async {
  final data = await _db.rpc('dashboard_summary', params: {'p_org': orgId});
  if (data is Map) return data.cast<String, dynamic>();
  return const {};
}

// --------------------------------------------------------------- Properties

Future<List<Map<String, dynamic>>> listPropertiesWithStats(
  String orgId, {
  String? type,
  String? search,
}) async {
  final data = await _db.rpc('list_properties_with_stats', params: {
    'p_org': orgId,
    'p_type': type,
    'p_search': search,
    'p_limit': 50,
    'p_offset': 0,
  });
  return _rows(data);
}

Future<Map<String, dynamic>> createProperty(String orgId, Map<String, dynamic> input) async {
  final row = await _db
      .from('properties')
      .insert({
        'org_id': orgId,
        'name': input['name'],
        'type': input['type'],
        'address_line': input['addressLine'],
        'sub_city': input['subCity'],
        'city': input['city'],
        'latitude': input['latitude'],
        'longitude': input['longitude'],
        'floors': input['floors'],
        'notes': input['notes'],
      })
      .select()
      .single();
  return row;
}

Future<Map<String, dynamic>> getProperty(String id) async {
  return await _db.from('properties').select('*').eq('id', id).single();
}

Future<List<Map<String, dynamic>>> listUnits(String propertyId, {String? status}) async {
  final data = await _db.rpc('list_units', params: {
    'p_property': propertyId,
    'p_status': status,
    'p_search': null,
    'p_limit': 100,
    'p_offset': 0,
  });
  return _rows(data);
}

Future<Map<String, dynamic>> createUnit(String orgId, Map<String, dynamic> input) async {
  final row = await _db
      .from('units')
      .insert({
        'org_id': orgId,
        'property_id': input['propertyId'],
        'code': input['code'],
        'kind': input['kind'],
        'floor_label': input['floorLabel'],
        'area_sqm': input['areaSqM'],
        'monthly_rent': input['monthlyRent'],
        'has_separate_meter': input['hasSeparateMeter'] ?? false,
        'has_storage': input['hasStorage'] ?? false,
      })
      .select()
      .single();
  return row;
}

// ------------------------------------------------------------------ Tenants

Future<List<Map<String, dynamic>>> listVacantUnits(String orgId) async {
  final data = await _db
      .from('units')
      .select('id, code, monthly_rent, property_id, properties(name)')
      .eq('org_id', orgId)
      .eq('status', 'vacant')
      .isFilter('deleted_at', null)
      .order('code')
      .limit(200);
  return (data as List).cast<Map<String, dynamic>>().map((r) {
    final props = r['properties'] as Map<String, dynamic>?;
    return <String, dynamic>{
      'id': r['id'],
      'code': r['code'],
      'property_id': r['property_id'],
      'property_name': props?['name'],
      'monthly_rent': '${r['monthly_rent'] ?? '0'}',
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> listTenantsWithStatus(
  String orgId,
  String filter, {
  String? search,
}) async {
  final data = await _db.rpc('list_tenants_with_status', params: {
    'p_org': orgId,
    'p_filter': filter,
    'p_search': search,
    'p_limit': 50,
    'p_offset': 0,
  });
  return _rows(data);
}

Future<Map<String, dynamic>> createTenantWithLease(Map<String, dynamic> input) async {
  final data = await _db.rpc('create_tenant_with_lease', params: {
    'p_org': input['orgId'],
    'p_unit': input['unitId'],
    'p_start': input['startDate'],
    'p_end': input['endDate'],
    'p_rent': input['monthlyRent'],
    'p_deposit': input['depositAmount'],
    'p_billing_day': input['billingDay'],
    'p_grace_days': input['graceDays'],
    'p_tenant': input['tenant'],
  });
  return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
}

Future<Map<String, dynamic>> getTenant(String id) async {
  return await _db.from('tenants').select('*').eq('id', id).single();
}

Future<Map<String, dynamic>> assignTenantToUnit(Map<String, dynamic> input) async {
  final data = await _db.rpc('assign_tenant_to_unit', params: {
    'p_unit': input['unitId'],
    'p_tenant': input['tenantId'],
    'p_start': input['startDate'],
    'p_end': input['endDate'],
    'p_rent': input['monthlyRent'],
    'p_deposit': input['depositAmount'] ?? '0',
    'p_billing_day': input['billingDay'] ?? 1,
    'p_grace_days': input['graceDays'] ?? 5,
  });
  return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
}

// -------------------------------------------------------------------- Leases

Future<void> terminateLease(String leaseId, String endDate, {String? reason}) async {
  await _db.rpc('terminate_lease', params: {
    'p_lease': leaseId,
    'p_end_date': endDate,
    'p_reason': reason,
  });
}

Future<void> renewLease(String leaseId, String newEnd, {String? newRent}) async {
  await _db.rpc('renew_lease', params: {
    'p_lease': leaseId,
    'p_new_end': newEnd,
    'p_new_rent': newRent,
  });
}

Future<List<Map<String, dynamic>>> listLeases(String orgId, {String? status}) async {
  var query = _db
      .from('leases')
      .select(
          'id, unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount, status, ended_reason, units(code), tenants(full_name)')
      .eq('org_id', orgId);
  if (status != null) query = query.eq('status', status);
  final data = await query.order('start_date', ascending: false).limit(100);
  return (data as List).cast<Map<String, dynamic>>().map((l) {
    final unit = l['units'] as Map<String, dynamic>?;
    final tenant = l['tenants'] as Map<String, dynamic>?;
    return {
      ...l,
      'unit_code': unit?['code'],
      'tenant_name': tenant?['full_name'],
      'label': '${unit?['code'] ?? 'Unit'} · ${tenant?['full_name'] ?? 'Tenant'}',
    };
  }).toList();
}

Future<List<Map<String, dynamic>>> listTenantLeases(String tenantId) async {
  final data = await _db
      .from('leases')
      .select('id, unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount, status, ended_reason, units(code)')
      .eq('tenant_id', tenantId)
      .order('start_date', ascending: false);
  return (data as List).cast<Map<String, dynamic>>().map((l) {
    final unit = l['units'] as Map<String, dynamic>?;
    return {...l, 'unit_code': unit?['code']};
  }).toList();
}

Future<List<Map<String, dynamic>>> listLeaseCharges(String leaseId) async {
  final data = await _db
      .from('rent_charges')
      .select('id, period_start, due_date, amount, amount_paid, status')
      .eq('lease_id', leaseId)
      .order('due_date', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
}

// ---------------------------------------------------------------------- Rent

Future<Map<String, dynamic>> rentOverview(String orgId, String month, {String? status, String? search}) async {
  final data = await _db.rpc('rent_overview', params: {
    'p_org': orgId,
    'p_month': month,
    'p_status': status,
    'p_search': search,
    'p_limit': 100,
    'p_offset': 0,
  });
  if (data is Map) return data.cast<String, dynamic>();
  return const {'rows': [], 'expected': 0, 'collected': 0, 'outstanding': 0};
}

// ------------------------------------------------------------------ Payments

Future<Map<String, dynamic>> recordPayment(Map<String, dynamic> input) async {
  final data = await _db.rpc('record_payment', params: {
    'p_lease': input['leaseId'],
    'p_amount': input['amount'],
    'p_method': input['method'],
    'p_reference': input['reference'],
    'p_paid_at': input['paidAt'] ?? DateTime.now().toUtc().toIso8601String(),
    'p_notes': input['notes'],
    'p_idempotency_key': input['idempotencyKey'],
  });
  return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
}

Future<void> voidPayment(String paymentId, String reason) async {
  await _db.rpc('void_payment', params: {'p_payment': paymentId, 'p_reason': reason});
}

Future<List<Map<String, dynamic>>> listPayments(String orgId) async {
  final data = await _db
      .from('payments')
      .select('id, receipt_no, amount, unallocated_amount, method, paid_at, voided_at, reference')
      .eq('org_id', orgId)
      .order('paid_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
}

// --------------------------------------------------------------------- Stock

Future<List<Map<String, dynamic>>> listStockItems(String orgId) async {
  final data = await _db
      .from('stock_items')
      .select('id, name, sku, category, uom, quantity, min_quantity, is_rentable, rental_rate, deleted_at')
      .eq('org_id', orgId)
      .isFilter('deleted_at', null)
      .order('name')
      .limit(100);
  return (data as List).cast<Map<String, dynamic>>();
}

Future<List<Map<String, dynamic>>> listLowStock(String orgId) async {
  final data = await _db.rpc('list_low_stock', params: {'p_org': orgId});
  return _rows(data);
}

Future<List<Map<String, dynamic>>> listStockRentals(String orgId) async {
  final data = await _db
      .from('stock_rentals')
      .select('id, item_id, tenant_id, quantity, daily_rate, start_date, due_date, returned_at, status, stock_items(name), tenants(full_name)')
      .eq('org_id', orgId)
      .order('created_at', ascending: false)
      .limit(100);
  return (data as List).cast<Map<String, dynamic>>();
}

Future<void> stockAdjust(String itemId, String type, String qty, {String? reason}) async {
  await _db.rpc('stock_adjust', params: {
    'p_item': itemId,
    'p_type': type,
    'p_qty': qty,
    'p_reason': reason,
    'p_unit': null,
  });
}

Future<void> rentStockItem(Map<String, dynamic> input) async {
  await _db.rpc('rent_stock_item', params: {
    'p_item': input['itemId'],
    'p_tenant': input['tenantId'],
    'p_qty': input['qty'],
    'p_rate': input['rate'],
    'p_due': input['due'],
  });
}

Future<void> returnStockItem(String rentalId) async {
  await _db.rpc('return_stock_item', params: {'p_rental': rentalId});
}

// ------------------------------------------------------------- Notifications

Future<List<Map<String, dynamic>>> listNotifications(String orgId) async {
  final data = await _db
      .from('notifications')
      .select('id, title, body, channel, status, created_at, read_at')
      .eq('org_id', orgId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
}

Future<void> markNotificationRead(String id) async {
  await _db.rpc('mark_notification_read', params: {'p_id': id});
}

Future<void> markAllNotificationsRead(String orgId) async {
  await _db.rpc('mark_all_notifications_read', params: {'p_org': orgId});
}

Future<void> sendReminder(String chargeId, {String channel = 'in_app'}) async {
  await _db.rpc('send_reminder', params: {'p_charge': chargeId, 'p_channel': channel});
}

/// Queue reminders for every unpaid charge in [month] (YYYY-MM-01).
/// Returns how many reminders were queued.
Future<int> sendRemindersBulk(String orgId, String month) async {
  final data = await _db.rpc('send_reminders_bulk', params: {'p_org': orgId, 'p_month': month});
  return (data as num?)?.toInt() ?? 0;
}

// -------------------------------------------------------------------- Reports

Future<List<Map<String, dynamic>>> reportCollections(
  String orgId,
  String from,
  String to, {
  String groupBy = 'month',
}) async {
  final data = await _db.rpc('report_collections', params: {
    'p_org': orgId,
    'p_from': from,
    'p_to': to,
    'p_group_by': groupBy,
  });
  return _rows(data);
}

Future<List<Map<String, dynamic>>> reportOccupancy(String orgId, String from, String to) async {
  final data = await _db.rpc('report_occupancy', params: {'p_org': orgId, 'p_from': from, 'p_to': to});
  return _rows(data);
}

Future<List<Map<String, dynamic>>> reportOverdueAgeing(String orgId) async {
  final data = await _db.rpc('report_overdue_ageing', params: {'p_org': orgId});
  return _rows(data);
}

// --------------------------------------------------------------- Membership

Future<List<Map<String, dynamic>>> listMembers(String orgId, {String? search}) async {
  final data = await _db.rpc('admin_list_members', params: {
    'p_org': orgId,
    'p_search': search,
    'p_limit': 100,
    'p_offset': 0,
  });
  return _rows(data);
}

Future<void> adminSetMemberRole(String orgId, String userId, String role) async {
  await _db.rpc('admin_set_member_role', params: {'p_org': orgId, 'p_user': userId, 'p_role': role});
}

Future<void> adminSetMemberStatus(String orgId, String userId, String status) async {
  await _db.rpc('admin_set_member_status', params: {'p_org': orgId, 'p_user': userId, 'p_status': status});
}

Future<Map<String, dynamic>> inviteMember(Map<String, dynamic> input) async {
  final res = await _db.functions.invoke('invite-member', body: {
    'org_id': input['orgId'],
    'email': input['email'],
    'phone': input['phone'],
    'role': input['role'],
  });
  return res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
}

// ----------------------------------------------------------------- Invitations

Future<Map<String, dynamic>> acceptInvitation(String tokenHash) async {
  final data = await _db.rpc('accept_invitation', params: {'p_token_hash': tokenHash});
  return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
}

// ---------------------------------------------------------------- Org / auth

Future<void> createOrganization(String name) async {
  await _db.rpc('create_organization', params: {'p_name': name, 'p_slug': null});
}

Future<Map<String, dynamic>?> activeMembership() async {
  final data = await _db
      .from('organization_members')
      .select('org_id, role')
      .eq('status', 'active')
      .limit(1);
  final rows = (data as List).cast<Map<String, dynamic>>();
  return rows.isEmpty ? null : rows.first;
}
