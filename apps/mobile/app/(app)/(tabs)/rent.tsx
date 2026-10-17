import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, View } from "react-native";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { rentOverview, sendReminder } from "@/features/api";
import { Button, Card, Screen, Text } from "@/components/ui";
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
  lease_id: string;
}

export default function RentScreen() {
  const router = useRouter();
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
      <Button title="Record payment" onPress={() => router.push("/(app)/payments/new")} />
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
          <Pressable onPress={() => router.push(`/(app)/payments/new?leaseId=${item.lease_id}`)}>
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
              {item.status === "overdue" || item.status === "pending" || item.status === "partial" ? (
                <View style={{ marginTop: 8 }}>
                  <Button
                    title="Send reminder"
                    variant="ghost"
                    onPress={() => {
                      void sendReminder(item.id);
                    }}
                  />
                </View>
              ) : null}
            </Card>
          </Pressable>
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
