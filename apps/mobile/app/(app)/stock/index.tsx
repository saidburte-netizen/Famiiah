import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Modal, View } from "react-native";
import { Stack } from "expo-router";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { listStockItems, stockAdjust, type StockItemRow } from "@/features/api";

type AdjustTypeValue = "in" | "out" | "adjustment";

export default function StockScreen() {
  const { orgId } = useOrg();
  const [rows, setRows] = useState<StockItemRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<StockItemRow | null>(null);

  const load = useCallback(async () => {
    if (!orgId) return;
    setRows(await listStockItems(orgId));
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  return (
    <Screen>
      <Stack.Screen options={{ title: "Stock" }} />
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(r) => r.id}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          ListEmptyComponent={<Text variant="muted">No stock items yet.</Text>}
          renderItem={({ item }) => {
            const low = Number(item.quantity) <= Number(item.min_quantity);
            return (
              <Card>
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
                <Button title="Adjust" variant="ghost" onPress={() => setSelected(item)} />
              </Card>
            );
          }}
        />
      )}
      <AdjustModal
        item={selected}
        onClose={() => setSelected(null)}
        onDone={async () => {
          setSelected(null);
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
