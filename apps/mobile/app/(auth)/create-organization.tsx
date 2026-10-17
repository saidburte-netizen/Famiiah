import { useState } from "react";
import { useRouter } from "expo-router";
import { useQueryClient } from "@tanstack/react-query";
import { getSupabase } from "@/lib/supabase";
import { queryKeys } from "@/lib/query";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { userMessage } from "@/lib/errors";

/**
 * First-run: the signed-in user creates their organization (becomes owner).
 * Reachable while signed in — see the `create-organization` guard in the root
 * layout, without which sign-up would dead-end here.
 */
export default function CreateOrganizationScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();
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
      // The active-org query cached "no membership"; drop it before routing so
      // the dashboard comes up already pointing at the new organization.
      await queryClient.invalidateQueries({ queryKey: queryKeys.activeOrg });
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
