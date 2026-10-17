import { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Alert, Modal, ScrollView, View } from "react-native";
import { Button, Card, Field, Screen, Text } from "@/components/ui";
import { colors } from "@/theme/tokens";
import { useOrg } from "@/lib/org";
import {
  adminSetMemberRole,
  adminSetMemberStatus,
  inviteMember,
  listMembers,
} from "@/features/api";
import { userMessage } from "@/lib/errors";

const ROLES = ["owner", "manager", "staff", "viewer"] as const;
const STATUSES = ["active", "suspended", "pending"] as const;

interface MemberRow {
  user_id: string;
  full_name: string | null;
  role: string;
  status: string;
}

export default function AdminScreen() {
  const { orgId, role } = useOrg();
  const [rows, setRows] = useState<MemberRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [inviting, setInviting] = useState(false);
  const [managing, setManaging] = useState<MemberRow | null>(null);

  const isOwner = role === "owner";

  const load = useCallback(async () => {
    if (!orgId) return;
    setError(null);
    try {
      setRows((await listMembers(orgId)) as MemberRow[]);
    } catch (e) {
      setError(userMessage(e));
    }
  }, [orgId]);

  useEffect(() => {
    if (!orgId) return;
    setLoading(true);
    load().finally(() => setLoading(false));
  }, [orgId, load]);

  return (
    <Screen>
      <Text variant="display" color={colors.midnight}>
        Admin
      </Text>
      {error ? (
        <Text variant="medium" color={colors.danger}>
          {error}
        </Text>
      ) : null}
      {isOwner ? <Button title="Invite teammate" onPress={() => setInviting(true)} /> : null}
      {loading ? (
        <ActivityIndicator color={colors.royal} />
      ) : (
        <ScrollView contentContainerStyle={{ gap: 12 }}>
          {rows.map((m) => (
            <Card key={m.user_id}>
              <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
                <Text variant="bold" color={colors.navy}>
                  {m.full_name || m.user_id.slice(0, 8)}
                </Text>
                <Text variant="semibold" color={colors.textMuted}>
                  {m.role}
                </Text>
              </View>
              <Text variant="muted">{m.status}</Text>
              {isOwner ? (
                <View style={{ marginTop: 8 }}>
                  <Button title="Manage" variant="ghost" onPress={() => setManaging(m)} />
                </View>
              ) : null}
            </Card>
          ))}
        </ScrollView>
      )}

      <InviteModal
        orgId={orgId}
        visible={inviting}
        onClose={() => setInviting(false)}
        onDone={() => setInviting(false)}
      />
      <ManageModal
        orgId={orgId}
        member={managing}
        onClose={() => setManaging(null)}
        onDone={async () => {
          setManaging(null);
          await load();
        }}
      />
    </Screen>
  );
}

function InviteModal({
  orgId,
  visible,
  onClose,
  onDone,
}: {
  orgId: string | null;
  visible: boolean;
  onClose: () => void;
  onDone: () => void;
}) {
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [inviteRole, setInviteRole] = useState("staff");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (visible) {
      setEmail("");
      setPhone("");
      setInviteRole("staff");
      setError(null);
    }
  }, [visible]);

  async function send() {
    if (!orgId) return;
    setError(null);
    if (!email.trim() && !phone.trim()) {
      setError("Enter an email or a phone number.");
      return;
    }
    setBusy(true);
    try {
      const res = await inviteMember({
        orgId,
        email: email.trim() || undefined,
        phone: phone.trim() || undefined,
        role: inviteRole,
      });
      const link = res?.link;
      Alert.alert(
        "Invitation created",
        link
          ? `Share this link with the invitee:\n\n${link}`
          : "The invitation was created and emailed.",
      );
      onDone();
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
          Invite teammate
        </Text>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Field
            label="Email"
            autoCapitalize="none"
            keyboardType="email-address"
            value={email}
            onChangeText={setEmail}
          />
          <Field label="Phone (optional)" value={phone} onChangeText={setPhone} />
          <Text variant="semibold" color={colors.textMuted}>
            Role
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
            {ROLES.map((r) => (
              <View key={r} style={{ minWidth: 96, flexGrow: 1 }}>
                <Button
                  title={r}
                  variant={inviteRole === r ? "primary" : "ghost"}
                  onPress={() => setInviteRole(r)}
                />
              </View>
            ))}
          </View>
          <Button title="Create invitation" onPress={send} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}

function ManageModal({
  orgId,
  member,
  onClose,
  onDone,
}: {
  orgId: string | null;
  member: MemberRow | null;
  onClose: () => void;
  onDone: () => void | Promise<void>;
}) {
  const [role, setRole] = useState("staff");
  const [status, setStatus] = useState("active");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setRole(member?.role ?? "staff");
    setStatus(member?.status ?? "active");
    setError(null);
  }, [member]);

  async function save() {
    if (!orgId || !member) return;
    setError(null);
    setBusy(true);
    try {
      if (role !== member.role) await adminSetMemberRole(orgId, member.user_id, role);
      if (status !== member.status) await adminSetMemberStatus(orgId, member.user_id, status);
      await onDone();
    } catch (err) {
      setError(userMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={!!member} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, padding: 20, gap: 16, backgroundColor: colors.background }}>
        <Text variant="display" color={colors.midnight}>
          {member?.full_name || "Member"}
        </Text>
        {error ? (
          <Text variant="medium" color={colors.danger}>
            {error}
          </Text>
        ) : null}
        <Card>
          <Text variant="semibold" color={colors.textMuted}>
            Role
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
            {ROLES.map((r) => (
              <View key={r} style={{ minWidth: 96, flexGrow: 1 }}>
                <Button
                  title={r}
                  variant={role === r ? "primary" : "ghost"}
                  onPress={() => setRole(r)}
                />
              </View>
            ))}
          </View>

          <Text variant="semibold" color={colors.textMuted}>
            Status
          </Text>
          <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
            {STATUSES.map((s) => (
              <View key={s} style={{ minWidth: 96, flexGrow: 1 }}>
                <Button
                  title={s}
                  variant={status === s ? "primary" : "ghost"}
                  onPress={() => setStatus(s)}
                />
              </View>
            ))}
          </View>

          <Button title="Save" onPress={save} loading={busy} />
          <Button title="Cancel" variant="ghost" onPress={onClose} />
        </Card>
      </View>
    </Modal>
  );
}
