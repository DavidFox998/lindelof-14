import { createHash } from "node:crypto";
import {
  existsSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import type { Logger } from "pino";

export const ALERTS_ACK_MAX_ENTRIES = 1000;

export function defaultAlertsAckPath(repoRoot: string): string {
  return path.join(repoRoot, "data", "ledger-alerts.ack.json");
}

export function computeAlertId(timestamp: string, message: string): string {
  return createHash("sha256")
    .update(timestamp + "\n" + message)
    .digest("hex");
}

type MinLogger = Pick<Logger, "warn" | "error">;

export function readAckMap(
  ackPath: string,
  log: MinLogger,
): Record<string, string> {
  if (!existsSync(ackPath)) return {};
  let raw: string;
  try {
    raw = readFileSync(ackPath, "utf8");
  } catch (err) {
    log.warn({ err, path: ackPath }, "Failed to read alert ack sidecar");
    return {};
  }
  const trimmed = raw.trim();
  if (!trimmed) return {};
  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch (err) {
    log.warn({ err, path: ackPath }, "Malformed alert ack sidecar; ignoring");
    return {};
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(parsed as Record<string, unknown>)) {
    if (typeof k === "string" && /^[0-9a-f]{64}$/.test(k) && typeof v === "string") {
      out[k] = v;
    }
  }
  return out;
}

export function writeAckMap(
  ackPath: string,
  map: Record<string, string>,
  log: MinLogger,
): void {
  let trimmed = map;
  const keys = Object.keys(map);
  if (keys.length > ALERTS_ACK_MAX_ENTRIES) {
    const sorted = keys
      .map((k) => [k, map[k]] as const)
      .sort((a, b) => (a[1] < b[1] ? 1 : a[1] > b[1] ? -1 : 0))
      .slice(0, ALERTS_ACK_MAX_ENTRIES);
    trimmed = Object.fromEntries(sorted);
  }
  const tmp = ackPath + ".tmp";
  try {
    writeFileSync(tmp, JSON.stringify(trimmed, null, 2) + "\n", { mode: 0o644 });
    renameSync(tmp, ackPath);
  } catch (err) {
    log.error({ err, path: ackPath }, "Failed to persist alert ack sidecar");
    throw err;
  }
}

/**
 * Returns true iff `alertId` is present in the on-disk ack sidecar at
 * `ackPath`. Reads the file fresh on every call — the file is small
 * (≤1000 entries, ≤~70 KB) and only consulted on monitor ticks
 * (default cadence 5 min), so the disk hit is negligible and we never
 * serve stale state when the operator dismissed an alert seconds ago.
 */
export function isAlertAcknowledged(
  ackPath: string,
  alertId: string,
  log: MinLogger,
): boolean {
  if (!alertId) return false;
  const map = readAckMap(ackPath, log);
  return Object.prototype.hasOwnProperty.call(map, alertId);
}
