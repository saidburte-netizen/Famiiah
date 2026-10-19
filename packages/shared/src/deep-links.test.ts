import { describe, expect, it } from "vitest";
import { isAuthCallbackUrl, parseRecoveryTokens } from "./deep-links";

/**
 * These lock in the password-reset contract: the recovery link GoTrue emails
 * carries its tokens in the URI *fragment*, and the invitation link must never
 * be mistaken for an auth callback.
 */
describe("isAuthCallbackUrl", () => {
  it("recognises a recovery link (tokens in the fragment)", () => {
    expect(
      isAuthCallbackUrl("fam://reset-password#access_token=a&refresh_token=b&type=recovery"),
    ).toBe(true);
  });

  it("recognises a PKCE callback link (code in the query)", () => {
    expect(isAuthCallbackUrl("fam://reset-password?code=abc")).toBe(true);
  });

  it("leaves the invitation link alone", () => {
    expect(isAuthCallbackUrl("fam://invite?token=abc123")).toBe(false);
  });

  it("leaves an ordinary in-app location alone", () => {
    expect(isAuthCallbackUrl("/app/home")).toBe(false);
  });
});

describe("parseRecoveryTokens", () => {
  it("reads the tokens from the fragment", () => {
    expect(
      parseRecoveryTokens(
        "fam://reset-password#access_token=at123&expires_in=3600&refresh_token=rt456&token_type=bearer&type=recovery",
      ),
    ).toEqual({ accessToken: "at123", refreshToken: "rt456", type: "recovery" });
  });

  it("falls back to the query string when there is no fragment", () => {
    expect(parseRecoveryTokens("fam://reset-password?access_token=at&refresh_token=rt")).toEqual({
      accessToken: "at",
      refreshToken: "rt",
    });
  });

  it("returns null for an expired/used link with no tokens", () => {
    expect(parseRecoveryTokens("fam://reset-password")).toBeNull();
    expect(parseRecoveryTokens("fam://reset-password#error=access_denied")).toBeNull();
  });

  it("returns null when only one of the two tokens is present", () => {
    expect(parseRecoveryTokens("fam://reset-password#access_token=at")).toBeNull();
  });

  it("does not mistake the invite token for recovery tokens", () => {
    expect(parseRecoveryTokens("fam://invite?token=abc123")).toBeNull();
  });
});
