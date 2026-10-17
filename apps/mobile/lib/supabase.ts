import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import * as SecureStore from "expo-secure-store";
import Constants from "expo-constants";
import type { Database } from "@fam/shared";
import { AppState } from "react-native";

/**
 * Secure storage adapter: auth tokens live in expo-secure-store (Keychain /
 * Keystore), never in AsyncStorage.
 */
const SecureStorageAdapter = {
  getItem: (key: string) => SecureStore.getItemAsync(key),
  setItem: (key: string, value: string) => SecureStore.setItemAsync(key, value),
  removeItem: (key: string) => SecureStore.deleteItemAsync(key),
};

let client: SupabaseClient<Database> | null = null;

/** False when the build is missing its public Supabase config. */
export function hasSupabaseEnv(): boolean {
  return Boolean(process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY);
}

export function getSupabase(): SupabaseClient<Database> {
  if (client) return client;
  const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
  const anon = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) throw new Error("missing_supabase_env");

  const appVersion = Constants.expoConfig?.version ?? "0.0.0";
  const appEnv = process.env.EXPO_PUBLIC_APP_ENV ?? "local";

  client = createClient<Database>(url, anon, {
    auth: {
      storage: SecureStorageAdapter,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
    global: {
      headers: {
        "x-client-version": appVersion,
        "x-app-env": appEnv,
      },
    },
  });
  return client;
}

/** Refresh tokens when the app returns to the foreground. */
export function startAutoRefresh(): () => void {
  const supabase = getSupabase();
  const sub = AppState.addEventListener("change", (state) => {
    if (state === "active") supabase.auth.startAutoRefresh();
    else supabase.auth.stopAutoRefresh();
  });
  return () => sub.remove();
}
