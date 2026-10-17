import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, RefreshControl, View } from "react-native";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { listPropertiesWithStats } from "@/features/api";
import { Button, Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { formatMoney } from "@fam/shared";

interface PropertyRow {
  id: string;
  name: string;
  type: string;
  city: string | null;
  units_total: number;
  units_rented: number;
  occupancy_pct: number;
  monthly_total: string;
}

export default function PropertiesScreen() {
  const router = useRouter();
  const [rows, setRows] = useState<PropertyRow[]>([]);
  const [orgId, setOrgId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    const supabase = getSupabase();
    supabase
      .from("organization_members")
      .select("org_id")
      .eq("status", "active")
      .limit(1)
      .then(({ data }) => setOrgId(data?.[0]?.org_id ?? null));
  }, []);

  const load = useCallback(async () => {
    if (!orgId) return;
    const data = (await listPropertiesWithStats(orgId)) as PropertyRow[];
    setRows(data);
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  if (loading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Button title="New property" onPress={() => router.push("/(app)/properties/new")} />
      <FlatList
        data={rows}
        keyExtractor={(r) => r.id}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={async () => {
              setRefreshing(true);
              await load();
              setRefreshing(false);
            }}
          />
        }
        ListEmptyComponent={<Text variant="muted">No properties yet.</Text>}
        renderItem={({ item }) => (
          <Pressable onPress={() => router.push(`/(app)/properties/${item.id}`)}>
            <Card>
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text variant="bold" color={colors.navy}>
                  {item.name}
                </Text>
                <Text variant="semibold" color={colors.royal}>
                  {item.occupancy_pct}%
                </Text>
              </View>
              <Text variant="muted">
                {item.type} · {item.city ?? "—"}
              </Text>
              <Text variant="muted">
                {item.units_rented}/{item.units_total} units rented · {formatMoney(item.monthly_total)}/mo
              </Text>
            </Card>
          </Pressable>
        )}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
      />
    </Screen>
  );
}
