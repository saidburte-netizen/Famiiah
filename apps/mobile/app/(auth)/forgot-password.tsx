import { useState } from "react";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";

export default function ForgotPasswordScreen() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);

  async function send() {
    setBusy(true);
    try {
      const supabase = getSupabase();
      // Always report success to avoid account enumeration.
      await supabase.auth.resetPasswordForEmail(email, { redirectTo: "fam://reset-password" });
      setSent(true);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Reset password
      </Text>
      <Card>
        {sent ? (
          <Text variant="medium">
            If an account exists for that email, we&apos;ve sent a reset link. Check your inbox.
          </Text>
        ) : (
          <>
            <Field
              label={t("auth.email")}
              autoCapitalize="none"
              keyboardType="email-address"
              value={email}
              onChangeText={setEmail}
            />
            <Button title="Send reset link" onPress={send} loading={busy} />
          </>
        )}
      </Card>
      <Button title="Back to sign in" variant="ghost" onPress={() => router.replace("/(auth)/login")} />
    </Screen>
  );
}
