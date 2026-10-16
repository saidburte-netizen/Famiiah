import { Stack } from "expo-router";
import { colors } from "@/theme/tokens";

export default function AppLayout() {
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
