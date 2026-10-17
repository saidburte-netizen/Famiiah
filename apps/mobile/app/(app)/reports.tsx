import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, ScrollView, View } from "react-native";
import { Stack } from "expo-router";
import { formatMoney } from "@fam/shared";
import { Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { reportCollections, reportOccupancy, reportOverdueAgeing } from "@/features/api";

interface CollectionRow {
  bucket: string;
  expected: number;
  collected: number;
  outstanding: number;
}
interface OccupancyRow {
  bucket: string;
  total_units: number;
  rented_units: number;
  occupancy_pct: number;
}
interface AgeingRow {
  ageing: string;
  charges: number;
  amount: string;
}

function iso(d: Date) {
  return d.toISOString().slice(0, 10);
}

export default function ReportsScreen() {
  const { orgId } = useOrg();
  const [collections, setCollections] = useState<CollectionRow[]>([]);
  const [occupancy, setOccupancy] = useState<OccupancyRow[]>([]);
  const [ageing, setAgeing] = useState<AgeingRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!orgId) return;
    const to = new Date();
    const from = new Date();
    from.setMonth(from.getMonth() - 5);
    from.setDate(1);
    const [c, o, a] = await Promise.all([
      reportCollections(orgId, iso(from), iso(to), "month"),
      reportOccupancy(orgId, iso(from), iso(to)),
      reportOverdueAgeing(orgId),
    ]);
    setCollections(c as CollectionRow[]);
    setOccupancy(o as OccupancyRow[]);
    setAgeing(a as AgeingRow[]);
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    setError(null);
    load()
      .catch((e: unknown) => setError(e instanceof Error ? e.message : "Could not load reports."))
      .finally(() => setLoading(false));
  }, [orgId, load]);

  if (loading) {
    return (
      <Screen>
        <Stack.Screen options={{ title: "Reports" }} />
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "Reports" }} />
      <ScrollView contentContainerStyle={{ gap: 16 }}>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}

        <Card>
          <Text variant="semibold" color={colors.navy}>
            Collections (last 6 months)
          </Text>
          {collections.length === 0 ? (
            <Text variant="muted">No data.</Text>
          ) : (
            collections.map((r) => (
              <View
                key={r.bucket}
                style={{ flexDirection: "row", justifyContent: "space-between" }}
              >
                <Text variant="muted">{r.bucket}</Text>
                <Text variant="muted">
                  {formatMoney(r.collected)} / {formatMoney(r.expected)}
                </Text>
                <Text variant="semibold" color={Number(r.outstanding) > 0 ? colors.danger : colors.textMuted}>
                  {formatMoney(r.outstanding)}
                </Text>
              </View>
            ))
          )}
        </Card>

        <Card>
          <Text variant="semibold" color={colors.navy}>
            Occupancy
          </Text>
          {occupancy.length === 0 ? (
            <Text variant="muted">No data.</Text>
          ) : (
            occupancy.map((r) => (
              <View
                key={r.bucket}
                style={{ flexDirection: "row", justifyContent: "space-between" }}
              >
                <Text variant="muted">{r.bucket}</Text>
                <Text variant="muted">
                  {r.rented_units}/{r.total_units} units
                </Text>
                <Text variant="semibold" color={colors.navy}>
                  {r.occupancy_pct}%
                </Text>
              </View>
            ))
          )}
        </Card>

        <Card>
          <Text variant="semibold" color={colors.navy}>
            Overdue ageing
          </Text>
          {ageing.length === 0 ? (
            <Text variant="muted">Nothing overdue.</Text>
          ) : (
            ageing.map((r) => (
              <View
                key={r.ageing}
                style={{ flexDirection: "row", justifyContent: "space-between" }}
              >
                <Text variant="muted">{r.ageing}</Text>
                <Text variant="muted">{r.charges} charges</Text>
                <Text variant="semibold" color={colors.danger}>
                  {formatMoney(r.amount)}
                </Text>
              </View>
            ))
          )}
        </Card>
      </ScrollView>
    </Screen>
  );
}
