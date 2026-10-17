import { useQuery } from "@tanstack/react-query";
import { getSupabase } from "./supabase";

export interface ActiveOrg {
  orgId: string;
  role: string;
  name?: string;
}

/**
 * Resolves the signed-in user's active organization and role.
 *
 * A user may belong to several orgs; v1 picks the first active membership and
 * exposes `switchOrg` for later multi-org support.
 */
export function useOrg() {
  const query = useQuery<ActiveOrg | null>({
    queryKey: ["active-org"],
    staleTime: 60_000,
    queryFn: async () => {
      const supabase = getSupabase();
      const { data, error } = await supabase
        .from("organization_members")
        .select("org_id, role")
        .eq("status", "active")
        .limit(1);
      if (error) throw error;
      const row = data?.[0] as { org_id: string; role: string } | undefined;
      if (!row) return null;
      return { orgId: row.org_id, role: row.role };
    },
  });

  return {
    org: query.data ?? null,
    orgId: query.data?.orgId ?? null,
    role: query.data?.role ?? null,
    loading: query.isLoading,
    error: query.error as Error | null,
    refetch: query.refetch,
  };
}
