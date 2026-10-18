import { useState } from "react";
import { useRouter } from "expo-router";
import { SignUpSchema, toE164 } from "@fam/shared";
import { getSupabase } from "@/lib/supabase";
import { takePendingInvite } from "@/lib/invite";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";

/**
 * One form: username, phone number and password all together.
 * The phone is the GoTrue identifier, so the account signs in with phone +
 * password. If the project requires SMS code verification, GoTrue returns
 * no session and we ask for the OTP.
 */
export default function SignUpScreen() {
  const router = useRouter();
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  /** E.164 number waiting for the SMS code to be verified. */
  const [pendingPhone, setPendingPhone] = useState<string | null>(null);
  const [code, setCode] = useState("");

  async function submit() {
    setError(null);
    setNotice(null);
    const e164 = toE164(phone);
    const parsed = SignUpSchema.safeParse({
      fullName,
      phone: e164 ?? phone,
      password,
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? t("error.unknown"));
      return;
    }
    const normalized = e164!;
    setBusy(true);
    try {
      const supabase = getSupabase();
      const { data, error: e } = await supabase.auth.signUp({
        phone: normalized,
        password,
        options: { data: { full_name: fullName } },
      });
      if (e) throw e;
      if (!data.session) {
        setPendingPhone(normalized);
        return;
      }
      await afterAuth();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function verify() {
    if (!pendingPhone) return;
    setError(null);
    setNotice(null);
    if (code.trim().length < 4) {
      setError("Enter the code from the SMS.");
      return;
    }
    setBusy(true);
    try {
      const supabase = getSupabase();
      await supabase.auth.verifyOtp({ phone: pendingPhone, token: code.trim(), type: "sms" });
      await afterAuth();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    if (!pendingPhone) return;
    setError(null);
    setNotice(null);
    setBusy(true);
    try {
      const supabase = getSupabase();
      await supabase.auth.resend({ phone: pendingPhone, type: "sms" });
      setNotice(t("auth.codeSent"));
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function afterAuth() {
    const pendingInvite = await takePendingInvite();
    if (pendingInvite) {
      router.replace(`/(auth)/invite?token=${encodeURIComponent(pendingInvite)}`);
      return;
    }
    router.replace("/(auth)/create-organization");
  }

  if (pendingPhone) {
    return (
      <Screen>
        <Text variant="display" color={colors.midnight}>
          {t("auth.verifyPhoneTitle")}
        </Text>
        <Card>
          {error ? (
            <Text variant="medium" color={colors.danger}>
              {error}
            </Text>
          ) : null}
          {notice ? (
            <Text variant="medium" color={colors.navy}>
              {notice}
            </Text>
          ) : null}
          <Text variant="medium">{t("auth.verifyPhoneBody")}</Text>
          <Text variant="semibold" color={colors.midnight}>
            {pendingPhone}
          </Text>
          <Field
            label={t("auth.otpCode")}
            value={code}
            onChangeText={setCode}
            keyboardType="number-pad"
            autoCapitalize="none"
          />
          <Button title={t("auth.verify")} onPress={verify} loading={busy} />
          <Button title={t("auth.resendCode")} variant="ghost" onPress={resend} />
          <Button
            title={t("auth.changeNumber")}
            variant="ghost"
            onPress={() => {
              setPendingPhone(null);
              setCode("");
            }}
          />
        </Card>
        <Button title={t("auth.signIn")} variant="ghost" onPress={() => router.replace("/(auth)/login")} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Create account
      </Text>
      <Card>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Field
          label={t("auth.username")}
          value={fullName}
          onChangeText={setFullName}
          autoCapitalize="words"
        />
        <Field
          label={t("auth.phone")}
          keyboardType="phone-pad"
          value={phone}
          onChangeText={setPhone}
          autoCapitalize="none"
        />
        <Field label={t("auth.password")} secureTextEntry value={password} onChangeText={setPassword} />
        <Text variant="muted">At least 8 characters, with an uppercase letter and a number.</Text>
        <Button title={t("auth.signUp")} onPress={submit} loading={busy} />
      </Card>
      <Button title={t("auth.signIn")} variant="ghost" onPress={() => router.replace("/(auth)/login")} />
    </Screen>
  );
}
