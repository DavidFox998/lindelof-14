import { Router, type IRouter } from "express";
import { createHash } from "node:crypto";
import {
  existsSync,
  openSync,
  readSync,
  closeSync,
  statSync,
  readFileSync,
  writeFileSync,
  renameSync,
} from "node:fs";
import path from "node:path";

type FailureMode =
  | "hits_missing"
  | "checkpoint_missing"
  | "checkpoint_malformed"
  | "checkpoint_unreadable"
  | "hits_truncated"
  | "hits_rewritten_in_place";

interface LedgerIntegrityStatus {
  status: "ok" | "mismatch" | "missing";
  failureMode: FailureMode | null;
  reason: string | null;
  checkpointSize: number | null;
  checkpointSha: string | null;
  liveSize: number | null;
  livePrefixSha: string | null;
  growthBytes: number | null;
  checkedAt: string;
  ledgerLastModified: string | null;
  ledgerPath: string;
  checkpointPath: string;
  lastOkAt: string | null;
}

function resolveRepoRoot(): string {
  const candidates = [
    process.cwd(),
    path.resolve(process.cwd(), "..", ".."),
    path.resolve(process.cwd(), ".."),
  ];
  for (const c of candidates) {
    if (existsSync(path.join(c, "data", "hits.txt"))) return c;
    if (existsSync(path.join(c, "data", "hits.txt.checkpoint"))) return c;
  }
  return candidates[0];
}

function readPrefixSha(filePath: string, size: number): string {
  const fd = openSync(filePath, "r");
  try {
    const buf = Buffer.alloc(size);
    let off = 0;
    while (off < size) {
      const n = readSync(fd, buf, off, size - off, off);
      if (n === 0) break;
      off += n;
    }
    return createHash("sha256").update(buf.subarray(0, off)).digest("hex");
  } finally {
    closeSync(fd);
  }
}

export interface LedgerRouterOptions {
  hitsPath: string;
  checkpointPath: string;
  lastOkPath?: string;
}

function readPersistedLastOk(p: string): string | null {
  try {
    if (!existsSync(p)) return null;
    const raw = readFileSync(p, "utf-8");
    const parsed = JSON.parse(raw) as unknown;
    if (
      parsed &&
      typeof parsed === "object" &&
      "lastOkAt" in parsed &&
      typeof (parsed as { lastOkAt: unknown }).lastOkAt === "string"
    ) {
      const v = (parsed as { lastOkAt: string }).lastOkAt;
      if (!Number.isNaN(Date.parse(v))) return v;
    }
    return null;
  } catch {
    return null;
  }
}

function writePersistedLastOk(p: string, lastOkAt: string): void {
  try {
    const tmp = `${p}.tmp`;
    writeFileSync(tmp, JSON.stringify({ lastOkAt }) + "\n");
    renameSync(tmp, p);
  } catch {
    // Best-effort: never let a sidecar write failure break the endpoint.
  }
}

