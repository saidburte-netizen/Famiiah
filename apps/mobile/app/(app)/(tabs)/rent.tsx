import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, View } from "react-native";
import { getSupabase } from "@/lib/supabase";
import { rentOverview } from "@/features/api";
import { Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { formatMoney } from "@fam/shared";

interface ChargeRow {
  id: string;
  amount: string;
  amount_paid: string;
  status: string;
  due_date: string;
  tenant_name: string;
  unit_code: string;
}

export default function RentScreen() {
  const [rows, setRows] = useState<ChargeRow[]>([]);
  const [totals, setTotals] = useState({ expected: "0", collected: "0", outstanding: "0" });
  const [orgId, setOrgId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const month = new Date().toISOString().slice(0, 7) + "-01";

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
    rentOverview(orgId, month)
      .then((d) => {
        setRows(d.rows as ChargeRow[]);
        setTotals({
          expected: String(d.expected),
          collected: String(d.collected),
          outstanding: String(d.outstanding),
        });
      })
      .finally(() => setLoading(false));
  }, [orgId, month]);

  if (loading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Card>
        <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
          <Stat label="Expected" value={formatMoney(totals.expected)} />
          <Stat label="Collected" value={formatMoney(totals.collected)} />
          <Stat label="Outstanding" value={formatMoney(totals.outstanding)} />
        </View>
      </Card>
      <FlatList
        data={rows}
        keyExtractor={(r) => r.id}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
        ListEmptyComponent={<Text variant="muted">No charges this month.</Text>}
        renderItem={({ item }) => (
          <Card>
            <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
              <Text variant="bold" color={colors.navy}>
                {item.unit_code} · {item.tenant_name}
              </Text>
              <Text
                variant="semibold"
                color={item.status === "overdue" ? colors.danger : colors.textMuted}
              >
                {item.status}
              </Text>
            </View>
            <Text variant="muted">
              {formatMoney(item.amount)} · due {item.due_date} · paid {formatMoney(item.amount_paid)}
            </Text>
          </Card>
        )}
      />
    </Screen>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View>
      <Text variant="muted">{label}</Text>
      <Text variant="bold" color={colors.navy}>
        {value}
      </Text>
    </View>
  );
}
