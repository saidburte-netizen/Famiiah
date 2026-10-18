import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";
import Constants from "expo-constants";
import type { Database } from "@fam/shared";
import { AppState } from "react-native";

/**
 * Secure storage adapter: auth tokens live in expo-secure-store (Keychain /
 * Keystore), never in AsyncStorage — except as a last resort. Some Android
 * ROMs ship a Keystore that *throws* on write; because supabase-js persists
 * the session inside `signUp()`/`signInWithPassword()`, a throw used to fail
 * sign-up with a generic error **after** the account was created
 * server-side. When (and only when) the secure store fails, the session
 * falls back to plain app-private AsyncStorage — where supabase-js keeps it
 * by default — and the fallback copy is dropped again on a healthy write or
 * sign-out. Mirrors `SecureLocalStorage` in the Flutter client
 * (ASSUMPTIONS A14).
 */
const readWithFallback = async (key: string): Promise<string | null> => {
  try {
    const value = await SecureStore.getItemAsync(key);
    if (value !== null) return value;
  } catch {
    // Broken Keystore — the plain copy below still counts.
  }
  try {
    return await AsyncStorage.getItem(key);
  } catch {
    return null;
  }
};

const writeWithFallback = async (key: string, value: string): Promise<void> => {
  try {
    await SecureStore.setItemAsync(key, value);
    await AsyncStorage.removeItem(key).catch(() => undefined);
    return;
  } catch {
    // Broken Keystore: the auth request already succeeded, so keep the user
    // signed in from a plain app-private copy instead of failing the flow.
  }
  await AsyncStorage.setItem(key, value);
};

const removeBoth = async (key: string): Promise<void> => {
  await SecureStore.deleteItemAsync(key).catch(() => undefined);
  await AsyncStorage.removeItem(key).catch(() => undefined);
};

const SecureStorageAdapter = {
  getItem: readWithFallback,
  setItem: writeWithFallback,
  removeItem: removeBoth,
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
