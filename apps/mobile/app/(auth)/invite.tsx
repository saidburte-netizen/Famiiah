import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import * as Crypto from "expo-crypto";
import { Button, Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { getSupabase } from "@/lib/supabase";
import { acceptInvitation } from "@/features/api";
import { savePendingInvite } from "@/lib/invite";

/**
 * Accept an organization invitation from the deep link
 * `fam://invite?token=<rawToken>`.
 *
 * `accept_invitation` matches on the SHA-256 hash of the raw token, so we hash
 * the incoming token before calling the RPC. If the visitor is not signed in we
 * stash the token and send them to sign in / sign up first.
 */
export default function InviteScreen() {
  const router = useRouter();
  const { token } = useLocalSearchParams<{ token?: string }>();
  const [state, setState] = useState<"checking" | "needs_auth" | "accepting" | "done" | "error">(
    "checking",
  );
  const [error, setError] = useState<string | null>(null);

  const accept = useCallback(
    async (raw: string) => {
      setState("accepting");
      setError(null);
      try {
        const hash = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, raw);
        await acceptInvitation(hash);
        setState("done");
        setTimeout(() => router.replace("/(app)/(tabs)"), 800);
      } catch (err) {
        const message = err instanceof Error ? err.message : "Could not accept the invitation.";
        setError(
          message === "invalid_token"
            ? "This invitation is invalid or has already been used."
            : message === "invitation_expired"
              ? "This invitation has expired. Ask an admin to send a new one."
              : message,
        );
        setState("error");
      }
    },
    [router],
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!token) {
        if (!cancelled) {
          setError("No invitation token was provided.");
          setState("error");
        }
        return;
      }
      const supabase = getSupabase();
      const { data } = await supabase.auth.getSession();
      if (cancelled) return;
      if (!data.session) {
        await savePendingInvite(token);
        setState("needs_auth");
        return;
      }
      await accept(token);
    })();
    return () => {
      cancelled = true;
    };
  }, [token, accept]);

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Organization invitation
      </Text>
      <Card>
        {state === "checking" || state === "accepting" ? (
          <>
            <ActivityIndicator color={colors.royal} />
            <Text variant="muted">
              {state === "checking" ? "Checking your invitation…" : "Joining the organization…"}
            </Text>
          </>
        ) : null}

        {state === "done" ? (
          <Text variant="medium" color={colors.royal}>
            You have joined the organization.
          </Text>
        ) : null}

        {state === "error" ? (
          <>
            <Text variant="medium" color={colors.danger}>
              {error}
            </Text>
            <Button title="Go to sign in" onPress={() => router.replace("/(auth)/login")} />
          </>
        ) : null}

        {state === "needs_auth" ? (
          <>
            <Text variant="muted">
              Sign in or create an account to accept this invitation. Your invitation is saved.
            </Text>
            <Button title="Sign in" onPress={() => router.replace("/(auth)/login")} />
            <Button
              title="Create an account"
              variant="ghost"
              onPress={() => router.replace("/(auth)/sign-up")}
            />
          </>
        ) : null}
      </Card>
    </Screen>
  );
}
