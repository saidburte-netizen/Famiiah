import { useQuery } from "@tanstack/react-query";
import { getSupabase } from "./supabase";
import { queryKeys } from "./query";

export interface ActiveOrg {
  orgId: string;
  role: string;
  name?: string;
}

/**
 * Resolves the signed-in user's active organization and role.
 *
 * A user may belong to several orgs; v1 picks the first active membership.
 * Because it goes through React Query, every screen that calls `useOrg()`
 * shares one network request and a single refresh.
 */
export function useOrg() {
  const query = useQuery<ActiveOrg | null>({
    queryKey: queryKeys.activeOrg,
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
    error: (query.error as Error | null) ?? null,
    refetch: query.refetch,
  };
}
