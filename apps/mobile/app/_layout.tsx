import { useEffect, useState } from "react";
import { Slot, useRouter, useSegments } from "expo-router";
import { StatusBar } from "expo-status-bar";
import Constants from "expo-constants";
import { ActivityIndicator, Linking, Platform, Pressable, Text, View } from "react-native";
import type { Session } from "@supabase/supabase-js";
import { QueryProvider } from "@/lib/query";
import { getSupabase, startAutoRefresh } from "@/lib/supabase";
import { checkVersionGate, type GateDecision } from "@/lib/version-gate";
import { colors } from "@/theme/tokens";

export default function RootLayout() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [gate, setGate] = useState<GateDecision | null>(null);
  const router = useRouter();
  const segments = useSegments();

  useEffect(() => {
    const supabase = getSupabase();
    const stopRefresh = startAutoRefresh();

    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s);
    });

    return () => {
      sub.subscription.unsubscribe();
      stopRefresh();
    };
  }, []);

  // Version gate: blocks the app when the backend requires an update.
  useEffect(() => {
    if (!ready) return;
    let cancelled = false;
    const platform = Platform.OS === "ios" || Platform.OS === "android" ? Platform.OS : "web";
    const version = Constants.expoConfig?.version ?? "0.0.0";
    checkVersionGate(platform, version).then((decision) => {
      if (!cancelled) setGate(decision);
    });
    return () => {
      cancelled = true;
    };
  }, [ready]);

  // Route based on auth state once we know it.
  useEffect(() => {
    if (!ready || gate?.kind === "force_update") return;
    const segs = segments as unknown as string[];
    const inAuthGroup = segs[0] === "(auth)";
    const onInvite = inAuthGroup && segs[1] === "invite";
    if (!session && !inAuthGroup) {
      router.replace("/(auth)/login");
    } else if (session && inAuthGroup && !onInvite) {
      router.replace("/(app)/(tabs)");
    }
  }, [ready, session, segments, router, gate]);

  if (!ready || !gate) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: colors.midnight }}>
        <ActivityIndicator color={colors.ice} />
      </View>
    );
  }

  if (gate.kind === "force_update") {
    return (
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          gap: 16,
          padding: 32,
          backgroundColor: colors.midnight,
        }}
      >
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

  return (
    <QueryProvider>
      <StatusBar style="light" />
      <Slot />
    </QueryProvider>
  );
}
