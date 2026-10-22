import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_message.dart';
import '../../core/money/money.dart';
import '../../features/api.dart';
import '../../state/org_provider.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

final paymentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final org = ref.watch(orgProvider);
  if (org.orgId == null) return const [];
  return listPayments(org.orgId!);
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final payments = ref.watch(paymentsProvider);
    final canVoid = org.role == 'owner' || org.role == 'manager';

    return FamPage(
      title: 'Payments',
      subtitle: 'Receipts, methods and voiding',
      floatingActionButton: FamFab(
        icon: Icons.add_rounded,
        label: 'Record',
        onPressed: () => context.push('/app/payments/new'),
      ),
      child: payments.when(
        loading: () => const FamLoading(),
        error: (e, _) =>
            ErrorState(message: userMessage(e), onRetry: () => ref.invalidate(paymentsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(paymentsProvider),
          child: rows.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payments yet',
                    message: 'Record a payment and it will appear here with its receipt number.',
                    actionLabel: 'Record payment',
                    onAction: () => context.push('/app/payments/new'),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = rows[i];
                    final voided = p['voided_at'] != null;
                    return FamCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: voided ? FamColors.chipBg : FamColors.tint,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  voided
                                      ? Icons.receipt_long_outlined
                                      : Icons.check_circle_outline_rounded,
                                  size: 22,
                                  color: voided ? FamColors.textMuted : FamColors.royal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p['receipt_no'] ?? 'receipt'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: FamFonts.body,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: FamColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p['method']} · ${p['paid_at']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: FamFonts.body,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: FamColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatMoney(p['amount'], decimals: 0),
                                style: TextStyle(
                                  fontFamily: FamFonts.body,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: voided ? FamColors.textMuted : FamColors.navy,
                                  decoration: voided ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ],
                          ),
                          if (voided) ...[
                            const SizedBox(height: 10),
                            const FamBadge(
                              label: 'Voided',
                              foreground: FamColors.danger,
                              background: FamColors.dangerBg,
                            ),
                          ] else if (p['reference'] != null) ...[
                            const SizedBox(height: 10),
                            FamInfoRow(
                              label: 'Reference',
                              value: '${p['reference']}',
                              icon: Icons.tag_rounded,
                            ),
                          ],
                          if (canVoid && !voided) ...[
                            const SizedBox(height: 12),
                            FamSecondaryButton(
                              label: 'Void payment',
                              icon: Icons.undo_rounded,
                              borderColor: FamColors.danger,
                              foregroundColor: FamColors.danger,
                              height: 46,
                              dense: true,
                              onPressed: () => _confirmVoid(context, ref, p['id'] as String),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }


  Future<void> _confirmVoid(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void payment'),
        content: const Text('This reverses the allocation. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Void')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await voidPayment(id, 'voided by user');
      ref.invalidate(paymentsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(e))));
      }
    }
  }
}
