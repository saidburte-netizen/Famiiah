import * as SecureStore from "expo-secure-store";

/**
 * Pending invitation token.
 *
 * When someone opens an invite deep link (`fam://invite?token=...`) without a
 * session, we stash the token here so it survives the sign-in / sign-up flow
 * and can be accepted afterwards.
 */
const KEY = "fam.pending_invite";

export async function savePendingInvite(token: string): Promise<void> {
  await SecureStore.setItemAsync(KEY, token);
}

export async function takePendingInvite(): Promise<string | null> {
  const token = await SecureStore.getItemAsync(KEY);
  if (token) await SecureStore.deleteItemAsync(KEY);
  return token;
}

export async function peekPendingInvite(): Promise<string | null> {
  return SecureStore.getItemAsync(KEY);
}
