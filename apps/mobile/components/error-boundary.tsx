import { useEffect } from "react";
import type { ErrorBoundaryProps } from "expo-router";
import { Pressable, ScrollView, StyleSheet, View } from "react-native";
import { Text } from "@/components/ui";
import { errorTag } from "@/lib/errors";
import { colors, radius } from "@/theme/tokens";

/**
 * Top-level render guard. Expo Router renders this whenever a screen throws
 * during render; `retry` re-renders the tree.
 */
export function ErrorBoundary({ error, retry }: ErrorBoundaryProps) {
  useEffect(() => {
    // Report a stable tag, never the raw error.
    console.warn(`[fam] render error: ${errorTag(error)}`);
  }, [error]);

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text variant="display" color={colors.ice}>
          Fam
        </Text>
        <Text variant="semibold" color={colors.white} style={{ fontSize: 18 }}>
          Something went wrong
        </Text>
        <Text style={{ color: colors.ice, textAlign: "center" }} variant="muted">
          {"We hit an unexpected problem. Try again \u2014 if it keeps happening, restart the app."}
        </Text>
        <Pressable onPress={() => void retry()} style={styles.button} accessibilityRole="button">
          <Text variant="bold" color={colors.white}>
            Try again
          </Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.midnight },
  content: { flexGrow: 1, alignItems: "center", justifyContent: "center", gap: 12, padding: 32 },
  button: {
    marginTop: 8,
    backgroundColor: colors.royal,
    paddingHorizontal: 24,
    paddingVertical: 14,
    borderRadius: radius.button ?? 16,
  },
});
