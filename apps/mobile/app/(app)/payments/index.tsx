import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Modal, View } from "react-native";
import { Stack, useFocusEffect, useRouter } from "expo-router";
import { useQueryClient } from "@tanstack/react-query";
import { formatMoney } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { listPayments, voidPayment } from "@/features/api";
import { userMessage } from "@/lib/errors";

interface PaymentRow {
  id: string;
  receipt_no: string | null;
  amount: string;
  unallocated_amount: string | null;
  method: string;
  paid_at: string;
  voided_at: string | null;
  reference: string | null;
}

export default function PaymentsScreen() {
  const { orgId, role } = useOrg();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [rows, setRows] = useState<PaymentRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<PaymentRow | null>(null);

  const canVoid = role === "owner" || role === "manager";

  const load = useCallback(async () => {
    if (!orgId) return;
    setRows(await listPayments(orgId));
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  // Returning from "record payment" must show the new row, so refresh on focus.
  useFocusEffect(
    useCallback(() => {
      if (!orgId) return;
      void load();
    }, [orgId, load]),
  );

  return (
    <Screen>
      <Stack.Screen options={{ title: "Payments" }} />
      <Button title="Record payment" onPress={() => router.push("/(app)/payments/new")} />
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(r) => r.id}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          ListEmptyComponent={<Text variant="muted">No payments recorded yet.</Text>}
          renderItem={({ item }) => {
            const voided = !!item.voided_at;
            return (
              <Card>
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text variant="bold" color={voided ? colors.textMuted : colors.navy}>
                    {formatMoney(item.amount)}
                  </Text>
                  <Text variant="semibold" color={voided ? colors.danger : colors.textMuted}>
                    {voided ? "voided" : item.method}
                  </Text>
                </View>
                <Text variant="muted">
                  {item.receipt_no ? `${item.receipt_no} · ` : ""}
                  {item.paid_at.slice(0, 10)}
                  {item.reference ? ` · ${item.reference}` : ""}
                </Text>
                {Number(item.unallocated_amount ?? 0) > 0 && !voided ? (
                  <Text variant="muted">
                    Unallocated credit {formatMoney(item.unallocated_amount ?? "0")}
                  </Text>
                ) : null}
                {canVoid && !voided ? (
                  <View style={{ marginTop: 8 }}>
                    <Button title="Void" variant="ghost" onPress={() => setSelected(item)} />
                  </View>
                ) : null}
              </Card>
            );
          }}
        />
      )}
      <VoidModal
        payment={selected}
        onClose={() => setSelected(null)}
        onDone={async () => {
          setSelected(null);
          await load();
          // A void reverses an allocation: refresh the rent/dashboard caches the
          // other screens read from.
          await queryClient.invalidateQueries({ queryKey: ["rent-overview"] });
          await queryClient.invalidateQueries({ queryKey: ["dashboard"] });
        }}
      />
    </Screen>
  );
}

function VoidModal({
  payment,
  onClose,
  onDone,
}: {
  payment: PaymentRow | null;
  onClose: () => void;
  onDone: () => void | Promise<void>;
}) {
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setReason("");
    setError(null);
  }, [payment]);

  async function save() {
    if (!payment) return;
    setError(null);
    setBusy(true);
    try {
      await voidPayment(payment.id, reason || "voided from app");
      await onDone();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={!!payment} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, padding: 20, gap: 16, backgroundColor: colors.background }}>
        <Text variant="display" color={colors.midnight}>
          Void payment
        </Text>
        {payment ? (
          <Text variant="muted">
            {formatMoney(payment.amount)} · {payment.method} · {payment.paid_at.slice(0, 10)}
          </Text>
        ) : null}
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Field label="Reason" value={reason} onChangeText={setReason} />
          <Button title="Void payment" onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}
