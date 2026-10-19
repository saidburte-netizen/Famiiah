import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Modal, ScrollView, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useQueryClient } from "@tanstack/react-query";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { createUnit, getProperty, listUnits, type UnitRow } from "@/features/api";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

const KINDS = ["shop", "apartment", "office", "storage"] as const;

export default function PropertyDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [property, setProperty] = useState<Record<string, unknown> | null>(null);
  const [units, setUnits] = useState<UnitRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<"all" | "rented" | "vacant" | "overdue">("all");

  const load = useCallback(async () => {
    if (!id) return;
    try {
      setError(null);
      const [p, u] = await Promise.all([getProperty(id), listUnits(id)]);
      setProperty(p as Record<string, unknown>);
      setUnits(u);
    } catch (e) {
      setError(userMessage(e));
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

  const rented = units.filter((u) => u.status === "rented").length;
  const vacant = units.filter((u) => u.status === "vacant").length;
  const overdue = units.filter((u) => u.overdue === true).length;
  const counts: Record<typeof filter, number> = {
    all: units.length,
    rented,
    vacant,
    overdue,
  };
  const visible = units.filter((u) => {
    if (filter === "rented") return u.status === "rented";
    if (filter === "vacant") return u.status === "vacant";
    if (filter === "overdue") return u.overdue === true;
    return true;
  });

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
          {rented} rented · {vacant} vacant · {units.length} units
        </Text>
        <Button title="Add unit" onPress={() => setModal(true)} />
      </Card>

      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
        {(["all", "rented", "vacant", "overdue"] as const).map((f) => (
          <View key={f} style={{ minWidth: 90, flexGrow: 1 }}>
            <Button
              title={`${f[0].toUpperCase()}${f.slice(1)} (${counts[f]})`}
              variant={filter === f ? "primary" : "ghost"}
              onPress={() => setFilter(f)}
            />
          </View>
        ))}
      </View>

      <FlatList
        data={visible}
        keyExtractor={(u) => u.id}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
        ListEmptyComponent={
          <Text variant="muted">
            {filter === "all" ? "No units yet." : "No units match this filter."}
          </Text>
        }
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
            {item.overdue ? (
              <Text variant="semibold" color={colors.danger}>
                Rent overdue
              </Text>
            ) : null}
            {item.status === "vacant" ? (
              <View style={{ flexDirection: "row", gap: 8, marginTop: 8 }}>
                <View style={{ flex: 1 }}>
                  <Button
                    title="New tenant"
                    onPress={() => router.push(`/(app)/tenants/new?unitId=${item.id}`)}
                  />
                </View>
                <View style={{ flex: 1 }}>
                  <Button
                    title="Existing"
                    variant="ghost"
                    onPress={() =>
                      router.push(
                        `/(app)/units/${item.id}/assign?propertyId=${id}&code=${encodeURIComponent(
                          item.code,
                        )}&rent=${item.monthly_rent ?? ""}`,
                      )
                    }
                  />
                </View>
              </View>
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
          // The properties tab shows unit counts; refresh it too.
          if (property?.org_id) {
            await queryClient.invalidateQueries({
              queryKey: queryKeys.properties(String(property.org_id)),
            });
            await queryClient.invalidateQueries({
              queryKey: queryKeys.dashboard(String(property.org_id)),
            });
          }
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
      setError(userMessage(err));
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
