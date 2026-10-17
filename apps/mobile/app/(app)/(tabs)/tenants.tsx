import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, View } from "react-native";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { listTenantsWithStatus } from "@/features/api";
import { Button, Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";

const FILTERS = ["all", "active", "overdue", "expiring"] as const;

interface TenantRow {
  id: string;
  full_name: string;
  phone: string | null;
  unit_code: string | null;
  monthly_rent: string | null;
  lease_end: string | null;
  overdue_days: number;
  status: string;
}

export default function TenantsScreen() {
  const router = useRouter();
  const [rows, setRows] = useState<TenantRow[]>([]);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("all");
  const [orgId, setOrgId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const supabase = getSupabase();
    supabase
      .from("organization_members")
      .select("org_id")
      .eq("status", "active")
      .limit(1)
      .then(({ data }) => setOrgId(data?.[0]?.org_id ?? null));
  }, []);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    listTenantsWithStatus(orgId, filter)
      .then((d) => setRows(d as TenantRow[]))
      .finally(() => setLoading(false));
  }, [orgId, filter]);

  return (
    <Screen>
      <Button title="New tenant" onPress={() => router.push("/(app)/tenants/new")} />
      <View style={{ flexDirection: "row", gap: 8, flexWrap: "wrap" }}>
        {FILTERS.map((f) => (
          <View key={f} style={{ flex: 1, minWidth: 80 }}>
            <Button title={f} variant={filter === f ? "primary" : "ghost"} onPress={() => setFilter(f)} />
          </View>
        ))}
      </View>
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(r) => r.id}
          ListEmptyComponent={<Text variant="muted">No tenants.</Text>}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          renderItem={({ item }) => (
            <Pressable onPress={() => router.push(`/(app)/tenants/${item.id}`)}>
              <Card>
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text variant="bold" color={colors.navy}>
                    {item.full_name}
                  </Text>
                  {item.overdue_days > 0 ? (
                    <Text variant="semibold" color={colors.danger}>
                      Overdue {item.overdue_days}d
                    </Text>
                  ) : (
                    <Text variant="semibold" color={colors.textMuted}>
                      {item.status}
                    </Text>
                  )}
                </View>
                <Text variant="muted">
                  {item.unit_code ?? "—"} · {item.phone ?? "no phone"}
                </Text>
              </Card>
            </Pressable>
          )}
        />
      )}
    </Screen>
  );
}
