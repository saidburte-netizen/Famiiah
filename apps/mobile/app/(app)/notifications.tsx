import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, FlatList, RefreshControl, View } from "react-native";
import { Stack } from "expo-router";
import { Button, Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import {
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type NotificationRow,
} from "@/features/api";

export default function NotificationsScreen() {
  const { orgId } = useOrg();
  const [rows, setRows] = useState<NotificationRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    if (!orgId) return;
    const data = await listNotifications(orgId);
    setRows(data);
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  async function markOne(id: string) {
    await markNotificationRead(id);
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status: "read", read_at: new Date().toISOString() } : r)));
  }

  async function markAll() {
    if (!orgId) return;
    await markAllNotificationsRead(orgId);
    setRows((prev) => prev.map((r) => ({ ...r, status: "read" })));
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "Notifications" }} />
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <>
          <View style={{ flexDirection: "row", justifyContent: "flex-end" }}>
            <Button title="Mark all read" variant="ghost" onPress={markAll} />
          </View>
          <FlatList
            data={rows}
            keyExtractor={(r) => r.id}
            ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
            refreshControl={
              <RefreshControl
                refreshing={refreshing}
                onRefresh={async () => {
                  setRefreshing(true);
                  await load();
                  setRefreshing(false);
                }}
              />
            }
            ListEmptyComponent={<Text variant="muted">{"You're all caught up."}</Text>}
            renderItem={({ item }) => (
              <Card>
                <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                  <Text variant="bold" color={colors.navy}>
                    {item.title}
                  </Text>
                  {item.status !== "read" ? <Text variant="semibold" color={colors.royal}>New</Text> : null}
                </View>
                {item.body ? <Text variant="muted">{item.body}</Text> : null}
                <Text variant="muted">{new Date(item.created_at).toLocaleString()}</Text>
                {item.status !== "read" ? (
                  <Button title="Mark read" variant="ghost" onPress={() => markOne(item.id)} />
                ) : null}
              </Card>
            )}
          />
        </>
      )}
    </Screen>
  );
}
