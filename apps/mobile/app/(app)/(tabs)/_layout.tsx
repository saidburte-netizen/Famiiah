import { Tabs } from "expo-router";
import { useOrg } from "@/lib/org";
import { colors } from "@/theme/tokens";
import { t } from "@/i18n";

/**
 * Bottom tabs: Home, Properties, Tenants, Rent, Admin.
 * The Admin tab is hidden unless the user's role allows it (owner/manager).
 */
export default function TabsLayout() {
  const { role } = useOrg();
  const showAdmin = role === "owner" || role === "manager";

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
