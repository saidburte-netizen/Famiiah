# API (RPC catalog)

RPCs are the public API. Never change a released RPC's signature or return shape —
add a new function (`record_payment_v2`) and deprecate the old one.

Error convention: `raise exception '<snake_case_key>' using errcode = '<SQLSTATE>'`.
`42501` forbidden · `P0002` not found · `22023` invalid input · `23505` conflict.
The shared package maps keys to i18n messages; never leak SQL internals to the UI.

## Version gate

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `check_app_version` | `p_platform text, p_version text` | `{status, latest, min_supported, store_url, notes}` | anon + authenticated |

## Sign-up

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `handle_available` | `p_handle text` | `boolean` — `true` while the @handle is free | anon + authenticated |

## Organizations

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `create_organization` | `p_name, p_slug default null` | organization (caller becomes owner) | authenticated |
| `invite_member` | `p_org, p_email, p_phone, p_role, p_token_hash` | invitation | owner, manager |
| `accept_invitation` | `p_token_hash text` | member row | authenticated |

## Portfolio

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `list_properties_with_stats` | `p_org, p_type, p_search, p_limit, p_offset` | rows + totals | members |
| `list_units` | `p_property, p_status, p_search, p_limit, p_offset` | rows + tenant + overdue | members |

## Tenants & leases

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `list_tenants_with_status` | `p_org, p_filter, p_search, p_limit, p_offset` | rows | members |
| `create_tenant_with_lease` | `p_org, p_tenant jsonb, p_unit, p_start, p_end, p_rent, p_deposit, p_billing_day, p_grace_days` | `{tenant, lease}` | owner, manager, staff |
| `assign_tenant_to_unit` | `p_unit, p_tenant, p_start, p_end, p_rent, p_deposit, p_billing_day, p_grace_days` | lease (`unit_not_vacant`) | owner, manager |
| `renew_lease` | `p_lease, p_new_end, p_new_rent default null` | lease | owner, manager |
| `terminate_lease` | `p_lease, p_end_date, p_reason` | lease (unit becomes vacant) | owner, manager |

## Rent control

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `generate_monthly_charges` | `p_org default null` | count created (idempotent) | cron, owner, manager |
| `mark_overdue_charges` | none | count | cron |
| `record_payment` | `p_lease, p_amount, p_method, p_reference, p_paid_at, p_notes, p_idempotency_key` | payment (oldest-first; leftover → `unallocated_amount`) | owner, manager, staff |
| `void_payment` | `p_payment, p_reason` | payment (reverses allocations; custom audit row) | owner, manager |
| `rent_overview` | `p_org, p_month, p_status, p_search, p_limit, p_offset` | `{rows, expected, collected, outstanding}` | members |
| `send_reminder` | `p_charge, p_channel default 'in_app'` | notification id | owner, manager, staff |
| `send_reminders_bulk` | `p_org, p_month` | count queued | owner, manager |

## Stock

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `stock_adjust` | `p_item, p_type, p_qty, p_reason, p_unit` | item (row-locked; rejects negative balance) | owner, manager, staff |
| `rent_stock_item` | `p_item, p_tenant, p_qty, p_rate, p_due` | rental | owner, manager, staff |
| `return_stock_item` | `p_rental` | rental | owner, manager, staff |
| `list_low_stock` | `p_org` | items at/below `min_quantity` | members |

## Reports

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `report_collections` | `p_org, p_from, p_to, p_group_by ('month'\|'property')` | rows | owner, manager |
| `report_occupancy` | `p_org, p_from, p_to` | rows | owner, manager |
| `report_overdue_ageing` | `p_org` | rows | owner, manager |

## Dashboard, notifications, logs

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `dashboard_summary` | `p_org` | jsonb summary | members |
| `register_device_token` | `p_token, p_platform` | void | authenticated |
| `mark_notification_read` | `p_id` | void | recipient |
| `mark_all_notifications_read` | `p_org` | void | recipient |
| `log_client_event` | `p_level, p_source, p_message, p_context, p_app_version, p_platform, p_request_id` | void (truncated; 60/user/hour) | authenticated |

## Admin (org)

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `admin_list_members` | `p_org, p_search, p_limit, p_offset` | members + profile | owner, manager; platform admin |
| `admin_set_member_role` | `p_org, p_user, p_role` | member (last-owner protected) | owner; platform admin |
| `admin_set_member_status` | `p_org, p_user, p_status` | member | owner, manager |
| `admin_approve_member` | `p_org, p_user` | member | owner, manager |
| `admin_list_audit_logs` | `p_org, p_table, p_actor, p_from, p_to, p_limit, p_offset` | rows | owner, manager; platform admin |

## Admin (platform, AAL2 required)

| RPC | Args | Returns | Allowed |
|---|---|---|---|
| `admin_publish_app_version` | platform fields | row | platform admin (+ AAL2) |
| `admin_set_feature_flag` | `p_key, p_org, p_enabled` | row | platform admin (+ AAL2) |
| `admin_list_event_logs` | `p_level, p_from, p_to, p_limit, p_offset` | rows | platform admin (+ AAL2) |

## Edge Functions

| Function | Trigger | Job |
|---|---|---|
| `send-reminders` | cron daily | due-in-3/due-today/overdue reminders; idempotent per charge+day |
| `invite-member` | app | verify role, create invite (hashed token), email deep link |
| `generate-receipt` | app | build receipt PDF, store, return signed URL (1h) |
| `payment-webhook` | HTTP | verify HMAC signature, `record_payment` with provider ref as idempotency key; flag-gated |
| `admin-api` | app | privileged auth-user actions; requires platform admin + AAL2; audits |
