import { useEffect, useState } from "react";
import { View, ScrollView, ActivityIndicator } from "react-native";
import { getSupabase } from "@/lib/supabase";
import { dashboardSummary } from "@/features/api";
import { Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { formatMoney } from "@fam/shared";

interface Summary {
  collected_month: string;
  expected_month: string;
  collection_rate: number;
  properties_count: number;
  units_total: number;
  units_rented: number;
  units_vacant: number;
  active_tenants: number;
  overdue_count: number;
  overdue_amount: string;
  unread_notifications: number;
}

export default function DashboardScreen() {
  const [summary, setSummary] = useState<Summary | null>(null);
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
    dashboardSummary(orgId)
      .then((d) => setSummary(d as unknown as Summary))
      .finally(() => setLoading(false));
  }, [orgId]);

  if (loading || !summary) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  const tiles = [
    { label: "Collected", value: formatMoney(summary.collected_month) },
    { label: "Expected", value: formatMoney(summary.expected_month) },
    { label: "Occupancy", value: `${summary.units_rented}/${summary.units_total}` },
    { label: "Overdue", value: String(summary.overdue_count) },
  ];

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 16 }}>
        <Text variant="display" color={colors.midnight}>
          Dashboard
        </Text>
        <Card>
          <Text variant="muted">Collection rate this month</Text>
          <Text variant="extrabold" style={{ fontSize: 28 }} color={colors.navy}>
            {summary.collection_rate}%
          </Text>
        </Card>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 12 }}>
          {tiles.map((tile) => (
            <Card key={tile.label}>
              <View style={{ minWidth: 140 }}>
                <Text variant="muted">{tile.label}</Text>
                <Text variant="bold" color={colors.navy}>
                  {tile.value}
                </Text>
              </View>
            </Card>
          ))}
        </View>
        <Card>
          <Text variant="semibold">Overdue</Text>
          <Text variant="muted">
            {summary.overdue_count} charge(s) · {formatMoney(summary.overdue_amount)}
          </Text>
        </Card>
      </ScrollView>
    </Screen>
  );
}
