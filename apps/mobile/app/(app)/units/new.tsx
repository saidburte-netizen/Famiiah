import { useMemo, useState } from "react";
import { ActivityIndicator, Pressable, View } from "react-native";
import { Stack, useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { createUnit, listPropertiesWithStats } from "@/features/api";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

const KINDS = ["shop", "apartment", "office", "storage"] as const;

/** Global "new unit" entry point used by the dashboard quick actions. */
export default function NewUnitScreen() {
  const router = useRouter();
  const { orgId } = useOrg();

  const [propertyId, setPropertyId] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [kind, setKind] = useState<(typeof KINDS)[number]>("shop");
  const [floorLabel, setFloorLabel] = useState("");
  const [monthlyRent, setMonthlyRent] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const properties = useQuery({
    queryKey: queryKeys.properties(orgId ?? "none"),
    queryFn: () => listPropertiesWithStats(orgId as string),
    enabled: Boolean(orgId),
  });

  const rows = useMemo(() => properties.data ?? [], [properties.data]);
  const selectedId = propertyId ?? rows[0]?.id ?? null;

  async function save() {
    setError(null);
    if (!orgId) {
      setError("No active organization.");
      return;
    }
    if (!selectedId) {
      setError("Pick a property.");
      return;
    }
    if (!code.trim()) {
      setError("Unit code is required.");
      return;
    }
    setBusy(true);
    try {
      await createUnit(orgId, {
        propertyId: selectedId,
        code: code.trim(),
        kind,
        floorLabel: floorLabel.trim() || undefined,
        monthlyRent: monthlyRent.trim() || "0",
      });
      router.back();
    } catch (e) {
      setError(userMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "New unit" }} />
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Property
        </Text>
        {properties.isLoading ? (
          <ActivityIndicator color={colors.royal} />
        ) : rows.length === 0 ? (
          <Text variant="muted">Create a property first.</Text>
        ) : (
          <View style={{ gap: 8 }}>
            {rows.slice(0, 30).map((p) => {
              const selected = p.id === selectedId;
              return (
                <Pressable key={p.id} onPress={() => setPropertyId(p.id)}>
                  <View
                    style={{
                      borderWidth: 1,
                      borderColor: selected ? colors.royal : colors.border,
                      borderRadius: 12,
                      padding: 12,
                      backgroundColor: selected ? colors.tint : colors.white,
                    }}
                  >
                    <Text variant="semibold" color={colors.navy}>
                      {p.name}
                    </Text>
                    <Text variant="muted">
                      {p.type} · {p.city ?? "—"}
                    </Text>
                  </View>
                </Pressable>
              );
            })}
          </View>
        )}
      </Card>

      <Card>
        <Field label="Unit code" value={code} onChangeText={setCode} />
        <Text variant="semibold" color={colors.textMuted}>
          Kind
        </Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
          {KINDS.map((k) => (
            <View key={k} style={{ minWidth: 90, flexGrow: 1 }}>
              <Button
                title={k}
                variant={kind === k ? "primary" : "ghost"}
                onPress={() => setKind(k)}
              />
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
      </Card>

      <Button title="Save unit" loading={busy} onPress={save} />
    </Screen>
  );
}
