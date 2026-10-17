import { useEffect, useState } from "react";
import { Alert } from "react-native";
import { Stack, useRouter } from "expo-router";
import Constants from "expo-constants";
import { Button, Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { getSupabase } from "@/lib/supabase";
import { useOrg } from "@/lib/org";

export default function SettingsScreen() {
  const router = useRouter();
  const { role } = useOrg();
  const [email, setEmail] = useState<string | null>(null);
  const [name, setName] = useState<string | null>(null);
  const version = Constants.expoConfig?.version ?? "1.0.0";

  useEffect(() => {
    const supabase = getSupabase();
    supabase.auth.getUser().then(({ data }) => {
      setEmail(data.user?.email ?? null);
      setName((data.user?.user_metadata?.full_name as string | undefined) ?? null);
    });
  }, []);

  async function signOut() {
    const supabase = getSupabase();
    await supabase.auth.signOut();
    router.replace("/(auth)/login");
  }

  function confirmSignOut() {
    Alert.alert("Sign out", "Are you sure you want to sign out?", [
      { text: "Cancel", style: "cancel" },
      { text: "Sign out", style: "destructive", onPress: signOut },
    ]);
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "Settings" }} />
      <Card>
        <Text variant="muted">Signed in as</Text>
        <Text variant="bold" color={colors.navy}>
          {name ?? "—"}
        </Text>
        <Text variant="muted">{email ?? "—"}</Text>
        {role ? <Text variant="muted">Role: {role}</Text> : null}
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Payments
        </Text>
        <Text variant="muted">Every recorded payment, with receipts and voiding.</Text>
        <Button
          title="Payment history"
          variant="ghost"
          onPress={() => router.push("/(app)/payments")}
        />
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Reports
        </Text>
        <Text variant="muted">Collections, occupancy and overdue ageing.</Text>
        <Button title="Open reports" variant="ghost" onPress={() => router.push("/(app)/reports")} />
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Notifications
        </Text>
        <Text variant="muted">Reminders, receipts and overdue alerts.</Text>
        <Button
          title="Open notifications"
          variant="ghost"
          onPress={() => router.push("/(app)/notifications")}
        />
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          About
        </Text>
        <Text variant="muted">App version {version}</Text>
        <Text variant="muted">Currency ETB · Timezone Africa/Addis_Ababa</Text>
      </Card>

      <Button title="Sign out" variant="ghost" onPress={confirmSignOut} />
    </Screen>
  );
}
