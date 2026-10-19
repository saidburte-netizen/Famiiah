import { useEffect, useState } from "react";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";

/**
 * Finish a password reset: the user arrives from the `fam://reset-password`
 * link GoTrue emails. The root layout's `Linking` handler parses the recovery
 * tokens out of the URI fragment (`@fam/shared/deep-links`) and calls
 * `setSession`, which is what makes `hasSession` true here — supabase-js does
 * not do this itself on native (`detectSessionInUrl` is a browser-only path).
 *
 * Because that exchange is asynchronous, we subscribe to auth state instead of
 * reading the session once: otherwise a session that lands a moment after mount
 * would be missed and a perfectly good link would look expired. If no session
 * arrives shortly, the link really was expired or already used, and the screen
 * says so and offers a fresh link rather than failing with a raw error.
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
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) setHasSession(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) setHasSession(true);
    });
    // No session within this window means the token was expired or reused. The
    // updater leaves an already-found session (`true`) untouched.
    const timer = setTimeout(() => {
      setHasSession((prev) => (prev === null ? false : prev));
    }, 3000);
    return () => {
      clearTimeout(timer);
      sub.subscription.unsubscribe();
    };
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
