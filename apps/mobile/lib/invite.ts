import * as SecureStore from "expo-secure-store";

/**
 * Pending invitation token.
 *
 * When someone opens an invite deep link (`fam://invite?token=...`) without a
 * session, we stash the token here so it survives the sign-in / sign-up flow
 * and can be accepted afterwards.
 *
 * Every operation is best-effort: a device whose Keystore throws must never
 * lose a sign-in over an optional convenience — reading a token that cannot be
 * decrypted just means "no pending invite", and the user can reopen the
 * invite link. Mirrors `invite_store.dart` in the Flutter client.
 */
const KEY = "fam.pending_invite";

export async function savePendingInvite(token: string): Promise<void> {
  try {
    await SecureStore.setItemAsync(KEY, token);
  } catch {
    // Best effort: an unstorable token costs the invite shortcut only.
  }
}

export async function takePendingInvite(): Promise<string | null> {
  try {
    const token = await SecureStore.getItemAsync(KEY);
    if (token) await SecureStore.deleteItemAsync(KEY);
    return token;
  } catch {
    // Broken secure store: treat as "no pending invite".
    return null;
  }
}

export async function peekPendingInvite(): Promise<string | null> {
  try {
    return await SecureStore.getItemAsync(KEY);
  } catch {
    return null;
  }
}
