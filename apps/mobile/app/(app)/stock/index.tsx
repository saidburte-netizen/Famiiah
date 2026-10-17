import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Modal, ScrollView, View } from "react-native";
import { Stack, useRouter } from "expo-router";
import { formatMoney } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import {
  listStockItems,
  listTenantsWithStatus,
  rentStockItem,
  stockAdjust,
  type StockItemRow,
  type TenantRow,
} from "@/features/api";

type AdjustTypeValue = "in" | "out" | "adjustment";

export default function StockScreen() {
  const { orgId } = useOrg();
  const router = useRouter();
  const [rows, setRows] = useState<StockItemRow[]>([]);
  const [tenants, setTenants] = useState<TenantRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [adjusting, setAdjusting] = useState<StockItemRow | null>(null);
  const [renting, setRenting] = useState<StockItemRow | null>(null);

  const load = useCallback(async () => {
    if (!orgId) return;
    const [items, ts] = await Promise.all([
      listStockItems(orgId),
      listTenantsWithStatus(orgId),
    ]);
    setRows(items);
    setTenants(ts);
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  return (
    <Screen>
      <Stack.Screen options={{ title: "Stock" }} />
      <Button title="Stock rentals" variant="ghost" onPress={() => router.push("/(app)/stock/rentals")} />
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <ScrollView contentContainerStyle={{ gap: 12 }}>
          {rows.length === 0 ? <Text variant="muted">No stock items yet.</Text> : null}
          {rows.map((item) => {
            const low = Number(item.quantity) <= Number(item.min_quantity);
            return (
              <Card key={item.id}>
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text variant="bold" color={colors.navy}>
                    {item.name}
                  </Text>
                  <Text variant="semibold" color={low ? colors.danger : colors.textMuted}>
                    {item.quantity} {item.uom}
                  </Text>
                </View>
                <Text variant="muted">
                  {item.sku ?? "no sku"}
                  {item.category ? ` · ${item.category}` : ""}
                  {item.is_rentable ? " · rentable" : ""}
                </Text>
                {low ? (
                  <Text variant="semibold" color={colors.danger}>
                    Low stock (min {item.min_quantity})
                  </Text>
                ) : null}
                <View style={{ flexDirection: "row", gap: 8, marginTop: 8 }}>
                  <View style={{ flex: 1 }}>
                    <Button title="Adjust" variant="ghost" onPress={() => setAdjusting(item)} />
                  </View>
                  {item.is_rentable && Number(item.quantity) > 0 ? (
                    <View style={{ flex: 1 }}>
                      <Button title="Rent out" onPress={() => setRenting(item)} />
                    </View>
                  ) : null}
                </View>
              </Card>
            );
          })}
        </ScrollView>
      )}

      <AdjustModal
        item={adjusting}
        onClose={() => setAdjusting(null)}
        onDone={async () => {
          setAdjusting(null);
          await load();
        }}
      />
      <RentModal
        item={renting}
        tenants={tenants}
        onClose={() => setRenting(null)}
        onDone={async () => {
          setRenting(null);
          await load();
        }}
      />
    </Screen>
  );
}

function AdjustModal({
  item,
  onClose,
  onDone,
}: {
  item: StockItemRow | null;
  onClose: () => void;
  onDone: () => void | Promise<void>;
}) {
  const [type, setType] = useState<AdjustTypeValue>("in");
  const [qty, setQty] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setQty("");
    setReason("");
    setError(null);
  }, [item]);

  async function save() {
    if (!item) return;
    setError(null);
    if (!/^\d+(\.\d{1,3})?$/.test(qty)) {
      setError("Enter a valid quantity.");
      return;
    }
    setBusy(true);
    try {
      await stockAdjust(item.id, type, qty, reason || undefined);
      await onDone();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not adjust stock.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={!!item} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, padding: 20, gap: 16, backgroundColor: colors.background }}>
        <Text variant="display" color={colors.midnight}>
          {item?.name ?? "Adjust"}
        </Text>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Text variant="semibold" color={colors.textMuted}>
            Movement
          </Text>
          <View style={{ flexDirection: "row", gap: 8 }}>
            {(["in", "out", "adjustment"] as const).map((t) => (
              <View key={t} style={{ flex: 1 }}>
                <Button
                  title={t}
                  variant={type === t ? "primary" : "ghost"}
                  onPress={() => setType(t)}
                />
              </View>
            ))}
          </View>
          <Field
            label={type === "adjustment" ? "Counted quantity" : "Quantity"}
            keyboardType="decimal-pad"
            value={qty}
            onChangeText={setQty}
          />
          <Field label="Reason" value={reason} onChangeText={setReason} />
          <Button title="Save" onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}

function RentModal({
  item,
  tenants,
  onClose,
  onDone,
}: {
  item: StockItemRow | null;
  tenants: TenantRow[];
  onClose: () => void;
  onDone: () => void | Promise<void>;
}) {
  const [tenantId, setTenantId] = useState<string | null>(null);
  const [qty, setQty] = useState("1");
  const [rate, setRate] = useState("");
  const [due, setDue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setTenantId(null);
    setQty("1");
    setRate(item?.rental_rate ?? "");
    const d = new Date();
    d.setDate(d.getDate() + 7);
    setDue(d.toISOString().slice(0, 10));
    setError(null);
  }, [item]);

  async function save() {
    if (!item) return;
    setError(null);
    if (!tenantId) {
      setError("Choose a tenant.");
      return;
    }
    if (!/^\d+(\.\d{1,3})?$/.test(qty)) {
      setError("Enter a valid quantity.");
      return;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(due)) {
      setError("Enter a due date as YYYY-MM-DD.");
      return;
    }
    setBusy(true);
    try {
      await rentStockItem({
        itemId: item.id,
        tenantId,
        qty,
        rate: rate || undefined,
        due,
      });
      await onDone();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not rent out the item.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={!!item} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, padding: 20, gap: 16, backgroundColor: colors.background }}>
        <Text variant="display" color={colors.midnight}>
          Rent out
        </Text>
        {item ? (
          <Text variant="muted">
            {item.name} · {item.quantity} {item.uom} available
            {item.rental_rate ? ` · ${formatMoney(item.rental_rate)}/day` : ""}
          </Text>
        ) : null}
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Text variant="semibold" color={colors.textMuted}>
            Tenant
          </Text>
          <ScrollView style={{ maxHeight: 200 }} contentContainerStyle={{ gap: 6 }}>
            {tenants.length === 0 ? (
              <Text variant="muted">No tenants yet.</Text>
            ) : (
              tenants.map((t) => (
                <Button
                  key={t.id}
                  title={t.full_name || t.id.slice(0, 8)}
                  variant={tenantId === t.id ? "primary" : "ghost"}
                  onPress={() => setTenantId(t.id)}
                />
              ))
            )}
          </ScrollView>
          <Field label="Quantity" keyboardType="decimal-pad" value={qty} onChangeText={setQty} />
          <Field
            label="Daily rate (ETB)"
            keyboardType="decimal-pad"
            value={rate}
            onChangeText={setRate}
          />
          <Field label="Due date (YYYY-MM-DD)" value={due} onChangeText={setDue} />
          <Button title="Rent out" onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}
