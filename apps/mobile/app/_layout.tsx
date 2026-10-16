import { useEffect, useState } from "react";
import { Slot, useRouter, useSegments } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { ActivityIndicator, View } from "react-native";
import type { Session } from "@supabase/supabase-js";
import { QueryProvider } from "@/lib/query";
import { getSupabase, startAutoRefresh } from "@/lib/supabase";
import { colors } from "@/theme/tokens";

export default function RootLayout() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
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

  // Route based on auth state once we know it.
  useEffect(() => {
    if (!ready) return;
    const inAuthGroup = segments[0] === "(auth)";
    if (!session && !inAuthGroup) {
      router.replace("/(auth)/login");
    } else if (session && inAuthGroup) {
      router.replace("/(app)/(tabs)");
    }
  }, [ready, session, segments, router]);

  if (!ready) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: colors.midnight }}>
        <ActivityIndicator color={colors.ice} />
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
