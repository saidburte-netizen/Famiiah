import type { ReactNode } from "react";
import {
  ActivityIndicator,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text as RNText,
  TextInput,
  View,
  type TextInputProps,
  type TextStyle,
} from "react-native";
import { colors, font, radius, MIN_TOUCH } from "@/theme/tokens";

export function Screen({ children }: { children: ReactNode }) {
  return (
    <SafeAreaView style={styles.screen}>
      <View style={{ padding: 20, gap: 16 }}>{children}</View>
    </SafeAreaView>
  );
}

export function Text({
  children,
  variant = "regular",
  style,
  color = colors.text,
}: {
  children: ReactNode;
  variant?: "regular" | "medium" | "semibold" | "bold" | "extrabold" | "display" | "muted";
  style?: TextStyle;
  color?: string;
}) {
  const map: Record<string, TextStyle> = {
    regular: { fontFamily: font.regular },
    medium: { fontFamily: font.medium },
    semibold: { fontFamily: font.semibold },
    bold: { fontFamily: font.bold },
    extrabold: { fontFamily: font.extrabold },
    display: { fontFamily: font.display, fontSize: 32 },
    muted: { fontFamily: font.regular, color: colors.textMuted },
  };
  return (
    <RNText style={[{ color, fontSize: 15 }, map[variant], style]}>{children}</RNText>
  );
}

export function Card({ children }: { children: ReactNode }) {
  return <View style={styles.card}>{children}</View>;
}

export function Field({
  label,
  error,
  ...props
}: TextInputProps & { label: string; error?: string | null }) {
  return (
    <View style={{ gap: 6 }}>
      <Text variant="semibold" color={colors.textMuted}>
        {label}
      </Text>
      <TextInput
        style={[styles.input, error ? { borderColor: colors.danger } : null]}
        placeholderTextColor="#7A89AD"
        accessibilityLabel={label}
        {...props}
      />
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}
    </View>
  );
}

export function Button({
  title,
  onPress,
  loading,
  disabled,
  variant = "primary",
}: {
  title: string;
  onPress?: () => void;
  loading?: boolean;
  disabled?: boolean;
  variant?: "primary" | "ghost";
}) {
  const isPrimary = variant === "primary";
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: !!disabled || !!loading, busy: !!loading }}
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.button,
        isPrimary ? { backgroundColor: colors.royal } : { backgroundColor: "transparent", borderWidth: 1, borderColor: colors.border },
        (disabled || loading) && { opacity: 0.6 },
        pressed && { opacity: 0.85 },
      ]}
    >
      {loading ? (
        <ActivityIndicator color={isPrimary ? colors.white : colors.navy} />
      ) : (
        <Text variant="bold" color={isPrimary ? colors.white : colors.navy}>
          {title}
        </Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  card: {
    backgroundColor: colors.white,
    borderRadius: radius.card,
    borderWidth: 1,
    borderColor: colors.border,
    padding: 16,
  },
  input: {
    height: MIN_TOUCH,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.white,
    paddingHorizontal: 12,
    fontFamily: font.regular,
    fontSize: 15,
    color: colors.text,
  },
  button: {
    height: 54,
    borderRadius: radius.button,
    alignItems: "center",
    justifyContent: "center",
  },
});
