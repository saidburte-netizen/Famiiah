import { getSupabase } from "./supabase";
import { compareVersions } from "@fam/shared";

export type GateDecision =
  | { kind: "ok" }
  | { kind: "update_available"; storeUrl?: string; notes?: string }
  | { kind: "force_update"; storeUrl?: string; notes?: string };

/**
 * On launch, ask the backend whether this client is supported. Fails open on
 * network error so a flaky connection never bricks the app.
 */
export async function checkVersionGate(
  platform: "ios" | "android" | "web",
  currentVersion: string,
): Promise<GateDecision> {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase.rpc("check_app_version", {
      p_platform: platform,
      p_version: currentVersion,
    });
    if (error || !data) return { kind: "ok" };
    const d = data as {
      status: "ok" | "update_available" | "force_update";
      store_url?: string;
      notes?: string;
      latest?: string;
    };
    if (d.status === "force_update") {
      return { kind: "force_update", storeUrl: d.store_url, notes: d.notes };
    }
    if (d.status === "update_available") {
      return { kind: "update_available", storeUrl: d.store_url, notes: d.notes };
    }
    return { kind: "ok" };
  } catch {
    return { kind: "ok" };
  }
}

/** Client-side mirror of the server gate (used in tests and offline fallback). */
export function shouldForce(current: string, minSupported: string): boolean {
  return compareVersions(current, minSupported) < 0;
}
