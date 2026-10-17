import { ActivityIndicator, Alert, FlatList, Pressable, View } from "react-native";
import { useRouter } from "expo-router";
import { useMutation, useQuery } from "@tanstack/react-query";
import { rentOverview, sendReminder } from "@/features/api";
import { Button, Card, ErrorState, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { formatMoney } from "@fam/shared";
import { useOrg } from "@/lib/org";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

export default function RentScreen() {
  const router = useRouter();
  const { orgId, loading: orgLoading, error: orgError, refetch: refetchOrg } = useOrg();
  const month = new Date().toISOString().slice(0, 7) + "-01";

  const rent = useQuery({
    queryKey: queryKeys.rent(orgId ?? "none", month),
    queryFn: () => rentOverview(orgId as string, month),
    enabled: Boolean(orgId),
  });

  const reminder = useMutation({
    mutationFn: (chargeId: string) => sendReminder(chargeId),
    onError: (e) => Alert.alert("Couldn't send reminder", userMessage(e)),
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

  if (rent.isLoading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  if (rent.isError || !rent.data) {
    return (
      <Screen>
        <ErrorState message={userMessage(rent.error)} onRetry={() => void rent.refetch()} />
      </Screen>
    );
  }

  const { rows, expected, collected, outstanding } = rent.data;

  return (
    <Screen>
      <Button title="Record payment" onPress={() => router.push("/(app)/payments/new")} />
      <View style={{ flexDirection: "row", gap: 12 }}>
        <View style={{ flex: 1 }}>
          <Stat label="Expected" value={formatMoney(expected)} />
        </View>
        <View style={{ flex: 1 }}>
          <Stat label="Collected" value={formatMoney(collected)} />
        </View>
        <View style={{ flex: 1 }}>
          <Stat label="Outstanding" value={formatMoney(outstanding)} />
        </View>
      </View>

      {rent.isFetching ? <ActivityIndicator color={colors.royal} /> : null}

      <FlatList
        data={rows}
        keyExtractor={(r) => r.id}
        ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
        ListEmptyComponent={<Text variant="muted">No charges this month.</Text>}
        renderItem={({ item }) => {
          const owes = ["overdue", "pending", "partial"].includes(item.status);
          return (
            <Pressable onPress={() => router.push(`/(app)/payments/new?leaseId=${item.lease_id}`)}>
              <Card>
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text variant="bold" color={colors.navy}>
                    {item.tenant_name}
                  </Text>
                  <Text variant="semibold" color={item.status === "overdue" ? colors.danger : colors.textMuted}>
                    {item.status}
                  </Text>
                </View>
                <Text variant="muted">
                  {item.unit_code} · due {item.due_date} · {formatMoney(item.amount)}
                </Text>
                <Text variant="muted">
                  Paid {formatMoney(item.amount_paid)}
                </Text>
                {owes ? (
                  <View style={{ marginTop: 8 }}>
                    <Button
                      title={reminder.isPending && reminder.variables === item.id ? "Sending…" : "Send reminder"}
                      variant="ghost"
                      disabled={reminder.isPending}
                      onPress={() => reminder.mutate(item.id)}
                    />
                  </View>
                ) : null}
              </Card>
            </Pressable>
          );
        }}
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