export function createLedgerRouter(opts: LedgerRouterOptions): IRouter {
  const HITS = opts.hitsPath;
  const CHECKPOINT = opts.checkpointPath;
  const LAST_OK_PATH = opts.lastOkPath ?? `${opts.hitsPath}.lastok`;
  let lastOkAt: string | null = readPersistedLastOk(LAST_OK_PATH);

  function buildStatus(): LedgerIntegrityStatus {
    const checkedAt = new Date().toISOString();
    const base: LedgerIntegrityStatus = {
      status: "ok",
      failureMode: null,
      reason: null,
      checkpointSize: null,
      checkpointSha: null,
      liveSize: null,
      livePrefixSha: null,
      growthBytes: null,
      checkedAt,
      ledgerLastModified: null,
      ledgerPath: HITS,
      checkpointPath: CHECKPOINT,
      lastOkAt,
    };

    if (!existsSync(HITS)) {
      return {
        ...base,
        status: "missing",
        failureMode: "hits_missing",
        reason: `${HITS} missing.`,
      };
    }

    let liveSize: number;
    let ledgerLastModified: string | null = null;
    try {
      const st = statSync(HITS);
      liveSize = st.size;
      ledgerLastModified = st.mtime.toISOString();
    } catch (e) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "hits_missing",
        reason: `Cannot stat ${HITS}: ${(e as Error).message}`,
      };
    }

    if (!existsSync(CHECKPOINT)) {
      return {
        ...base,
        status: "missing",
        failureMode: "checkpoint_missing",
        reason: `${CHECKPOINT} missing — cannot verify at-rest integrity. This file is committed; restore it from git.`,
        liveSize,
        ledgerLastModified,
      };
    }

    let raw: string;
    try {
      raw = readFileSync(CHECKPOINT, "utf-8").trim();
    } catch (e) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "checkpoint_unreadable",
        reason: `Cannot read ${CHECKPOINT}: ${(e as Error).message}`,
        liveSize,
        ledgerLastModified,
      };
    }

    const parts = raw.split(/\s+/);
    if (parts.length !== 2) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "checkpoint_malformed",
        reason: `${CHECKPOINT} malformed (expected '<size> <sha256>', got ${JSON.stringify(raw)}).`,
        liveSize,
        ledgerLastModified,
      };
    }

    const expectedSize = Number.parseInt(parts[0], 10);
    if (!Number.isFinite(expectedSize) || expectedSize < 0 || String(expectedSize) !== parts[0]) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "checkpoint_malformed",
        reason: `${CHECKPOINT} size field not a non-negative integer: ${JSON.stringify(parts[0])}.`,
        liveSize,
        ledgerLastModified,
      };
    }

    const expectedSha = parts[1].toLowerCase();
    if (!/^[0-9a-f]{64}$/.test(expectedSha)) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "checkpoint_malformed",
        reason: `${CHECKPOINT} sha256 field malformed: ${JSON.stringify(parts[1])}.`,
        checkpointSize: expectedSize,
        liveSize,
        ledgerLastModified,
      };
    }

    if (liveSize < expectedSize) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "hits_truncated",
        reason:
          `${HITS} SHRUNK — expected at least ${expectedSize} bytes, got ${liveSize}. ` +
          `TRUNCATION or in-place rewrite suspected. See docs/REPRODUCE.md for recovery.`,
        checkpointSize: expectedSize,
        checkpointSha: expectedSha,
        liveSize,
        ledgerLastModified,
      };
    }

    let prefixSha: string;
    try {
      prefixSha = readPrefixSha(HITS, expectedSize);
    } catch (e) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "checkpoint_unreadable",
        reason: `Cannot hash ${HITS} prefix: ${(e as Error).message}`,
        checkpointSize: expectedSize,
        checkpointSha: expectedSha,
        liveSize,
        ledgerLastModified,
      };
    }

    if (prefixSha !== expectedSha) {
      return {
        ...base,
        status: "mismatch",
        failureMode: "hits_rewritten_in_place",
        reason:
          `${HITS} first ${expectedSize} bytes have been rewritten in place. ` +
          `expected sha256: ${expectedSha} got sha256: ${prefixSha}. ` +
          `The ledger is append-only; in-place edits are not permitted.`,
        checkpointSize: expectedSize,
        checkpointSha: expectedSha,
        liveSize,
        livePrefixSha: prefixSha,
        ledgerLastModified,
      };
    }

    lastOkAt = checkedAt;
    writePersistedLastOk(LAST_OK_PATH, checkedAt);
    return {
      ...base,
      status: "ok",
      checkpointSize: expectedSize,
      checkpointSha: expectedSha,
      liveSize,
      livePrefixSha: prefixSha,
      growthBytes: liveSize - expectedSize,
      ledgerLastModified,
      lastOkAt,
    };
  }

  const router: IRouter = Router();
  router.get("/ledger/integrity", (_req, res) => {
    res.status(200).json(buildStatus());
  });
  return router;
}

const REPO_ROOT = resolveRepoRoot();
const defaultRouter = createLedgerRouter({
  hitsPath: path.join(REPO_ROOT, "data", "hits.txt"),
  checkpointPath: path.join(REPO_ROOT, "data", "hits.txt.checkpoint"),
});

export default defaultRouter;
