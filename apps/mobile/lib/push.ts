import Constants from "expo-constants";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { getSupabase } from "./supabase";

/**
 * Ask for notification permission, get the Expo push token and store it via
 * `register_device_token` (upsert on the token). Safe to call on every launch:
 * skips silently when permission is denied or the platform has no push token
 * (e.g. web).
 */
export async function registerPushToken(): Promise<string | null> {
  if (Platform.OS === "web") return null;

  const existing = await Notifications.getPermissionsAsync();
  let granted = existing.granted;
  if (!granted && existing.canAskAgain) {
    granted = (await Notifications.requestPermissionsAsync()).granted;
  }
  if (!granted) return null;

  const extra = Constants.expoConfig?.extra as { eas?: { projectId?: string } } | undefined;
  const projectId = extra?.eas?.projectId;

  const { data } = await Notifications.getExpoPushTokenAsync(
    projectId ? { projectId } : undefined,
  );

  const platform = Platform.OS === "ios" ? "ios" : "android";
  const supabase = getSupabase();
  const { error } = await supabase.rpc("register_device_token", {
    p_token: data,
    p_platform: platform,
  });
  if (error) throw error;
  return data;
}
