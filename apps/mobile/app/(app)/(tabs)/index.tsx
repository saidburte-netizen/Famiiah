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
    // A signed-in user with no membership is not a dead end: they can create
    // their own workspace (or accept a pending invitation) from here.
    return (
      <Screen>
        <Card>
          <Text variant="semibold">No workspace yet</Text>
          <Text variant="muted">
            Create an organization to start managing properties, tenants and rent.
          </Text>
          <Button
            title="Create organization"
            onPress={() => router.push("/(auth)/create-organization")}
          />
          <Button title="Refresh" variant="ghost" onPress={() => void refetchOrg()} />
        </Card>
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
        {data.due_this_week?.length ? (
          <Card>
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
              <Text variant="semibold">Due this week</Text>
              <Button title="See all" variant="ghost" onPress={() => router.push("/(app)/(tabs)/rent")} />
            </View>
            {data.due_this_week.map((c) => (
              <View
                key={c.id}
                style={{ flexDirection: "row", justifyContent: "space-between", paddingVertical: 4 }}
              >
                <Text variant="muted">
                  {c.tenant_name} · unit {c.unit_code}
                </Text>
                <Text variant="semibold" color={colors.navy}>
                  {c.due_date} · {formatMoney(c.amount)}
                </Text>
              </View>
            ))}
          </Card>
        ) : null}
        <Text variant="semibold">Quick actions</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 12 }}>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button
              title="Property"
              variant="ghost"
              onPress={() => router.push("/(app)/properties/new")}
            />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Unit" variant="ghost" onPress={() => router.push("/(app)/units/new")} />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Tenant" variant="ghost" onPress={() => router.push("/(app)/tenants/new")} />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Stock" variant="ghost" onPress={() => router.push("/(app)/stock")} />
          </View>
        </View>
        <Button title="Record payment" onPress={() => router.push("/(app)/payments/new")} />
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 12 }}>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Payments" variant="ghost" onPress={() => router.push("/(app)/payments")} />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Reports" variant="ghost" onPress={() => router.push("/(app)/reports")} />
          </View>
        </View>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 12 }}>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button
              title={`Notifications${data.unread_notifications ? ` (${data.unread_notifications})` : ""}`}
              variant="ghost"
              onPress={() => router.push("/(app)/notifications")}
            />
          </View>
          <View style={{ flexGrow: 1, minWidth: 140 }}>
            <Button title="Settings" variant="ghost" onPress={() => router.push("/(app)/settings")} />
          </View>
        </View>
      </ScrollView>
    </Screen>
  );
}
