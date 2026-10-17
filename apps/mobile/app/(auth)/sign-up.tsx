import { useState } from "react";
import { View } from "react-native";
import { useRouter } from "expo-router";
import { SignUpSchema } from "@fam/shared";
import { getSupabase } from "@/lib/supabase";
import { takePendingInvite } from "@/lib/invite";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";

const STEPS = ["Your details", "Password", "Terms"] as const;

export default function SignUpScreen() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

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
      const { error: e } = await supabase.auth.signUp({
        email,
        password,
        phone,
        options: { data: { full_name: fullName } },
      });
      if (e) throw e;
      const pendingInvite = await takePendingInvite();
      if (pendingInvite) {
        router.replace(`/(auth)/invite?token=${encodeURIComponent(pendingInvite)}`);
        return;
      }
      router.replace("/(auth)/create-organization");
    } catch (err) {
      setError(err instanceof Error ? err.message : t("error.unknown"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Create account
      </Text>
      <View style={{ flexDirection: "row", gap: 6 }}>
        {STEPS.map((s, i) => (
          <View
            key={s}
            style={{
              flex: 1,
              height: 4,
              borderRadius: 2,
              backgroundColor: i <= step ? colors.royal : colors.border,
            }}
          />
        ))}
      </View>

      <Card>
        {step === 0 && (
          <>
            <Field label="Full name" value={fullName} onChangeText={setFullName} />
            <Field
              label={t("auth.email")}
              autoCapitalize="none"
              keyboardType="email-address"
              value={email}
              onChangeText={setEmail}
            />
            <Field label={t("auth.phone")} keyboardType="phone-pad" value={phone} onChangeText={setPhone} />
            <Button title="Continue" onPress={() => setStep(1)} />
          </>
        )}
        {step === 1 && (
          <>
            <Field label={t("auth.password")} secureTextEntry value={password} onChangeText={setPassword} />
            {error ? (
              <Text variant="medium" color={colors.danger}>
                {error}
              </Text>
            ) : null}
            <Button title="Continue" onPress={() => setStep(2)} />
          </>
        )}
        {step === 2 && (
          <>
            <Button
              title={acceptTerms ? "✓ Terms accepted" : "Accept terms"}
              variant={acceptTerms ? "primary" : "ghost"}
              onPress={() => setAcceptTerms(true)}
            />
            {error ? (
              <Text variant="medium" color={colors.danger}>
                {error}
              </Text>
            ) : null}
            <Button title="Create account" onPress={submit} loading={busy} />
          </>
        )}
      </Card>

      <Button title="Back to sign in" variant="ghost" onPress={() => router.replace("/(auth)/login")} />
    </Screen>
  );
}
