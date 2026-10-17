import { useState } from "react";
import { useRouter } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { userMessage } from "@/lib/errors";

/** First-run: the signed-in user creates their organization (becomes owner). */
export default function CreateOrganizationScreen() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function create() {
    setBusy(true);
    setError(null);
    try {
      const supabase = getSupabase();
      const { error: e } = await supabase.rpc("create_organization", { p_name: name, p_slug: null });
      if (e) throw e;
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
        Create your organization
      </Text>
      <Text variant="muted">You&apos;ll be the owner of this workspace.</Text>
      <Card>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Field label="Organization name" value={name} onChangeText={setName} />
        <Button title="Create organization" onPress={create} loading={busy} />
      </Card>
      <Button title="I have an invitation" variant="ghost" onPress={() => router.replace("/(auth)/login")} />
    </Screen>
  );
}
