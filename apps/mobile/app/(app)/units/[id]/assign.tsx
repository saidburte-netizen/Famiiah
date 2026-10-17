import { useMemo, useState } from "react";
import { ActivityIndicator, Pressable, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { AssignTenantToUnitSchema } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { assignTenantToUnit, listTenantsWithStatus } from "@/features/api";
import { queryKeys } from "@/lib/query";
import { userMessage } from "@/lib/errors";

export default function AssignTenantScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{
    id: string;
    propertyId?: string;
    code?: string;
    rent?: string;
  }>();
  const { orgId } = useOrg();

  const [tenantId, setTenantId] = useState<string | null>(null);
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10));
  const [endDate, setEndDate] = useState("");
  const [monthlyRent, setMonthlyRent] = useState(params.rent ?? "");
  const [depositAmount, setDepositAmount] = useState("0");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const tenants = useQuery({
    queryKey: queryKeys.tenants(orgId ?? "none", "assignable"),
    queryFn: () => listTenantsWithStatus(orgId as string, "all"),
    enabled: Boolean(orgId),
  });

  // Tenants holding an active lease already have a unit_code; the RPC does not
  // guard against that, so filter them out here.
  const assignable = useMemo(
    () => (tenants.data ?? []).filter((t) => !t.unit_code),
    [tenants.data],
  );

  async function submit() {
    setError(null);
    const parsed = AssignTenantToUnitSchema.safeParse({
      unitId: params.id,
      tenantId,
      startDate,
      endDate: endDate || null,
      monthlyRent: monthlyRent || params.rent || "0",
      depositAmount: depositAmount || "0",
      billingDay: 1,
      graceDays: 5,
    });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "invalid_input");
      return;
    }
    setBusy(true);
    try {
      await assignTenantToUnit(parsed.data);
      if (params.propertyId) {
        // Replacing remounts the property screen so its units refetch.
        router.replace(`/(app)/properties/${params.propertyId}`);
      } else {
        router.replace("/(app)/(tabs)/tenants");
      }
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "Assign tenant" }} />
      <Card>
        <Text variant="bold" color={colors.navy}>
          Unit {params.code ?? params.id}
        </Text>
        <Text variant="muted">The unit becomes rented once the lease is created.</Text>
      </Card>

      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Tenant
        </Text>
        {tenants.isLoading ? (
          <ActivityIndicator color={colors.royal} />
        ) : assignable.length === 0 ? (
          <Text variant="muted">
            Every tenant already has an active lease. Create a new tenant instead.
          </Text>
        ) : (
          <View style={{ gap: 8 }}>
            {assignable.slice(0, 50).map((t) => (
              <Pressable key={t.id} onPress={() => setTenantId(t.id)}>
                <View
                  style={{
                    borderWidth: 1,
                    borderColor: tenantId === t.id ? colors.royal : colors.border,
                    borderRadius: 12,
                    padding: 12,
                    backgroundColor: tenantId === t.id ? colors.tint : colors.white,
                  }}
                >
                  <Text variant="semibold" color={colors.navy}>
                    {t.full_name}
                  </Text>
                  {t.phone ? <Text variant="muted">{t.phone}</Text> : null}
                </View>
              </Pressable>
            ))}
          </View>
        )}
      </Card>

      <Card>
        <Text variant="semibold" color={colors.navy}>
          Lease
        </Text>
        <Field label="Start date (YYYY-MM-DD)" value={startDate} onChangeText={setStartDate} />
        <Field label="End date (optional)" value={endDate} onChangeText={setEndDate} />
        <Field
          label="Monthly rent (ETB)"
          keyboardType="decimal-pad"
          value={monthlyRent}
          onChangeText={setMonthlyRent}
        />
        <Field
          label="Deposit (ETB)"
          keyboardType="decimal-pad"
          value={depositAmount}
          onChangeText={setDepositAmount}
        />
      </Card>

      <Button title="Assign tenant" onPress={submit} loading={busy} disabled={!tenantId} />
    </Screen>
  );
}
