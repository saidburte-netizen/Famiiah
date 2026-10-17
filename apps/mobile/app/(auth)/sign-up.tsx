import { useState } from "react";
import { View } from "react-native";
import { useRouter } from "expo-router";
import { SignUpSchema } from "@fam/shared";
import { getSupabase } from "@/lib/supabase";
import { takePendingInvite } from "@/lib/invite";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";

/**
 * One form: name, email, phone, password and the terms toggle together (the
 * three-step version hid the password behind a "Continue" button).
 */
export default function SignUpScreen() {
  const router = useRouter();
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  /** Set when the account was created but the email still needs confirming. */
  const [pendingEmail, setPendingEmail] = useState<string | null>(null);

  async function submit() {
    setError(null);
    const parsed = SignUpSchema.safeParse({
      fullName,
      email,
      phone,
      password,
      role: "owner",
      acceptTerms: acceptTerms as true,
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? t("error.unknown"));
      return;
    }
    setBusy(true);
    try {
      const supabase = getSupabase();
      // The phone number is profile data, not a sign-in identifier: sending it
      // as `phone` makes GoTrue reject the request ("Only an email address or
      // phone number should be provided on signup") unless phone sign-in is
      // enabled for the project. It travels in the metadata instead, where
      // `handle_new_user()` picks it up.
      const { data, error: e } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: fullName, phone } },
      });
      if (e) throw e;
      if (!data.session) {
        setPendingEmail(email);
        return;
      }
      const pendingInvite = await takePendingInvite();
      if (pendingInvite) {
        router.replace(`/(auth)/invite?token=${encodeURIComponent(pendingInvite)}`);
        return;
      }
      router.replace("/(auth)/create-organization");
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  if (pendingEmail) {
    return (
      <Screen>
        <Text variant="display" color={colors.midnight}>
          {t("auth.confirmEmailTitle")}
        </Text>
        <Card>
          <View style={{ gap: 12 }}>
            <Text variant="medium">{t("auth.confirmEmailBody")}</Text>
            <Text variant="semibold" color={colors.midnight}>
              {pendingEmail}
            </Text>
            <Text variant="muted">{t("auth.confirmEmailHint")}</Text>
            <Button title={t("auth.signIn")} onPress={() => router.replace("/(auth)/login")} />
            <Button
              title={t("auth.useAnotherEmail")}
              variant="ghost"
              onPress={() => setPendingEmail(null)}
            />
          </View>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Create account
      </Text>

      <Card>
        <View style={{ gap: 12 }}>
          {error ? (
            <Text variant="medium" color={colors.danger}>
              {error}
            </Text>
          ) : null}
          <Field label="Full name" value={fullName} onChangeText={setFullName} autoCapitalize="words" />
          <Field
            label={t("auth.email")}
            autoCapitalize="none"
            keyboardType="email-address"
            value={email}
            onChangeText={setEmail}
          />
          <Field label={t("auth.phone")} keyboardType="phone-pad" value={phone} onChangeText={setPhone} />
          <Field label={t("auth.password")} secureTextEntry value={password} onChangeText={setPassword} />
          <Text variant="muted">At least 8 characters, with an uppercase letter and a number.</Text>
          <Button
            title={acceptTerms ? "✓ Terms accepted (tap to undo)" : "Accept terms"}
            variant={acceptTerms ? "primary" : "ghost"}
            onPress={() => setAcceptTerms((v) => !v)}
          />
          <Button title={t("auth.signUp")} onPress={submit} loading={busy} />
        </View>
      </Card>

      <Button title={t("auth.signIn")} variant="ghost" onPress={() => router.replace("/(auth)/login")} />
    </Screen>
  );
}
