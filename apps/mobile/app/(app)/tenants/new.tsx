import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { CreateTenantWithLeaseSchema } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { createTenantWithLease, listVacantUnits, type VacantUnit } from "@/features/api";

export default function NewTenantScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ unitId?: string }>();
  const { orgId } = useOrg();

  const [units, setUnits] = useState<VacantUnit[]>([]);
  const [loadingUnits, setLoadingUnits] = useState(true);
  const [unitId, setUnitId] = useState<string | null>(params.unitId ?? null);

  const [fullName, setFullName] = useState("");
  const [businessName, setBusinessName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");

  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10));
  const [endDate, setEndDate] = useState("");
  const [monthlyRent, setMonthlyRent] = useState("");
  const [depositAmount, setDepositAmount] = useState("0");

  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!orgId) return;
    let cancelled = false;
    listVacantUnits(orgId)
      .then((u) => {
        if (!cancelled) setUnits(u);
      })
      .finally(() => {
        if (!cancelled) setLoadingUnits(false);
      });
    return () => {
      cancelled = true;
    };
  }, [orgId]);

  // Default to the unit passed in the route, otherwise the first vacant unit.
  const selectedUnit = useMemo(
    () => units.find((u) => u.id === unitId) ?? units[0] ?? null,
    [units, unitId],
  );

  async function submit() {
    setError(null);
    if (!orgId) {
      setError("No active organization.");
      return;
    }
    if (!selectedUnit) {
      setError("Pick a vacant unit.");
      return;
    }
    const parsed = CreateTenantWithLeaseSchema.safeParse({
      orgId,
      unitId: selectedUnit.id,
      startDate,
      endDate: endDate || null,
      monthlyRent: monthlyRent || selectedUnit.monthly_rent || "0",
      depositAmount: depositAmount || "0",
      billingDay: 1,
      graceDays: 5,
      tenant: {
        fullName,
        businessName: businessName || undefined,
        phone: phone || undefined,
        email: email || undefined,
      },
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "invalid_input");
      return;
    }
    setBusy(true);
    try {
      await createTenantWithLease(parsed.data);
      router.replace("/(app)/(tabs)/tenants");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not create tenant.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "New tenant" }} />
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Unit
        </Text>
        {loadingUnits ? (
          <ActivityIndicator color={colors.royal} />
        ) : units.length === 0 ? (
          <Text variant="muted">No vacant units. Add units to a property first.</Text>
        ) : (
          <View style={{ gap: 8 }}>
            {units.slice(0, 30).map((u) => (
              <Pressable key={u.id} onPress={() => setUnitId(u.id)}>
                <View
                  style={{
                    borderWidth: 1,
                    borderColor: selectedUnit?.id === u.id ? colors.royal : colors.border,
                    borderRadius: 12,
                    padding: 12,
                    backgroundColor: selectedUnit?.id === u.id ? colors.tint : colors.white,
                  }}
                >
                  <Text variant="semibold" color={colors.navy}>
                    {u.code} — {u.property_name ?? "Property"}
                  </Text>
                  <Text variant="muted">Rent {u.monthly_rent} ETB</Text>
                </View>
              </Pressable>
            ))}
          </View>
        )}
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Tenant
        </Text>
        <Field label="Full name" value={fullName} onChangeText={setFullName} />
        <Field label="Business name" value={businessName} onChangeText={setBusinessName} />
        <Field label="Phone" keyboardType="phone-pad" value={phone} onChangeText={setPhone} />
        <Field label="Email" autoCapitalize="none" keyboardType="email-address" value={email} onChangeText={setEmail} />
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Lease
        </Text>
        <Field label="Start date (YYYY-MM-DD)" value={startDate} onChangeText={setStartDate} />
        <Field label="End date (optional)" value={endDate} onChangeText={setEndDate} />
        <Field label="Monthly rent (ETB)" keyboardType="decimal-pad" value={monthlyRent} onChangeText={setMonthlyRent} />
        <Field label="Deposit (ETB)" keyboardType="decimal-pad" value={depositAmount} onChangeText={setDepositAmount} />
      </Card>

      <Button title="Create tenant & lease" onPress={submit} loading={busy} />
    </Screen>
  );
}
