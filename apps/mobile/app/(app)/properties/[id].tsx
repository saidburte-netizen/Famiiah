import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Modal, ScrollView, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { createUnit, getProperty, listUnits, type UnitRow } from "@/features/api";

const KINDS = ["shop", "apartment", "office", "storage"] as const;

export default function PropertyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [property, setProperty] = useState<Record<string, unknown> | null>(null);
  const [units, setUnits] = useState<UnitRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!id) return;
    try {
      setError(null);
      const [p, u] = await Promise.all([getProperty(id), listUnits(id)]);
      setProperty(p as Record<string, unknown>);
      setUnits(u);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load property.");
    }
  }, [id]);

  useEffect(() => {
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [load]);

  if (loading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: String(property?.name ?? "Property") }} />
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}
      <Card>
        <Text variant="bold" color={colors.navy}>
          {String(property?.name ?? "")}
        </Text>
        <Text variant="muted">
          {String(property?.type ?? "")} · {String(property?.city ?? "—")}
        </Text>
        <Text variant="muted">
          {units.filter((u) => u.status === "rented").length}/{units.length} units rented
        </Text>
        <Button title="Add unit" onPress={() => setModal(true)} />
      </Card>

      <FlatList
        data={units}
        keyExtractor={(u) => u.id}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
        ListEmptyComponent={<Text variant="muted">No units yet.</Text>}
        renderItem={({ item }) => (
          <Card>
            <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
              <Text variant="bold" color={colors.navy}>
                {item.code}
              </Text>
              <Text
                variant="semibold"
                color={item.status === "vacant" ? colors.royal : colors.textMuted}
              >
                {item.status}
              </Text>
            </View>
            <Text variant="muted">
              {item.kind ?? "—"} · {item.monthly_rent ? `${item.monthly_rent} ETB` : "no rent"}
              {item.tenant_name ? ` · ${item.tenant_name}` : ""}
            </Text>
            {item.status === "vacant" ? (
              <Button
                title="Assign tenant"
                variant="ghost"
                onPress={() => router.push(`/(app)/tenants/new?unitId=${item.id}`)}
              />
            ) : null}
          </Card>
        )}
      />

      <AddUnitModal
        visible={modal}
        onClose={() => setModal(false)}
        onCreated={async () => {
          setModal(false);
          await load();
        }}
        propertyId={id ?? ""}
        orgId={String(property?.org_id ?? "")}
      />
    </Screen>
  );
}

function AddUnitModal({
  visible,
  propertyId,
  orgId,
  onClose,
  onCreated,
}: {
  visible: boolean;
  propertyId: string;
  orgId: string;
  onClose: () => void;
  onCreated: () => void | Promise<void>;
}) {
  const [code, setCode] = useState("");
  const [kind, setKind] = useState<(typeof KINDS)[number]>("shop");
  const [floorLabel, setFloorLabel] = useState("");
  const [monthlyRent, setMonthlyRent] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function save() {
    setError(null);
    if (!code) {
      setError("Unit code is required.");
      return;
    }
    if (!orgId) {
      setError("Could not determine the organization. Reload the screen.");
      return;
    }
    if (!/^\d+(\.\d{1,2})?$/.test(monthlyRent || "0")) {
      setError("Enter a valid rent.");
      return;
    }
    setBusy(true);
    try {
      await createUnit(orgId, {
        propertyId,
        code,
        kind,
        floorLabel: floorLabel || undefined,
        monthlyRent: monthlyRent || "0",
      });
      setCode("");
      setMonthlyRent("");
      setFloorLabel("");
      await onCreated();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create unit.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <ScrollView contentContainerStyle={{ padding: 20, gap: 16, backgroundColor: colors.background, flexGrow: 1 }}>
        <Text variant="display" color={colors.midnight}>
          New unit
        </Text>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Field label="Code" value={code} onChangeText={setCode} placeholder="e.g. A-101" />
          <Text variant="semibold" color={colors.textMuted}>
            Kind
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
            {KINDS.map((k) => (
              <View key={k} style={{ flexGrow: 1, minWidth: 90 }}>
                <Button title={k} variant={kind === k ? "primary" : "ghost"} onPress={() => setKind(k)} />
              </View>
            ))}
          </View>
          <Field label="Floor label" value={floorLabel} onChangeText={setFloorLabel} />
          <Field
            label="Monthly rent (ETB)"
            keyboardType="decimal-pad"
            value={monthlyRent}
            onChangeText={setMonthlyRent}
          />
          <Button title="Save unit" onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </ScrollView>
    </Modal>
  );
}
