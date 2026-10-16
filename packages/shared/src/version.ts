/**
 * Semantic-version comparison used by the app version gate.
 * Versions are `MAJOR.MINOR.PATCH` strings. Compared as int arrays so
 * '1.10.0' > '1.9.0' (string compare would be wrong).
 */

export interface ParsedVersion {
  major: number;
  minor: number;
  patch: number;
}

const SEMVER_RE = /^(\d+)\.(\d+)\.(\d+)$/;

export function parseVersion(v: string): ParsedVersion | null {
  const m = SEMVER_RE.exec(v.trim());
  if (!m) return null;
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

export function isValidVersion(v: string): boolean {
  return parseVersion(v) !== null;
}

/** Compare two semver strings. Returns -1, 0, or 1. Invalid inputs compare as equal (0). */
export function compareVersions(a: string, b: string): -1 | 0 | 1 {
  const pa = parseVersion(a);
  const pb = parseVersion(b);
  if (!pa || !pb) return 0;
  if (pa.major !== pb.major) return pa.major < pb.major ? -1 : 1;
  if (pa.minor !== pb.minor) return pa.minor < pb.minor ? -1 : 1;
  if (pa.patch !== pb.patch) return pa.patch < pb.patch ? -1 : 1;
  return 0;
}

export type VersionStatus = "ok" | "update_available" | "force_update";

export interface VersionGateInput {
  current: string;
  latest: string;
  minSupported: string;
  forceUpdate: boolean;
}

/**
 * Decide the gate status for a running client.
 * - force_update when current < minSupported, OR (forceUpdate && current < latest)
 * - update_available when current < latest
 * - ok otherwise
 */
export function versionStatus({ current, latest, minSupported, forceUpdate }: VersionGateInput): VersionStatus {
  const c = parseVersion(current);
  const l = parseVersion(latest);
  const mn = parseVersion(minSupported);
  if (!c || !l || !mn) return "ok";

  const belowMin = compareVersions(current, minSupported) < 0;
  if (belowMin) return "force_update";

  if (forceUpdate && compareVersions(current, latest) < 0) return "force_update";

  if (compareVersions(current, latest) < 0) return "update_available";

  return "ok";
}
