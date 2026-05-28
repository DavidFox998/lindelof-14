import { test, expect, type Route, type Request } from "@playwright/test";
import {
  mkdtempSync,
  writeFileSync,
  rmSync,
  unlinkSync,
  existsSync,
  readFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import http from "node:http";
import type { AddressInfo } from "node:net";
import express from "express";
import { createLedgerChecker } from "../../../api-server/src/routes/ledger.js";

/**
 * Task #167: end-to-end coverage for the "Recent dismissals" panel
 * (`panel-ledger-sidecar-forged-history`) added in task #150.
 *
 * The panel renders under the red forged-sidecar banner and reads
 * from `GET /api/lean/ledger/sidecar-forged-ack/history` — a rotating
 * JSONL log that survives the single-incident sidecar being replaced
 * by a later forged read. The server-side append + read path is
 * covered by `routes/ledger.integration.test.ts`, but the wiring
 * between the orval-generated `useGetSidecarForgedAckHistory` hook
 * and the dashboard panel (row ordering, `data-payload-sha` /
 * `data-acked-by` attributes, count text, and the empty-state hide)
 * had no Playwright coverage.
 *
 * This spec exercises a realistic repeat-tamper attack flow:
 *
 *   1. Forge a sidecar (payload-v1), ack it as referee "alice"
 *      (named-token path so the history row carries an attribution).
 *   2. Restart the fixture and forge with DIFFERENT bytes
 *      (payload-v2). The prior ack file is bound to the previous
 *      payload sha and gets discarded, so the banner re-fires
 *      un-acked, exactly as task #138 modelled.
 *   3. Ack the new incident as referee "bob".
 *   4. Assert the panel lists both rows newest-first: row 0 = bob /
 *      sha_v2, row 1 = alice / sha_v1, plus the "2 of last 20"
 *      count text.
 *
 * A second test covers the empty state: a forged sidecar at boot
 * with no history file on disk → the red banner is visible but the
 * dismissals panel is NOT rendered.
 *
 * Fixture strategy mirrors `ledger-sidecar-forged-ack.spec.ts` and
 * `ledger-sidecar-forged-ack-named-referee.spec.ts`: boot an
 * in-process express server backed by a real `createLedgerChecker`
 * over a tmp dir, forward the dashboard's `/api/ledger/integrity`,
 * `/api/ledger/sidecar-forged-ack`, and the history endpoint to it.
 * The named-token map turns the bearer token into a referee name and
 * passes it to `checker.acknowledgeForgedSidecar(name)` — same shape
 * as the production `LEAN_REBUILD_TOKENS=alice:...,bob:...` parser.
 */

const LEDGER_INTEGRITY_URL = "**/api/ledger/integrity*";
const LEDGER_ACK_URL = "**/api/ledger/sidecar-forged-ack";
const LEDGER_ACK_HISTORY_URL = "**/api/ledger/sidecar-forged-ack/history*";
const REBUILD_TOKEN_STORAGE_KEY = "lean-rebuild-token";

const ALICE_TOKEN = "alice-named-token-fixture";
const BOB_TOKEN = "bob-named-token-fixture";
const ALICE_NAME = "alice";
const BOB_NAME = "bob";

function sha256(buf: Buffer | string): string {
  return createHash("sha256").update(buf).digest("hex");
}

type FixtureServer = {
  baseUrl: string;
  close: () => Promise<void>;
};

async function bootFixture(paths: {
  hitsPath: string;
  checkpointPath: string;
  lastOkPath: string;
  secretPath: string;
}): Promise<FixtureServer> {
  const checker = createLedgerChecker({
    hitsPath: paths.hitsPath,
    checkpointPath: paths.checkpointPath,
    lastOkPath: paths.lastOkPath,
    secretPath: paths.secretPath,
  });

  // In-fixture named-token → referee-name map. A bearer token that
  // matches a named entry resolves to that name and is authoritative
  // — mirrors the production `LEAN_REBUILD_TOKENS` parser. The
  // dashboard's ack mutation only sends Authorization, never
  // X-Referee-Name, so this map is the realistic mechanism for the
  // history row to carry an `ackedBy`.
  const namedTokens = new Map<string, string>([
    [ALICE_TOKEN, ALICE_NAME],
    [BOB_TOKEN, BOB_NAME],
  ]);

  const app = express();
  app.use(express.json());
  app.use("/api", checker.router);
  app.post("/api/ledger/sidecar-forged-ack", (req, res) => {
    const auth = req.headers["authorization"] ?? "";
    const match = /^Bearer\s+(.+)$/i.exec(
      Array.isArray(auth) ? (auth[0] ?? "") : auth,
    );
    const provided = match ? match[1]?.trim() : "";
    if (!provided) {
      res
        .status(401)
        .json({ ok: false, error: "Unauthorized: bad referee token." });
      return;
    }
    const refereeName = namedTokens.get(provided) ?? null;
    if (refereeName === null) {
      res
        .status(401)
        .json({ ok: false, error: "Unauthorized: bad referee token." });
      return;
    }
    const result = checker.acknowledgeForgedSidecar(refereeName);
    if (!result.ok) {
      res.status(409).json({
        ok: false,
        error: "No forged-sidecar incident to acknowledge.",
      });
      return;
    }
    res.json({
      ok: true,
      acknowledgedAt: result.acknowledgedAt,
      alreadyAcknowledged: result.alreadyAcknowledged,
      payloadSha: result.payloadSha,
      ackedBy: result.ackedBy,
    });
  });
  // Task #150's GET history endpoint is registered in production by
  // `routes/lean.ts` (mounted on /api), not by `checker.router`.
  // Re-implement it here against the same on-disk rotating log
  // (`${lastOkPath}.forged-ack.log.jsonl`) the ack handler appends
  // to via `checker.acknowledgeForgedSidecar`. Newest-first, capped
  // at 20 entries — same contract the dashboard panel renders.
  const historyPath = `${paths.lastOkPath}.forged-ack.log.jsonl`;
  app.get("/api/ledger/sidecar-forged-ack/history", (req, res) => {
    const rawLimit = req.query["limit"];
    let limit = 20;
    if (typeof rawLimit === "string" && rawLimit.trim() !== "") {
      const parsed = Number(rawLimit);
      if (Number.isFinite(parsed) && parsed > 0) {
        limit = Math.floor(parsed);
      }
    }
    let entries: Array<{
      payloadSha: string;
      acknowledgedAt: string;
      ackedBy: string | null;
    }> = [];
    if (existsSync(historyPath)) {
      const raw = readFileSync(historyPath, "utf-8");
      const lines = raw.split("\n").filter((l) => l.length > 0);
      for (let i = lines.length - 1; i >= 0 && entries.length < limit; i--) {
        try {
          const parsed = JSON.parse(lines[i] as string) as Record<
            string,
            unknown
          >;
          const payloadSha = parsed["payloadSha"];
          const acknowledgedAt = parsed["acknowledgedAt"];
          if (
            typeof payloadSha !== "string" ||
            !/^[0-9a-f]{64}$/i.test(payloadSha) ||
            typeof acknowledgedAt !== "string"
          ) {
            continue;
          }
          const ackedByRaw = parsed["ackedBy"];
          entries.push({
            payloadSha: payloadSha.toLowerCase(),
            acknowledgedAt,
            ackedBy:
              typeof ackedByRaw === "string" && ackedByRaw.length > 0
                ? ackedByRaw
                : null,
          });
        } catch {
          continue;
        }
      }
    }
    res.json({ entries, capacity: 20 });
  });
  const srv = http.createServer(app);
  await new Promise<void>((resolve) => srv.listen(0, "127.0.0.1", resolve));
  const port = (srv.address() as AddressInfo).port;

  return {
    baseUrl: `http://127.0.0.1:${port}`,
    close: async () => {
      await new Promise<void>((resolve, reject) =>
        srv.close((err) => (err ? reject(err) : resolve())),
      );
    },
  };
}

async function installForwarders(
  page: import("@playwright/test").Page,
  getActive: () => FixtureServer,
): Promise<void> {
  const forward = async (route: Route, request: Request, suffix: string) => {
    const upstream = new URL(request.url());
    const forwarded = `${getActive().baseUrl}${suffix}${upstream.search}`;
    const postData = request.postData();
    const res = await fetch(forwarded, {
      method: request.method(),
      headers: request.headers(),
      body: postData ?? undefined,
    });
    const body = Buffer.from(await res.arrayBuffer());
    const headers: Record<string, string> = {};
    res.headers.forEach((v, k) => {
      const lk = k.toLowerCase();
      if (
        lk === "content-encoding" ||
        lk === "content-length" ||
        lk === "transfer-encoding"
      ) {
        return;
      }
      headers[k] = v;
    });
    await route.fulfill({ status: res.status, headers, body });
  };
  await page.route(LEDGER_INTEGRITY_URL, (route, request) =>
    forward(route, request, "/api/ledger/integrity"),
  );
  await page.route(LEDGER_ACK_URL, (route, request) =>
    forward(route, request, "/api/ledger/sidecar-forged-ack"),
  );
  // The dashboard's `useGetSidecarForgedAckHistory` hook hits
  // /api/ledger/sidecar-forged-ack/history; forward it to the
  // fixture router (mounted at /api) so it sees the same on-disk
  // history file the ack POST appends to.
  await page.route(LEDGER_ACK_HISTORY_URL, (route, request) =>
    forward(route, request, "/api/ledger/sidecar-forged-ack/history"),
  );
}

function forgedSidecarBytes(marker: string): Buffer {
  return Buffer.from(
    JSON.stringify({
      lastOkAt: "2099-01-01T00:00:00.000Z",
      lastCheckedAt: "2099-01-01T00:00:00.000Z",
      marker,
    }) + "\n",
  );
}

function writeForgedSidecar(lastOkPath: string, marker: string): void {
  writeFileSync(lastOkPath, forgedSidecarBytes(marker));
}

function payloadShaFor(marker: string): string {
  return sha256(forgedSidecarBytes(marker));
}

function seedTmpLedger(tmpDir: string): {
  hitsPath: string;
  checkpointPath: string;
  lastOkPath: string;
  secretPath: string;
} {
  const hitsPath = path.join(tmpDir, "hits.txt");
  const checkpointPath = path.join(tmpDir, "hits.txt.checkpoint");
  const lastOkPath = path.join(tmpDir, "hits.txt.lastok");
  const secretPath = path.join(tmpDir, "hits.txt.lastok.key");

  const sealed = "line1\nline2\nline3\n";
  const buf = Buffer.from(sealed, "utf-8");
  writeFileSync(hitsPath, buf);
  writeFileSync(checkpointPath, `${buf.length} ${sha256(buf)}\n`);
  // Pre-seed the HMAC secret so the router does NOT auto-generate
  // one — the forged sidecar must be evaluated against a known
  // secret it carries no valid mac for.
  writeFileSync(secretPath, "ab".repeat(32) + "\n");
  return { hitsPath, checkpointPath, lastOkPath, secretPath };
}

test.describe(
  "dashboard: Recent dismissals panel under the forged-sidecar banner (task #167)",
  () => {
    test("two distinct forged payloads + acks render newest-first with referee + payloadSha attribution", async ({
      page,
    }) => {
      const tmpDir = mkdtempSync(
        path.join(tmpdir(), "ledger-forged-history-e2e-"),
      );
      const seeded = seedTmpLedger(tmpDir);
      const { hitsPath, checkpointPath, lastOkPath, secretPath } = seeded;

      // --- Boot 1: forge payload-v1 ---
      const markerV1 = "payload-v1-history";
      const markerV2 = "payload-v2-history-distinct";
      const shaV1 = payloadShaFor(markerV1);
      const shaV2 = payloadShaFor(markerV2);
      // Sanity: the two markers really do produce distinct shas, so
      // the second ack lands a new ack file and a new history row
      // (rather than being deduped as alreadyAcknowledged).
      expect(shaV1).not.toBe(shaV2);

      writeForgedSidecar(lastOkPath, markerV1);
      let active = await bootFixture(seeded);

      try {
        await installForwarders(page, () => active);

        // Seed alice's token in localStorage so the first ack POST
        // carries Authorization: Bearer <alice-token>. The in-fixture
        // named-token map resolves this to "alice", which the checker
        // writes into the history row's ackedBy. addInitScript must
        // run BEFORE the dashboard renders — the ack button only
        // appears when a token is present — so we cannot defer the
        // seed to a post-goto page.evaluate. To swap to bob later, we
        // queue a SECOND addInitScript before the relevant reload;
        // Playwright accumulates init scripts in registration order,
        // so the last write wins on each subsequent navigation.
        await page.addInitScript(
          ([key, token]) => {
            window.localStorage.setItem(key as string, token as string);
          },
          [REBUILD_TOKEN_STORAGE_KEY, ALICE_TOKEN],
        );

        await page.goto("/");

        const banner = page.locator(
          '[data-testid="panel-ledger-sidecar-forged"]',
        );
        await expect(banner).toBeVisible();
        await expect(banner).toHaveAttribute("data-acknowledged", "false");

        // Before any ack, the "Recent dismissals" panel must NOT
        // render (empty state — no history file on disk yet).
        await expect(
          page.locator('[data-testid="panel-ledger-sidecar-forged-history"]'),
        ).toHaveCount(0);

        // --- Ack #1: alice acks payload-v1 ---
        const ackButton = page.locator(
          '[data-testid="button-ack-ledger-sidecar-forged"]',
        );
        await expect(ackButton).toBeEnabled();
        await ackButton.click();
        await expect(banner).toHaveAttribute("data-acknowledged", "true");

        // --- Restart with payload-v2 (DIFFERENT bytes → new sha) ---
        // The first /integrity poll after ack#1 will have written a
        // valid HMAC'd sidecar back to disk (task #110), so re-forge
        // the bytes (with a different marker, so the prior ack file
        // is stale and discarded) before booting the next fixture.
        // This is the realistic "attacker writes a NEW forged
        // payload, operator reboots" scenario from task #138, and
        // it's also the only way the banner stays visible on the
        // next reload — without re-forging, the fresh /integrity
        // call would report sidecar OK and the whole banner (with
        // the history panel under it) would unmount.
        await active.close();
        writeForgedSidecar(lastOkPath, markerV2);
        active = await bootFixture(seeded);

        // Swap the localStorage token to bob's before the next ack.
        // Queue a SECOND addInitScript — Playwright accumulates them,
        // and the later one overwrites localStorage[key] = BOB on the
        // upcoming reload. The reload is also needed to re-poll the
        // new fixture's /integrity (un-acked v2 banner) AND to pull
        // the history file that ack#1 left on disk.
        await page.addInitScript(
          ([key, token]) => {
            window.localStorage.setItem(key as string, token as string);
          },
          [REBUILD_TOKEN_STORAGE_KEY, BOB_TOKEN],
        );
        await page.reload();

        await expect(banner).toBeVisible();
        await expect(banner).toHaveAttribute("data-acknowledged", "false");

        // History panel now renders alice's row — the rotating log
        // on disk survived the restart even though the single-
        // incident ack file was discarded by the sha mismatch.
        const historyPanel = page.locator(
          '[data-testid="panel-ledger-sidecar-forged-history"]',
        );
        await expect(historyPanel).toBeVisible();
        await expect(
          page.locator(
            '[data-testid="text-ledger-sidecar-forged-history-count"]',
          ),
        ).toHaveText("1 of last 20");
        const firstRow = page.locator(
          '[data-testid="row-ledger-sidecar-forged-history-0"]',
        );
        await expect(firstRow).toHaveAttribute("data-acked-by", ALICE_NAME);
        await expect(firstRow).toHaveAttribute("data-payload-sha", shaV1);
        // Truncated payload sha (first 12 hex chars) is the user-
        // visible label inside the row.
        await expect(firstRow).toContainText(shaV1.slice(0, 12));
        await expect(firstRow).toContainText(ALICE_NAME);

        // --- Ack #2: bob acks payload-v2 ---
        await expect(ackButton).toBeEnabled();
        await ackButton.click();
        await expect(banner).toHaveAttribute("data-acknowledged", "true");

        // --- Restart with SAME payload-v2 bytes ---
        // Re-forge the same payload so the next boot's sidecar read
        // still classifies as forged (keeping the banner — and the
        // history panel under it — alive on the next reload), but
        // with the SAME sha so bob's ack file is still bound to it
        // and survives the restart. Symmetric with task #138's
        // "ack persists across restart" leg.
        await active.close();
        writeForgedSidecar(lastOkPath, markerV2);
        active = await bootFixture(seeded);

        await page.reload();
        await expect(banner).toBeVisible();
        await expect(banner).toHaveAttribute("data-acknowledged", "true");
        await expect(historyPanel).toBeVisible();
        await expect(
          page.locator(
            '[data-testid="text-ledger-sidecar-forged-history-count"]',
          ),
        ).toHaveText("2 of last 20");

        // Newest-first ordering: row-0 is bob/v2, row-1 is alice/v1.
        const row0 = page.locator(
          '[data-testid="row-ledger-sidecar-forged-history-0"]',
        );
        await expect(row0).toHaveAttribute("data-acked-by", BOB_NAME);
        await expect(row0).toHaveAttribute("data-payload-sha", shaV2);
        await expect(row0).toContainText(shaV2.slice(0, 12));
        await expect(row0).toContainText(BOB_NAME);

        const row1 = page.locator(
          '[data-testid="row-ledger-sidecar-forged-history-1"]',
        );
        await expect(row1).toHaveAttribute("data-acked-by", ALICE_NAME);
        await expect(row1).toHaveAttribute("data-payload-sha", shaV1);
        await expect(row1).toContainText(shaV1.slice(0, 12));
        await expect(row1).toContainText(ALICE_NAME);

        // Exactly two rows — no stray history entries leaking in.
        await expect(
          page.locator(
            '[data-testid^="row-ledger-sidecar-forged-history-"]',
          ),
        ).toHaveCount(2);
      } finally {
        await active.close();
        for (const p of [
          lastOkPath,
          secretPath,
          `${lastOkPath}.forged-ack`,
          `${lastOkPath}.forged-ack.log.jsonl`,
          hitsPath,
          checkpointPath,
        ]) {
          try {
            if (existsSync(p)) unlinkSync(p);
          } catch {
            /* ignore */
          }
        }
        rmSync(tmpDir, { recursive: true, force: true });
      }
    });

    test("empty state: no history file on disk → panel does not render even with a forged banner up", async ({
      page,
    }) => {
      const tmpDir = mkdtempSync(
        path.join(tmpdir(), "ledger-forged-history-empty-e2e-"),
      );
      const seeded = seedTmpLedger(tmpDir);
      const { lastOkPath, secretPath, hitsPath, checkpointPath } = seeded;

      writeForgedSidecar(lastOkPath, "payload-empty-state");
      const active = await bootFixture(seeded);

      try {
        await installForwarders(page, () => active);
        await page.goto("/");

        const banner = page.locator(
          '[data-testid="panel-ledger-sidecar-forged"]',
        );
        await expect(banner).toBeVisible();

        // No ack has been performed, so the rotating history log was
        // never created. The endpoint returns `entries: []` and the
        // dashboard renders nothing for the panel (early-return on
        // `entries.length === 0`).
        await expect(
          page.locator('[data-testid="panel-ledger-sidecar-forged-history"]'),
        ).toHaveCount(0);
        await expect(
          page.locator(
            '[data-testid="text-ledger-sidecar-forged-history-count"]',
          ),
        ).toHaveCount(0);
        await expect(
          page.locator(
            '[data-testid^="row-ledger-sidecar-forged-history-"]',
          ),
        ).toHaveCount(0);
      } finally {
        await active.close();
        for (const p of [
          lastOkPath,
          secretPath,
          `${lastOkPath}.forged-ack`,
          `${lastOkPath}.forged-ack.log.jsonl`,
          hitsPath,
          checkpointPath,
        ]) {
          try {
            if (existsSync(p)) unlinkSync(p);
          } catch {
            /* ignore */
          }
        }
        rmSync(tmpDir, { recursive: true, force: true });
      }
    });
  },
);
