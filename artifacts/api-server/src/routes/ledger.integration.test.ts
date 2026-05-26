import { describe, it, expect, beforeEach, afterEach, beforeAll, afterAll } from "vitest";
import { mkdtempSync, writeFileSync, rmSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import http from "node:http";
import type { AddressInfo } from "node:net";
import express from "express";
import { createLedgerRouter } from "./ledger.js";

let tmpDir: string;
let hitsPath: string;
let checkpointPath: string;
let server: http.Server;
let baseUrl: string;

function sha256(buf: Buffer | string): string {
  return createHash("sha256").update(buf).digest("hex");
}

function writeHits(content: string): { size: number; sha: string } {
  const buf = Buffer.from(content, "utf-8");
  writeFileSync(hitsPath, buf);
  return { size: buf.length, sha: sha256(buf) };
}

function writeCheckpoint(size: number, sha: string) {
  writeFileSync(checkpointPath, `${size} ${sha}\n`);
}

beforeAll(async () => {
  const app = express();
  // Route to a freshly-built router each request so the test can swap paths
  // by re-mounting if needed. Simpler: build once with fixed paths under tmpDir.
  tmpDir = mkdtempSync(path.join(tmpdir(), "ledger-test-"));
  hitsPath = path.join(tmpDir, "hits.txt");
  checkpointPath = path.join(tmpDir, "hits.txt.checkpoint");
  app.use("/api", createLedgerRouter({ hitsPath, checkpointPath }));
  server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const addr = server.address() as AddressInfo;
  baseUrl = `http://127.0.0.1:${addr.port}`;
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) =>
    server.close((err) => (err ? reject(err) : resolve())),
  );
  rmSync(tmpDir, { recursive: true, force: true });
});

beforeEach(() => {
  for (const p of [hitsPath, checkpointPath]) {
    try {
      unlinkSync(p);
    } catch {
      /* ignore */
    }
  }
});

afterEach(() => {
  for (const p of [hitsPath, checkpointPath]) {
    try {
      unlinkSync(p);
    } catch {
      /* ignore */
    }
  }
});

async function getStatus(): Promise<{ status: number; json: any }> {
  const res = await fetch(`${baseUrl}/api/ledger/integrity`);
  const json = (await res.json()) as any;
  return { status: res.status, json };
}

describe("GET /api/ledger/integrity", () => {
  it("returns status=ok with growthBytes when the prefix matches and the ledger has grown", async () => {
    const sealed = "line1\nline2\nline3\n";
    const { size, sha } = writeHits(sealed);
    writeCheckpoint(size, sha);
    // Append more bytes after checkpoint — legal append-only growth.
    writeFileSync(hitsPath, sealed + "appended-line\n");

    const r = await getStatus();
    expect(r.status).toBe(200);
    expect(r.json.status).toBe("ok");
    expect(r.json.failureMode).toBeNull();
    expect(r.json.checkpointSize).toBe(size);
    expect(r.json.checkpointSha).toBe(sha);
    expect(r.json.liveSize).toBe(size + "appended-line\n".length);
    expect(r.json.livePrefixSha).toBe(sha);
    expect(r.json.growthBytes).toBe("appended-line\n".length);
    expect(r.json.lastOkAt).toBe(r.json.checkedAt);
  });

  it("returns status=mismatch failureMode=hits_truncated when the live ledger is shorter than the checkpoint", async () => {
    const sealed = "line1\nline2\nline3\nline4\n";
    const { size, sha } = writeHits(sealed);
    writeCheckpoint(size, sha);
    // Truncate the live file below the checkpoint size.
    writeFileSync(hitsPath, "line1\n");

    const r = await getStatus();
    expect(r.status).toBe(200);
    expect(r.json.status).toBe("mismatch");
    expect(r.json.failureMode).toBe("hits_truncated");
    expect(r.json.reason).toMatch(/SHRUNK/);
    expect(r.json.checkpointSize).toBe(size);
    expect(r.json.liveSize).toBeLessThan(size);
  });

  it("returns status=mismatch failureMode=hits_rewritten_in_place when the prefix sha drifts", async () => {
    const sealed = "line1\nline2\nline3\n";
    const { size, sha } = writeHits(sealed);
    writeCheckpoint(size, sha);
    // Rewrite the first `size` bytes in place to something else of equal length.
    const tampered = "LINE1\nLINE2\nLINE3\n";
    expect(Buffer.byteLength(tampered)).toBe(size);
    writeFileSync(hitsPath, tampered);

    const r = await getStatus();
    expect(r.status).toBe(200);
    expect(r.json.status).toBe("mismatch");
    expect(r.json.failureMode).toBe("hits_rewritten_in_place");
    expect(r.json.checkpointSha).toBe(sha);
    expect(r.json.livePrefixSha).toBe(sha256(tampered));
    expect(r.json.livePrefixSha).not.toBe(sha);
    expect(r.json.reason).toMatch(/rewritten in place/);
  });

  it("returns status=missing failureMode=checkpoint_missing when the checkpoint file is absent", async () => {
    writeHits("line1\nline2\n");
    // No checkpoint written.
    const r = await getStatus();
    expect(r.status).toBe(200);
    expect(r.json.status).toBe("missing");
    expect(r.json.failureMode).toBe("checkpoint_missing");
    expect(r.json.reason).toMatch(/missing/);
    expect(r.json.liveSize).toBeGreaterThan(0);
  });

  it("returns status=mismatch failureMode=checkpoint_malformed when the checkpoint file is garbage", async () => {
    writeHits("line1\n");
    writeFileSync(checkpointPath, "not a valid checkpoint line\n");
    const r = await getStatus();
    expect(r.status).toBe(200);
    expect(r.json.status).toBe("mismatch");
    expect(r.json.failureMode).toBe("checkpoint_malformed");
    expect(r.json.reason).toMatch(/malformed|sha256/i);
  });

  it("returns status=missing failureMode=hits_missing when the ledger file is absent", async () => {
    writeCheckpoint(10, "0".repeat(64));
    const r = await getStatus();
    expect(r.status).toBe(200);
    expect(r.json.status).toBe("missing");
    expect(r.json.failureMode).toBe("hits_missing");
  });
});
