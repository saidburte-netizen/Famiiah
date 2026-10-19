import { useEffect, useState } from "react";
import { Slot, useRouter, useSegments } from "expo-router";
import { StatusBar } from "expo-status-bar";
import Constants from "expo-constants";
import { ActivityIndicator, Linking, Platform, Pressable, Text, View } from "react-native";
import { QueryProvider } from "@/lib/query";
import { AuthProvider, useAuth } from "@/lib/auth";
import { getSupabase, hasSupabaseEnv } from "@/lib/supabase";
import { checkVersionGate, type GateDecision } from "@/lib/version-gate";
import { colors } from "@/theme/tokens";
import { isAuthCallbackUrl, parseRecoveryTokens } from "@fam/shared";

// Render errors bubble here instead of white-screening the app.
export { ErrorBoundary } from "@/components/error-boundary";

export default function RootLayout() {
  if (!hasSupabaseEnv()) return <ConfigErrorScreen />;
  return (
    <QueryProvider>
      <StatusBar style="light" />
      <AuthProvider>
        <RootNavigator />
      </AuthProvider>
    </QueryProvider>
  );
}

/**
 * Owns the two app-wide gates: restore the session, then ask the backend
 * whether this client version is still supported. Routing only happens once
 * both are settled.
 */
function RootNavigator() {
  const { session, loading } = useAuth();
  const [gate, setGate] = useState<GateDecision | null>(null);
  const router = useRouter();
  const segments = useSegments();

  // Password reset: the recovery email links to `fam://reset-password` with the
  // tokens in the URI fragment (`#access_token=…&type=recovery`). supabase-js is
  // configured with `detectSessionInUrl: false` (its URL detection only runs in
  // a browser), so nothing turns those tokens into a session on its own —
  // without this the reset link is a dead end. We parse the fragment ourselves
  // and hand the tokens to `setSession`, which the reset screen then reads its
  // session from. Scoped to auth callbacks so the invite link is left alone.
  useEffect(() => {
    function handle(url: string | null) {
      if (!url || !isAuthCallbackUrl(url)) return;
      const tokens = parseRecoveryTokens(url);
      if (!tokens) return;
      getSupabase()
        .auth.setSession({
          access_token: tokens.accessToken,
          refresh_token: tokens.refreshToken,
        })
        .catch(() => {
          /* expired/already-used link — the reset screen shows a friendly notice */
        });
    }
    Linking.getInitialURL().then(handle).catch(() => undefined);
    const sub = Linking.addEventListener("url", ({ url }) => handle(url));
    return () => sub.remove();
  }, []);

  // Version gate: blocks the app when the backend requires an update.
  useEffect(() => {
    if (loading) return;
    let cancelled = false;
    const platform = Platform.OS === "ios" || Platform.OS === "android" ? Platform.OS : "web";
    const version = Constants.expoConfig?.version ?? "0.0.0";
    checkVersionGate(platform, version).then((decision) => {
      if (!cancelled) setGate(decision);
    });
    return () => {
      cancelled = true;
    };
  }, [loading]);

  // Route based on auth state once we know it.
  useEffect(() => {
    if (loading || gate?.kind === "force_update") return;
    const segs = segments as unknown as string[];
    const inAuthGroup = segs[0] === "(auth)";
    const onInvite = inAuthGroup && segs[1] === "invite";
    // Signed in but without a membership yet: the create-workspace screen must
    // stay reachable, otherwise sign-up with email confirmation disabled dead-ends.
    const onCreateOrg = inAuthGroup && segs[1] === "create-organization";
    // The password-reset link creates a *recovery* session, so this screen is
    // reachable while signed in — without the exception the user would be sent
    // to the tabs before they could choose a new password.
    const onResetPassword = inAuthGroup && segs[1] === "reset-password";
    if (!session && !inAuthGroup) {
      router.replace("/(auth)/login");
    } else if (session && inAuthGroup && !onInvite && !onCreateOrg && !onResetPassword) {
      router.replace("/(app)/(tabs)");
    }
  }, [loading, session, segments, router, gate]);

  if (loading || !gate) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={colors.ice} />
      </View>
    );
  }

  if (gate.kind === "force_update") {
    return (
      <View style={[styles.center, { gap: 16, padding: 32 }]}>
        <Text style={{ color: colors.ice, fontSize: 22, fontWeight: "700", textAlign: "center" }}>
          Update required
        </Text>
        <Text style={{ color: colors.ice, textAlign: "center", opacity: 0.8 }}>
          {gate.notes ?? "A newer version of Fam is required to continue."}
        </Text>
        {gate.storeUrl ? (
          <Pressable
            onPress={() => Linking.openURL(gate.storeUrl as string)}
            style={{
              backgroundColor: colors.royal,
              paddingHorizontal: 24,
              paddingVertical: 12,
              borderRadius: 12,
            }}
          >
            <Text style={{ color: colors.white, fontWeight: "700" }}>Update now</Text>
          </Pressable>
        ) : null}
      </View>
    );
  }

  return <Slot />;
}

/** Shown when the build was not given its public Supabase config. */
function ConfigErrorScreen() {
  return (
    <View style={[styles.center, { gap: 12, padding: 32 }]}>
      <Text style={{ color: colors.ice, fontSize: 20, fontWeight: "700", textAlign: "center" }}>
        Configuration missing
      </Text>
      <Text style={{ color: colors.ice, textAlign: "center", opacity: 0.8 }}>
        This build is missing EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY.
      </Text>
    </View>
  );
}

const styles = {
  center: {
    flex: 1,
    alignItems: "center" as const,
    justifyContent: "center" as const,
    backgroundColor: colors.midnight,
  },
};
