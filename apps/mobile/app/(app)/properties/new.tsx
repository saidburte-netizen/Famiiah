import { useState } from "react";
import { View } from "react-native";
import { Stack, useRouter } from "expo-router";
import { CreatePropertySchema, type CreatePropertyInput } from "@fam/shared";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import { createProperty } from "@/features/api";
import { userMessage } from "@/lib/errors";

const TYPES = ["residential", "commercial", "mixed_use"] as const;

export default function NewPropertyScreen() {
  const router = useRouter();
  const { orgId } = useOrg();
  const [name, setName] = useState("");
  const [type, setType] = useState<(typeof TYPES)[number]>("residential");
  const [addressLine, setAddressLine] = useState("");
  const [subCity, setSubCity] = useState("");
  const [city, setCity] = useState("");
  const [floors, setFloors] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    setError(null);
    if (!orgId) {
      setError("No active organization.");
      return;
    }
    const candidate: CreatePropertyInput = {
      name,
      type,
      addressLine: addressLine || undefined,
      subCity: subCity || undefined,
      city: city || undefined,
      floors: floors ? Number(floors) : undefined,
      notes: notes || undefined,
    };
    const parsed = CreatePropertySchema.safeParse(candidate);
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? "invalid_input");
      return;
    }
    setBusy(true);
    try {
      await createProperty(orgId, parsed.data);
      router.back();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: "New property" }} />
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}

      <Card>
        <Field label="Name" value={name} onChangeText={setName} />
        <Text variant="semibold" color={colors.textMuted}>
          Type
        </Text>
        <View style={{ flexDirection: "row", gap: 8 }}>
          {TYPES.map((t) => (
            <View key={t} style={{ flex: 1 }}>
              <Button title={t.replace("_", " ")} variant={type === t ? "primary" : "ghost"} onPress={() => setType(t)} />
            </View>
          ))}
        </View>
        <Field label="Address line" value={addressLine} onChangeText={setAddressLine} />
        <Field label="Sub-city" value={subCity} onChangeText={setSubCity} />
        <Field label="City" value={city} onChangeText={setCity} />
        <Field label="Floors" keyboardType="number-pad" value={floors} onChangeText={setFloors} />
        <Field label="Notes" value={notes} onChangeText={setNotes} multiline />
        <Button title="Create property" onPress={submit} loading={busy} />
      </Card>
    </Screen>
  );
}
