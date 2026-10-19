import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Modal, ScrollView, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useQueryClient } from "@tanstack/react-query";
import { formatMoney } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import {
  getTenant,
  listLeaseCharges,
  listTenantLeases,
  renewLease,
  terminateLease,
  type ChargeRow,
} from "@/features/api";
import { userMessage } from "@/lib/errors";

interface TenantDetail {
  id: string;
  full_name: string;
  business_name: string | null;
  phone: string | null;
  email: string | null;
  status: string;
}

interface TenantLease {
  id: string;
  start_date: string;
  end_date: string | null;
  monthly_rent: string;
  deposit_amount: string | null;
  status: string;
  ended_reason: string | null;
  unit_code: string | null;
}

export default function TenantDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [tenant, setTenant] = useState<TenantDetail | null>(null);
  const [leases, setLeases] = useState<TenantLease[]>([]);
  const [charges, setCharges] = useState<ChargeRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [leaseModal, setLeaseModal] = useState(false);

  const activeLease = leases.find((l) => l.status === "active") ?? null;

  const load = useCallback(async () => {
    if (!id) return;
    const [t, ls] = await Promise.all([getTenant(id), listTenantLeases(id)]);
    setTenant(t as TenantDetail);
    setLeases(ls as TenantLease[]);
    const active = (ls as TenantLease[]).find((l) => l.status === "active");
    setCharges(active ? await listLeaseCharges(active.id) : []);
  }, [id]);

  useEffect(() => {
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [load]);

  if (loading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: tenant?.full_name ?? "Tenant" }} />
      <ScrollView contentContainerStyle={{ gap: 16 }}>
        <Card>
          <Text variant="bold" color={colors.navy}>
            {tenant?.full_name ?? "—"}
          </Text>
          {tenant?.business_name ? <Text variant="muted">{tenant.business_name}</Text> : null}
          <Text variant="muted">{tenant?.phone ?? "no phone"}</Text>
          <Text variant="muted">{tenant?.email ?? "no email"}</Text>
        </Card>

        {activeLease ? (
          <Card>
            <Text variant="semibold" color={colors.navy}>
              Active lease · {activeLease.unit_code ?? "unit"}
            </Text>
            <Text variant="muted">
              {activeLease.start_date} → {activeLease.end_date ?? "open"} ·{" "}
              {formatMoney(activeLease.monthly_rent)}/mo
            </Text>
            {activeLease.deposit_amount ? (
              <Text variant="muted">Deposit {formatMoney(activeLease.deposit_amount)}</Text>
            ) : null}
            <View style={{ flexDirection: "row", gap: 8 }}>
              <View style={{ flex: 1 }}>
                <Button
                  title="Record payment"
                  onPress={() => router.push(`/(app)/payments/new?leaseId=${activeLease.id}`)}
                />
              </View>
              <View style={{ flex: 1 }}>
                <Button title="Manage" variant="ghost" onPress={() => setLeaseModal(true)} />
              </View>
            </View>
          </Card>
        ) : (
          <Card>
            <Text variant="muted">No active lease.</Text>
          </Card>
        )}

        <Card>
          <Text variant="semibold" color={colors.navy}>
            Charges
          </Text>
          {charges.length === 0 ? (
            <Text variant="muted">No charges yet.</Text>
          ) : (
            charges.map((c) => (
              <View key={c.id} style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text variant="muted">{c.due_date}</Text>
                <Text variant="muted">{formatMoney(c.amount)}</Text>
                <Text
                  variant="semibold"
                  color={c.status === "overdue" ? colors.danger : colors.textMuted}
                >
                  {c.status}
                </Text>
              </View>
            ))
          )}
        </Card>

        <Card>
          <Text variant="semibold" color={colors.navy}>
            Lease history
          </Text>
          {leases.length === 0 ? (
            <Text variant="muted">None.</Text>
          ) : (
            leases.map((l) => (
              <Text key={l.id} variant="muted">
                {l.start_date} → {l.end_date ?? "open"} · {l.status}
                {l.ended_reason ? ` (${l.ended_reason})` : ""}
              </Text>
            ))
          )}
        </Card>
      </ScrollView>

      <LeaseModal
        visible={leaseModal}
        lease={activeLease}
        onClose={() => setLeaseModal(false)}
        onDone={async () => {
          setLeaseModal(false);
          await load();
          // Renewing/terminating changes the tenant list, the rent overview and
          // the dashboard's overdue/occupancy numbers. Prefix keys invalidate
          // every cached variant (each tab passes its own org/filter/month).
          await queryClient.invalidateQueries({ queryKey: ["tenants"] });
          await queryClient.invalidateQueries({ queryKey: ["dashboard"] });
          await queryClient.invalidateQueries({ queryKey: ["rent-overview"] });
        }}
      />
    </Screen>
  );
}

function LeaseModal({
  visible,
  lease,
  onClose,
  onDone,
}: {
  visible: boolean;
  lease: TenantLease | null;
  onClose: () => void;
  onDone: () => void | Promise<void>;
}) {
  const [mode, setMode] = useState<"renew" | "terminate">("renew");
  const [date, setDate] = useState("");
  const [rent, setRent] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!visible) return;
    setMode("renew");
    setDate(lease?.end_date ?? new Date().toISOString().slice(0, 10));
    setRent(lease?.monthly_rent ?? "");
    setReason("");
    setError(null);
  }, [visible, lease]);

  async function save() {
    if (!lease) return;
    setError(null);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      setError("Enter a date as YYYY-MM-DD.");
      return;
    }
    setBusy(true);
    try {
      if (mode === "renew") {
        await renewLease(lease.id, date, rent || undefined);
      } else {
        await terminateLease(lease.id, date, reason || undefined);
      }
      await onDone();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, padding: 20, gap: 16, backgroundColor: colors.background }}>
        <Text variant="display" color={colors.midnight}>
          Manage lease
        </Text>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <View style={{ flexDirection: "row", gap: 8 }}>
            <View style={{ flex: 1 }}>
              <Button
                title="Renew"
                variant={mode === "renew" ? "primary" : "ghost"}
                onPress={() => setMode("renew")}
              />
            </View>
            <View style={{ flex: 1 }}>
              <Button
                title="Terminate"
                variant={mode === "terminate" ? "primary" : "ghost"}
                onPress={() => setMode("terminate")}
              />
            </View>
          </View>
          <Field
            label={mode === "renew" ? "New end date (YYYY-MM-DD)" : "Termination date (YYYY-MM-DD)"}
            value={date}
            onChangeText={setDate}
          />
          {mode === "renew" ? (
            <Field label="Monthly rent (ETB)" keyboardType="decimal-pad" value={rent} onChangeText={setRent} />
          ) : (
            <Field label="Reason" value={reason} onChangeText={setReason} />
          )}
          <Button title={mode === "renew" ? "Renew lease" : "Terminate lease"} onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}
