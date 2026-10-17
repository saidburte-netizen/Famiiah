import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Modal, View } from "react-native";
import { Stack } from "expo-router";
import { formatMoney } from "@fam/shared";
import { Button, Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { listStockRentals, returnStockItem, type StockRentalRow } from "@/features/api";

type RentalRow = StockRentalRow & {
  stock_items?: { name?: string } | null;
  tenants?: { full_name?: string } | null;
};

export default function StockRentalsScreen() {
  const { orgId } = useOrg();
  const [rows, setRows] = useState<RentalRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<RentalRow | null>(null);

  const load = useCallback(async () => {
    if (!orgId) return;
    setRows(await listStockRentals(orgId));
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  return (
    <Screen>
      <Stack.Screen options={{ title: "Stock rentals" }} />
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(r) => r.id}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          ListEmptyComponent={<Text variant="muted">Nothing rented out.</Text>}
          renderItem={({ item }) => {
            const open = item.status === "out" || item.status === "overdue";
            return (
              <Card>
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text variant="bold" color={colors.navy}>
                    {item.stock_items?.name ?? "Item"}
                  </Text>
                  <Text variant="semibold" color={open ? colors.navy : colors.textMuted}>
                    {item.status}
                  </Text>
                </View>
                <Text variant="muted">
                  {item.quantity} × {formatMoney(item.daily_rate)}/day · to{" "}
                  {item.tenants?.full_name ?? "tenant"}
                </Text>
                <Text variant="muted">
                  {item.start_date} → {item.due_date}
                </Text>
                {open ? (
                  <View style={{ marginTop: 8 }}>
                    <Button title="Return" variant="ghost" onPress={() => setSelected(item)} />
                  </View>
                ) : null}
              </Card>
            );
          }}
        />
      )}
      <ReturnModal
        rental={selected}
        onClose={() => setSelected(null)}
        onDone={async () => {
          setSelected(null);
          await load();
        }}
      />
    </Screen>
  );
}

function ReturnModal({
  rental,
  onClose,
  onDone,
}: {
  rental: RentalRow | null;
  onClose: () => void;
  onDone: () => void | Promise<void>;
}) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setError(null);
  }, [rental]);

  async function save() {
    if (!rental) return;
    setError(null);
    setBusy(true);
    try {
      await returnStockItem(rental.id);
      await onDone();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not return the item.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={!!rental} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, padding: 20, gap: 16, backgroundColor: colors.background }}>
        <Text variant="display" color={colors.midnight}>
          Return item
        </Text>
        {rental ? (
          <Text variant="muted">
            {rental.quantity} × {rental.stock_items?.name ?? "item"} from{" "}
            {rental.tenants?.full_name ?? "tenant"}
          </Text>
        ) : null}
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Button title="Confirm return" onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}
