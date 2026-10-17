import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, View } from "react-native";
import { getSupabase } from "@/lib/supabase";
import { Card, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";

interface MemberRow {
  user_id: string;
  full_name: string;
  role: string;
  status: string;
}

export default function AdminScreen() {
  const [rows, setRows] = useState<MemberRow[]>([]);
  const [orgId, setOrgId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = getSupabase();
    supabase
      .from("organization_members")
      .select("org_id")
      .eq("status", "active")
      .limit(1)
      .then(({ data }) => setOrgId(data?.[0]?.org_id ?? null));
  }, []);

  useEffect(() => {
    if (!orgId) return;
    let cancelled = false;
    const supabase = getSupabase();
    setLoading(true);
    (async () => {
      const { data, error: e } = await supabase.rpc("admin_list_members", {
        p_org: orgId,
        p_search: null,
        p_limit: 100,
        p_offset: 0,
      });
      if (cancelled) return;
      if (e) setError(e.message);
      else setRows((data ?? []) as unknown as MemberRow[]);
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [orgId]);

  if (loading) {
    return (
      <Screen>
        <ActivityIndicator color={colors.royal} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Admin
      </Text>
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : (
        <FlatList
          data={rows}
          keyExtractor={(r) => r.user_id}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          renderItem={({ item }) => (
            <Card>
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text variant="bold" color={colors.navy}>
                  {item.full_name || item.user_id.slice(0, 8)}
                </Text>
                <Text variant="semibold">{item.role}</Text>
              </View>
              <Text variant="muted">{item.status}</Text>
            </Card>
          )}
        />
      )}
      <Text variant="muted">Revenue, audit log and permissions are on the web console.</Text>
    </Screen>
  );
}
