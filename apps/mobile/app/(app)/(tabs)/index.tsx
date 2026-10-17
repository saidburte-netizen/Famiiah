import { View, ScrollView, ActivityIndicator } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { dashboardSummary } from "@/features/api";
import { Button, Card, ErrorState, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { formatMoney } from "@fam/shared";
import { useOrg } from "@/lib/org";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

export default function DashboardScreen() {
  const router = useRouter();
  const { orgId, loading: orgLoading, error: orgError, refetch: refetchOrg } = useOrg();

  const summary = useQuery({
    queryKey: queryKeys.dashboard(orgId ?? "none"),
    queryFn: () => dashboardSummary(orgId as string),
    enabled: Boolean(orgId),
  });

  if (orgLoading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  if (orgError) {
    return (
      <Screen>
        <ErrorState message={userMessage(orgError)} onRetry={() => void refetchOrg()} />
      </Screen>
    );
  }

  if (!orgId) {
    return (
      <Screen>
        <ErrorState message="No organization is linked to this account yet." />
      </Screen>
    );
  }

  if (summary.isLoading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  if (summary.isError || !summary.data) {
    return (
      <Screen>
        <ErrorState message={userMessage(summary.error)} onRetry={() => void summary.refetch()} />
      </Screen>
    );
  }

  const data = summary.data;
  const tiles = [
    { label: "Collected", value: formatMoney(data.collected_month) },
    { label: "Expected", value: formatMoney(data.expected_month) },
    { label: "Occupancy", value: `${data.units_rented}/${data.units_total}` },
    { label: "Overdue", value: String(data.overdue_count) },
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
            {data.collection_rate}%
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
            {data.overdue_count} charge(s) · {formatMoney(data.overdue_amount)}
          </Text>
        </Card>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 12 }}>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button
              title={`Notifications${data.unread_notifications ? ` (${data.unread_notifications})` : ""}`}
              variant="ghost"
              onPress={() => router.push("/(app)/notifications")}
            />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Stock" variant="ghost" onPress={() => router.push("/(app)/stock")} />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Settings" variant="ghost" onPress={() => router.push("/(app)/settings")} />
          </View>
        </View>
      </ScrollView>
    </Screen>
  );
}
