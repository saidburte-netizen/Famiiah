import { toE164 } from "@fam/shared";
import { getSupabase } from "@/lib/supabase";
import { takePendingInvite } from "@/lib/invite";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";
import { useState } from "react";
import { useRouter } from "expo-router";

export default function LoginScreen() {
  const router = useRouter();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function signIn() {
    setBusy(true);
    setError(null);
    try {
      const supabase = getSupabase();
      const id = identifier.trim();
      const email = id.includes("@") ? id : null;
      const phone = email ? null : toE164(id);
      if (!email && !phone) {
        setError(t("error.invalidPhone"));
        return;
      }
      // GoTrue takes one identifier per request: a verified email account or
      // a phone account. Both shapes are supported so older email accounts
      // still sign in.
      const { error: e } = email
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signInWithPassword({ phone: phone!, password });
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
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}

        <Field
          label={t("auth.phoneOrEmail")}
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
