import { useEffect, useState } from "react";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";

/**
 * Finish a password reset: the user arrives from the `fam://reset-password`
 * link GoTrue emails. supabase-js consumes the recovery tokens in the URI
 * fragment and creates a session before this screen renders, so we only ask for
 * the new password and call `updateUser`.
 *
 * A link that expired or was already used carries no session — the screen says
 * so and offers the way back to sign-in rather than failing with a raw error.
 */
export default function ResetPasswordScreen() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasSession, setHasSession] = useState<boolean | null>(null);

  useEffect(() => {
    const supabase = getSupabase();
    supabase.auth.getSession().then(({ data }) => setHasSession(Boolean(data.session)));
  }, []);

  async function submit() {
    if (password.length < 8) {
      setError("Use at least 8 characters.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const supabase = getSupabase();
      const { error: e } = await supabase.auth.updateUser({ password });
      if (e) throw e;
      setDone(true);
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        {t("auth.resetPasswordTitle")}
      </Text>
      <Card>
        {done ? (
          <>
            <Text variant="medium" color={colors.navy}>
              {t("auth.passwordUpdated")}
            </Text>
            <Button title={t("auth.signIn")} onPress={() => router.replace("/(auth)/login")} />
          </>
        ) : hasSession === false ? (
          <>
            <Text variant="medium" color={colors.danger}>
              {t("error.invalidToken")}
            </Text>
            <Button
              title="Send a new link"
              onPress={() => router.replace("/(auth)/forgot-password")}
            />
          </>
        ) : (
          <>
            <Field
              label={t("auth.newPassword")}
              secureTextEntry
              value={password}
              onChangeText={setPassword}
            />
            <Text variant="muted">At least 8 characters, with an uppercase letter and a number.</Text>
            {error ? (
              <Text variant="medium" color={colors.danger}>
                {error}
              </Text>
            ) : null}
            <Button title={t("auth.updatePassword")} onPress={submit} loading={busy} />
          </>
        )}
      </Card>
    </Screen>
  );
}
