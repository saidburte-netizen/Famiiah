import { describe, it, expect } from "vitest";
import { compareVersions, versionStatus, isValidVersion } from "./version";

describe("version", () => {
  it("validates semver", () => {
    expect(isValidVersion("1.2.3")).toBe(true);
    expect(isValidVersion("1.2")).toBe(false);
    expect(isValidVersion("a.b.c")).toBe(false);
  });

  it("compares numerically not lexicographically", () => {
    expect(compareVersions("1.10.0", "1.9.0")).toBe(1);
    expect(compareVersions("1.9.0", "1.10.0")).toBe(-1);
    expect(compareVersions("2.0.0", "1.99.99")).toBe(1);
    expect(compareVersions("1.2.3", "1.2.3")).toBe(0);
  });

  it("forces update when below min supported", () => {
    expect(
      versionStatus({ current: "1.0.0", latest: "2.0.0", minSupported: "1.1.0", forceUpdate: false })
    ).toBe("force_update");
  });

  it("forces update when flagged and below latest", () => {
    expect(
      versionStatus({ current: "1.0.0", latest: "1.1.0", minSupported: "1.0.0", forceUpdate: true })
    ).toBe("force_update");
  });

  it("offers dismissible update when below latest but supported", () => {
    expect(
      versionStatus({ current: "1.0.0", latest: "1.1.0", minSupported: "1.0.0", forceUpdate: false })
    ).toBe("update_available");
  });

  it("is ok when up to date", () => {
    expect(
      versionStatus({ current: "1.1.0", latest: "1.1.0", minSupported: "1.0.0", forceUpdate: false })
    ).toBe("ok");
  });

  it("is ok on malformed input (fails open to avoid bricking)", () => {
    expect(
      versionStatus({ current: "bad", latest: "1.1.0", minSupported: "1.0.0", forceUpdate: true })
    ).toBe("ok");
  });
});
