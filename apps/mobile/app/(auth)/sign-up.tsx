import { useState } from "react";
import { Pressable, View } from "react-native";
import { useRouter } from "expo-router";
import { SignUpSchema, toE164 } from "@fam/shared";
import { getSupabase } from "@/lib/supabase";
import { takePendingInvite } from "@/lib/invite";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";
import { userMessage } from "@/lib/errors";

/**
 * One form: @handle, phone number and password together, plus the terms that
 * have to be ticked. The phone is the GoTrue identifier, so the account signs
 * in with phone + password. If the project requires SMS code verification,
 * GoTrue returns no session and we ask for the OTP.
 */
export default function SignUpScreen() {
  const router = useRouter();
  const [handle, setHandle] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  /** E.164 number waiting for the SMS code to be verified. */
  const [pendingPhone, setPendingPhone] = useState<string | null>(null);
  const [code, setCode] = useState("");

  /** Maps a zod issue message to something a person can act on. */
  function fieldMessage(message: string): string {
    switch (message) {
      case "invalid_handle":
        return t("error.handleInvalid");
      case "must_accept_terms":
        return t("error.acceptTerms");
      case "invalid_phone":
        return t("error.invalidPhone");
      case "password_too_short":
        return "Use at least 8 characters.";
      case "password_needs_upper":
        return "Include an uppercase letter.";
      case "password_needs_digit":
        return "Include a number.";
      case "required":
        return "Fill in every field.";
      default:
        return t("error.unknown");
    }
  }

  async function submit() {
    setError(null);
    setNotice(null);
    const e164 = toE164(phone);
    if (!e164) {
      setError(t("error.invalidPhone"));
      return;
    }
    const parsed = SignUpSchema.safeParse({ handle, phone: e164, password, acceptTerms: acceptedTerms });
    if (!parsed.success) {
      setError(fieldMessage(parsed.error.issues[0]?.message ?? "required"));
      return;
    }
    setBusy(true);
    try {
      const supabase = getSupabase();
      // Handles are unique project-wide: ask before creating the account so
      // the user can pick another one; profiles.handle's unique index is what
      // actually guarantees it.
      const { data: available } = await supabase.rpc("handle_available", {
        p_handle: parsed.data.handle,
      });
      if (available === false) {
        setError(t("error.handleTaken"));
        return;
      }
      const { data, error: e } = await supabase.auth.signUp({
        phone: e164,
        password,
        options: {
          data: { handle: parsed.data.handle, accept_terms_at: new Date().toISOString() },
        },
      });
      if (e) throw e;
      if (!data.session) {
        setPendingPhone(e164);
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
          <View style={{ gap: 12 }}>
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
          </View>
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
        <View style={{ gap: 12 }}>
          {error ? (
            <Text variant="medium" color={colors.danger}>
              {error}
            </Text>
          ) : null}
          <Field
            label={t("auth.handle")}
            value={handle}
            onChangeText={setHandle}
            autoCapitalize="none"
            autoCorrect={false}
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
          <Pressable
            accessibilityRole="checkbox"
            accessibilityState={{ checked: acceptedTerms }}
            onPress={() => setAcceptedTerms(v => !v)}
            style={{
              flexDirection: "row",
              alignItems: "center",
              gap: 10,
              padding: 12,
              borderRadius: 16,
              borderWidth: 1,
              borderColor: acceptedTerms ? colors.royal : colors.border,
              backgroundColor: colors.white,
            }}
          >
            <View
              style={{
                width: 22,
                height: 22,
                borderRadius: 6,
                borderWidth: 1.5,
                borderColor: acceptedTerms ? colors.royal : colors.border,
                backgroundColor: acceptedTerms ? colors.royal : colors.white,
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              {acceptedTerms ? (
                <Text variant="bold" color={colors.white}>
                  ✓
                </Text>
              ) : null}
            </View>
            <Text variant="medium">{t("auth.acceptTerms")}</Text>
          </Pressable>
          <Button title={t("auth.signUp")} onPress={submit} loading={busy} />
        </View>
      </Card>
      <Button title={t("auth.signIn")} variant="ghost" onPress={() => router.replace("/(auth)/login")} />
    </Screen>
  );
}
