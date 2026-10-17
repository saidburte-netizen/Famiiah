import { ActivityIndicator, FlatList, Pressable, RefreshControl, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { listPropertiesWithStats } from "@/features/api";
import { Button, Card, ErrorState, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { formatMoney } from "@fam/shared";
import { useOrg } from "@/lib/org";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

export default function PropertiesScreen() {
  const router = useRouter();
  const { orgId, loading: orgLoading, error: orgError, refetch: refetchOrg } = useOrg();

  const properties = useQuery({
    queryKey: queryKeys.properties(orgId ?? "none"),
    queryFn: () => listPropertiesWithStats(orgId as string),
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

  const rows = properties.data ?? [];

  return (
    <Screen>
      <Button title="New property" onPress={() => router.push("/(app)/properties/new")} />
      {properties.isLoading ? (
        <ActivityIndicator color={colors.royal} />
      ) : properties.isError ? (
        <ErrorState message={userMessage(properties.error)} onRetry={() => void properties.refetch()} />
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(r) => r.id}
          refreshControl={
            <RefreshControl
              refreshing={properties.isRefetching}
              onRefresh={() => void properties.refetch()}
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
      )}
    </Screen>
  );
}
