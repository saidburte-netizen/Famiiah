import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useQueryClient } from "@tanstack/react-query";
import { RecordPaymentSchema } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { getSupabase } from "@/lib/supabase";
import { recordPayment } from "@/features/api";
import { userMessage } from "@/lib/errors";

const METHODS = ["cash", "bank_transfer", "telebirr", "chapa", "cheque", "other"] as const;

interface LeaseOption {
  id: string;
  label: string;
  monthly_rent: string;
}

export default function NewPaymentScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const params = useLocalSearchParams<{ leaseId?: string }>();
  const { orgId } = useOrg();

  const [options, setOptions] = useState<LeaseOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [leaseId, setLeaseId] = useState<string | null>(params.leaseId ?? null);

  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState<(typeof METHODS)[number]>("cash");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!orgId) return;
    let cancelled = false;
    const supabase = getSupabase();
    (async () => {
      const { data } = await supabase
        .from("leases")
        .select("id, monthly_rent, units(code), tenants(full_name)")
        .eq("org_id", orgId)
        .eq("status", "active")
        .limit(100);
      if (cancelled) return;
      const rows = (data ?? []) as unknown as Array<Record<string, unknown>>;
      setOptions(
        rows.map((r) => {
          const unit = r.units as { code?: string } | null;
          const tenant = r.tenants as { full_name?: string } | null;
          return {
            id: String(r.id),
            label: `${unit?.code ?? "Unit"} · ${tenant?.full_name ?? "Tenant"}`,
            monthly_rent: String(r.monthly_rent ?? "0"),
          };
        }),
      );
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [orgId]);

  // Default to the lease passed in the route, otherwise the first active lease.
  const selected = useMemo(
    () => options.find((o) => o.id === leaseId) ?? options[0] ?? null,
    [options, leaseId],
  );

  async function submit() {
    setError(null);
    if (!selected) {
      setError("Pick a lease.");
      return;
    }
    const parsed = RecordPaymentSchema.safeParse({
      leaseId: selected.id,
      amount,
      method,
      reference: reference || undefined,
      notes: notes || undefined,
      idempotencyKey: `pay-${selected.id}-${Date.now()}`,
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "invalid_input");
      return;
    }
    setBusy(true);
    try {
      await recordPayment(parsed.data);
      // A payment changes the payments list, the rent overview (paid/outstanding),
      // the dashboard totals and the tenant's charge list.
      await queryClient.invalidateQueries({ queryKey: ["payments"] });
      await queryClient.invalidateQueries({ queryKey: ["rent-overview"] });
      await queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      router.back();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "Record payment" }} />
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Lease
        </Text>
        {loading ? (
          <ActivityIndicator color={colors.royal} />
        ) : options.length === 0 ? (
          <Text variant="muted">No active leases. Create a tenant first.</Text>
        ) : (
          <View style={{ gap: 8, maxHeight: 240 }}>
            <FlatOptions options={options} leaseId={selected?.id ?? null} onPick={setLeaseId} />
          </View>
        )}
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Payment
        </Text>
        <Field
          label={selected ? `Amount (ETB) · rent ${selected.monthly_rent}` : "Amount (ETB)"}
          keyboardType="decimal-pad"
          value={amount}
          onChangeText={setAmount}
          placeholder="0.00"
        />
        <Text variant="semibold" color={colors.textMuted}>
          Method
        </Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
          {METHODS.map((m) => (
            <View key={m} style={{ flexGrow: 1, minWidth: 90 }}>
              <Button title={m.replace("_", " ")} variant={method === m ? "primary" : "ghost"} onPress={() => setMethod(m)} />
            </View>
          ))}
        </View>
        <Field label="Reference" value={reference} onChangeText={setReference} />
        <Field label="Notes" value={notes} onChangeText={setNotes} multiline />
      </Card>

      <Button title="Save payment" onPress={submit} loading={busy} />
    </Screen>
  );
}

function FlatOptions({
  options,
  leaseId,
  onPick,
}: {
  options: LeaseOption[];
  leaseId: string | null;
  onPick: (id: string) => void;
}) {
  return (
    <>
      {options.map((o) => (
        <Pressable key={o.id} onPress={() => onPick(o.id)}>
          <View
            style={{
              borderWidth: 1,
              borderColor: leaseId === o.id ? colors.royal : colors.border,
              borderRadius: 12,
              padding: 12,
              backgroundColor: leaseId === o.id ? colors.tint : colors.white,
            }}
          >
            <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
              <Text variant="semibold" color={colors.navy}>
                {o.label}
              </Text>
              <Text variant="muted">{o.monthly_rent} ETB</Text>
            </View>
          </View>
        </Pressable>
      ))}
    </>
  );
}
