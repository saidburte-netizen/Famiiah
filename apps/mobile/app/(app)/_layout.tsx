import { useEffect } from "react";
import { Stack, useRouter } from "expo-router";
import * as Notifications from "expo-notifications";
import { colors } from "@/theme/tokens";
import { registerPushToken } from "@/lib/push";

// Show alerts for foreground notifications; the OS handles background ones.
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export default function AppLayout() {
  const router = useRouter();

  useEffect(() => {
    registerPushToken().catch(() => {
      /* permission denied or transient — retried on next launch */
    });
  }, []);

  useEffect(() => {
    const sub = Notifications.addNotificationResponseReceivedListener(() => {
      router.push("/(app)/notifications");
    });
    return () => sub.remove();
  }, [router]);

  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: colors.midnight },
        headerTintColor: colors.white,
        contentStyle: { backgroundColor: colors.background },
      }}
    />
  );
}
