import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { normalizeError } from "@fam/shared";
import type { ReactNode } from "react";

/**
 * Centralized query keys. Keeping them in one place is what lets a mutation
 * invalidate exactly the right cache entries instead of refetching blindly.
 */
export const queryKeys = {
  activeOrg: ["active-org"] as const,
  dashboard: (orgId: string) => ["dashboard", orgId] as const,
  properties: (orgId: string) => ["properties", orgId] as const,
  property: (id: string) => ["property", id] as const,
  units: (propertyId: string) => ["units", propertyId] as const,
  tenants: (orgId: string, filter: string) => ["tenants", orgId, filter] as const,
  tenant: (id: string) => ["tenant", id] as const,
  rent: (orgId: string, month: string) => ["rent-overview", orgId, month] as const,
  payments: (orgId: string) => ["payments", orgId] as const,
  stock: (orgId: string) => ["stock", orgId] as const,
  lowStock: (orgId: string) => ["stock-low", orgId] as const,
  stockRentals: (orgId: string) => ["stock-rentals", orgId] as const,
  notifications: (orgId: string) => ["notifications", orgId] as const,
  members: (orgId: string) => ["members", orgId] as const,
  reports: (orgId: string) => ["reports", orgId] as const,
} as const;

/** Client errors (auth/permission/validation) are pointless to retry. */
const NON_RETRYABLE = new Set(["42501", "22023", "23505", "23514", "P0002"]);

/**
 * Query defaults from the brief: stale 30s, retry 2 (transient only).
 */
export function makeQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        gcTime: 5 * 60_000,
        refetchOnWindowFocus: false,
        retry: (failureCount, error) => {
          if (failureCount >= 2) return false;
          return !NON_RETRYABLE.has(normalizeError(error).code);
        },
      },
      mutations: { retry: 0 },
    },
  });
}

const client = makeQueryClient();

export function QueryProvider({ children }: { children: ReactNode }) {
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}

export { client as queryClient };
