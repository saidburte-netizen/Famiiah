import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, RefreshControl, View } from "react-native";
import { getSupabase } from "@/lib/supabase";
import { listPropertiesWithStats } from "@/features/api";
import { Card, Screen, Text } from "@/components/ui";
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

  async function load() {
    if (!orgId) return;
    const data = (await listPropertiesWithStats(orgId)) as PropertyRow[];
    setRows(data);
  }

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId]);

  if (loading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
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
          <Card>
            <Text variant="bold" color={colors.navy}>
              {item.name}
            </Text>
            <Text variant="muted">
              {item.type} · {item.city ?? "—"}
            </Text>
            <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: 8 }}>
              <Text variant="muted">
                {item.units_rented}/{item.units_total} rented
              </Text>
              <Text variant="semibold">{formatMoney(item.monthly_total)}/mo</Text>
            </View>
          </Card>
        )}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
      />
    </Screen>
  );
}
