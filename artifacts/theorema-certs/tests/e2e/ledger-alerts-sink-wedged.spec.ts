import { test, expect, type Route } from "@playwright/test";

/**
 * Task #122: end-to-end coverage for the "sink wedged" amber badge added
 * in task #108 / #94.
 *
 * When the in-flight dispatch cap in `kernel._fire_ledger_alert` is
 * saturated at the moment an alert tries to fire, the alert entry is
 * persisted to `data/ledger-alerts.jsonl` with
 * `delivery.{webhook,email}.status == "dropped_backpressure"` and the
 * companion `inflight` / `cap` ints. The dashboard's Recent ledger
 * alerts panel surfaces this by:
 *   - tagging the row with `data-dropped-backpressure="true"` and the
 *     deeper-amber background/border,
 *   - rendering the per-transport pill as
 *     "webhook: suppressed (sink wedged)" with a title attr that names
 *     the inflight / cap saturation,
 *   - appending "(N suppressed (sink wedged))" to the header counter.
 *
 * The behaviour was only verified by typecheck before this spec landed.
 * We mock `/api/lean/ledger-alerts*` via Playwright route interception
 * so the test is deterministic and does not require driving real
 * kernel back-pressure (which can't be hand-seeded into the live
 * `data/ledger-alerts.jsonl` without restart races against the
 * api-server process).
 *
 * Selectors / copy under test
 * (`artifacts/theorema-certs/src/pages/dashboard.tsx` ~1360–1620):
 *   - `[data-testid="panel-ledger-alerts"]`
 *   - `[data-testid="text-ledger-alerts-count"]`
 *   - `[data-testid="row-ledger-alert-0"]` carries
 *     `data-dropped-backpressure="true"`
 *   - `[data-testid="text-ledger-alert-webhook-0"]` reads
 *     "webhook: suppressed (sink wedged)" with a title naming the
 *     inflight / cap values
 *   - `[data-testid="text-ledger-alert-email-0"]` reads
 *     "email: suppressed (sink wedged)" similarly
 */

const LEDGER_ALERTS_URL = "**/api/lean/ledger-alerts*";

function buildWedgedAlertResponse() {
  const timestamp = new Date().toISOString();
  return {
    alerts: [
      {
        id: "sink-wedged-test-id",
        acknowledgedAt: null,
        timestamp,
        workflow: "zeta-burst-101-10000",
        message:
          "Ledger checkpoint verification failed: live prefix sha mismatch",
        failureMode: "live_prefix_sha_mismatch",
        recovery: null,
        hitsPath: "data/hits.txt",
        checkpointPath: "data/hits.txt.checkpoint",
        expectedSize: 1024,
        actualSize: 1024,
        expectedSha:
          "0000000000000000000000000000000000000000000000000000000000000000",
        source: "kernel._verify_checkpoint",
        delivery: {
          webhook: {
            status: "dropped_backpressure",
            error: null,
            inflight: 8,
            cap: 8,
          },
          email: {
            status: "dropped_backpressure",
            error: null,
            inflight: 8,
            cap: 8,
          },
        },
      },
    ],
    limit: 50,
    totalReturned: 1,
    logPath: "data/ledger-alerts.jsonl",
    logExists: true,
    ackGcDropped: 0,
    rotation: 0,
    availableRotations: [],
  };
}

async function installLedgerAlertsMock(
  page: import("@playwright/test").Page,
) {
  await page.route(LEDGER_ALERTS_URL, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(buildWedgedAlertResponse()),
    });
  });
}

test.describe("dashboard: recent ledger alerts 'sink wedged' badge", () => {
  test("renders the deeper-amber sink-wedged row, suppressed pills, and header counter suffix", async ({
    page,
  }) => {
    await installLedgerAlertsMock(page);

    await page.goto("/");

    const panel = page.locator('[data-testid="panel-ledger-alerts"]');
    await expect(panel).toBeVisible();

    // Header counter — must include the "(1 suppressed (sink wedged))"
    // suffix so a refactor that drops the counter is caught.
    const counter = page.locator('[data-testid="text-ledger-alerts-count"]');
    await expect(counter).toBeVisible();
    await expect(counter).toContainText("1 entry");
    await expect(counter).toContainText("1 suppressed (sink wedged)");

    // Row — must carry the data attribute the panel uses to gate the
    // deeper-amber styling. Asserting on the attribute (rather than the
    // class string) keeps the test resilient to Tailwind shade tweaks
    // while still pinning the operator-visible signal.
    const row = page.locator('[data-testid="row-ledger-alert-0"]');
    await expect(row).toBeVisible();
    await expect(row).toHaveAttribute("data-dropped-backpressure", "true");

    // Per-transport pills — exact copy + tooltip that names the
    // inflight / cap saturation. Both webhook and email are wedged in
    // the fixture so a future refactor that special-cases only one
    // transport doesn't silently regress.
    const webhookPill = page.locator(
      '[data-testid="text-ledger-alert-webhook-0"]',
    );
    await expect(webhookPill).toBeVisible();
    await expect(webhookPill).toHaveText("webhook: suppressed (sink wedged)");
    await expect(webhookPill).toHaveAttribute("data-status", "dropped_backpressure");
    const webhookTitle = await webhookPill.getAttribute("title");
    expect(webhookTitle).toBeTruthy();
    expect(webhookTitle).toContain("inflight=8");
    expect(webhookTitle).toContain("cap=8");
    expect(webhookTitle).toContain("sink itself is wedged");

    const emailPill = page.locator(
      '[data-testid="text-ledger-alert-email-0"]',
    );
    await expect(emailPill).toBeVisible();
    await expect(emailPill).toHaveText("email: suppressed (sink wedged)");
    await expect(emailPill).toHaveAttribute("data-status", "dropped_backpressure");
    const emailTitle = await emailPill.getAttribute("title");
    expect(emailTitle).toBeTruthy();
    expect(emailTitle).toContain("inflight=8");
    expect(emailTitle).toContain("cap=8");
  });
});
