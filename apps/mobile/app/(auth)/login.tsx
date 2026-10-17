import { useState } from "react";
import { View } from "react-native";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { takePendingInvite } from "@/lib/invite";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";

const ROLE_CHIPS = ["owner", "manager", "staff"] as const;

export default function LoginScreen() {
  const router = useRouter();
  const [role, setRole] = useState<(typeof ROLE_CHIPS)[number]>("owner");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function signIn() {
    setBusy(true);
    setError(null);
    try {
      const supabase = getSupabase();
      const { error: e } = await supabase.auth.signInWithPassword({ email: identifier, password });
      if (e) throw e;
      const pendingInvite = await takePendingInvite();
      if (pendingInvite) {
        router.replace(`/(auth)/invite?token=${encodeURIComponent(pendingInvite)}`);
        return;
      }
      router.replace("/(app)/(tabs)");
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Fam
      </Text>
      <Text variant="muted">Property &amp; rental control</Text>

      <Card>
        <Text variant="semibold" color={colors.textMuted}>
          Sign in as
        </Text>
        <View style={{ flexDirection: "row", gap: 8 }}>
          {ROLE_CHIPS.map((r) => (
            <View key={r} style={{ flex: 1 }}>
              <Button
                title={r}
                variant={role === r ? "primary" : "ghost"}
                onPress={() => setRole(r)}
              />
            </View>
          ))}
        </View>

        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}

        <Field
          label={t("auth.email")}
          autoCapitalize="none"
          keyboardType="email-address"
          value={identifier}
          onChangeText={setIdentifier}
        />
        <Field label={t("auth.password")} secureTextEntry value={password} onChangeText={setPassword} />

        <Button title={t("auth.signIn")} onPress={signIn} loading={busy} />
        <Button
          title={t("auth.forgotPassword")}
          variant="ghost"
          onPress={() => router.push("/(auth)/forgot-password")}
        />
      </Card>

      <Button title={t("auth.signUp")} variant="ghost" onPress={() => router.push("/(auth)/sign-up")} />
    </Screen>
  );
}
