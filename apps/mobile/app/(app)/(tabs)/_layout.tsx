import { useEffect, useState } from "react";
import { Tabs } from "expo-router";
import { getSupabase } from "@/lib/supabase";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";

/**
 * Bottom tabs: Home, Properties, Tenants, Rent, Admin.
 * The Admin tab is hidden unless the user's role allows it (owner/manager).
 */
export default function TabsLayout() {
  const [role, setRole] = useState<string | null>(null);
  const [showAdmin, setShowAdmin] = useState(false);

  useEffect(() => {
    const supabase = getSupabase();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      // resolve the user's role in their active org
      const { data: members } = await supabase
        .from("organization_members")
        .select("role")
        .eq("user_id", data.user.id)
        .eq("status", "active")
        .limit(1);
      const r = members?.[0]?.role ?? null;
      setRole(r);
      setShowAdmin(r === "owner" || r === "manager");
    });
  }, []);

  return (
    <Tabs
      screenOptions={{
        headerStyle: { backgroundColor: colors.midnight },
        headerTintColor: colors.white,
        tabBarActiveTintColor: colors.royal,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: { borderTopColor: colors.border },
      }}
    >
      <Tabs.Screen name="index" options={{ title: t("nav.home") }} />
      <Tabs.Screen name="properties" options={{ title: t("nav.properties") }} />
      <Tabs.Screen name="tenants" options={{ title: t("nav.tenants") }} />
      <Tabs.Screen name="rent" options={{ title: t("nav.rent") }} />
      <Tabs.Screen
        name="admin"
        options={{ title: t("nav.admin"), href: showAdmin ? "/(app)/(tabs)/admin" : null }}
      />
    </Tabs>
  );
}
