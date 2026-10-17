import { useState } from "react";
import { ActivityIndicator, FlatList, Pressable, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { listTenantsWithStatus } from "@/features/api";
import { Button, Card, ErrorState, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

const FILTERS = ["all", "active", "overdue", "expiring"] as const;

export default function TenantsScreen() {
  const router = useRouter();
  const { orgId, loading: orgLoading, error: orgError, refetch: refetchOrg } = useOrg();
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("all");

  const tenants = useQuery({
    queryKey: queryKeys.tenants(orgId ?? "none", filter),
    queryFn: () => listTenantsWithStatus(orgId as string, filter),
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
      {tenants.isLoading ? (
        <ActivityIndicator color={colors.royal} />
      ) : tenants.isError ? (
        <ErrorState message={userMessage(tenants.error)} onRetry={() => void tenants.refetch()} />
      ) : (
        <FlatList
          data={tenants.data ?? []}
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
