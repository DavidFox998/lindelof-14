import { test, expect, type Route } from "@playwright/test";

/**
 * Task #131: end-to-end coverage for the "alerts suppressed —
 * acknowledged" indicator (and its "failure mode changed while
 * silenced" companion badge) added to the Lean 4 Verification
 * monitor panel by Task #115.
 *
 * Selectors / copy under test:
 *   - `[data-testid="text-ledger-monitor-suppressed"]` renders when
 *     `monitor.lastAcknowledgedAlertId` is non-null and contains the
 *     copy "alerts suppressed — acknowledged".
 *   - `[data-testid="link-ledger-monitor-ack-id"]` has
 *     `href="#alert-<id>"` and visible text equal to the first 12
 *     chars of the id followed by an ellipsis.
 *   - `[data-testid="badge-ledger-monitor-silenced-transition"]`
 *     renders only when the live `failureMode` differs from
 *     `monitor.lastAlertedFailureMode` (and the live ledger is
 *     non-ok).
 *   - The whole suppressed block stays out of the DOM when
 *     `lastAcknowledgedAlertId` is null.
 */

const LEDGER_INTEGRITY_URL = "**/api/ledger/integrity*";

type SuppressedOverrides = {
  status: "ok" | "mismatch";
  failureMode: string | null;
  lastAcknowledgedAlertId: string | null;
  lastAlertedFailureMode: string | null;
};

function buildLedgerIntegrityBody(overrides: SuppressedOverrides) {
  const nowIso = new Date().toISOString();
  return {
    status: overrides.status,
    failureMode: overrides.failureMode,
    reason:
      overrides.status === "ok"
        ? null
        : "Synthetic mismatch for suppressed-badge e2e coverage.",
    checkpointSize: 1024,
    checkpointSha:
      "0000000000000000000000000000000000000000000000000000000000000000",
    liveSize: 1024,
    livePrefixSha:
      "0000000000000000000000000000000000000000000000000000000000000000",
    growthBytes: 0,
    checkedAt: nowIso,
    ledgerLastModified: nowIso,
    ledgerPath: "data/hits.txt",
    checkpointPath: "data/hits.txt.checkpoint",
    lastOkAt: nowIso,
    lastOkAgeSeconds: 5,
    lastCheckedAt: nowIso,
    lastCheckedAgeSeconds: 5,
    staleThresholdSeconds: 1800,
    stale: false,
    checkedStaleThresholdSeconds: 600,
    checkedStale: false,
    checkpointLastModified: nowIso,
    checkpointAgeSeconds: 100,
    checkpointCoverageRatio: 1,
    checkpointStaleThresholdSeconds: 2592000,
    checkpointStale: false,
    lastOkSidecarStatus: "ok",
    lastOkSidecarStatusAcknowledgedAt: null,
    monitor: {
      enabled: true,
      intervalSeconds: 300,
      lastTickAt: nowIso,
      lastAlertedFailureMode: overrides.lastAlertedFailureMode,
      lastAcknowledgedAlertId: overrides.lastAcknowledgedAlertId,
      watchdogState: "ok",
      watchdogLastFiredAt: null,
    },
  };
}

async function installLedgerIntegrityMock(
  page: import("@playwright/test").Page,
  overridesRef: { current: SuppressedOverrides },
) {
  await page.route(LEDGER_INTEGRITY_URL, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(buildLedgerIntegrityBody(overridesRef.current)),
    });
  });
}

test.describe("dashboard: ledger monitor suppressed badge", () => {
  test("renders the suppressed indicator with ack-id link, surfaces the silenced-transition badge when failure modes diverge, and stays absent when no alert is acknowledged", async ({
    page,
  }) => {
    const ackedId =
      "01HX9YQF8VABCDEF0123456789ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
    const overridesRef: { current: SuppressedOverrides } = {
      current: {
        status: "mismatch",
        failureMode: "truncation",
        lastAcknowledgedAlertId: ackedId,
        lastAlertedFailureMode: "truncation",
      },
    };

    await installLedgerIntegrityMock(page, overridesRef);

    // Case 1: alert acknowledged, live failure mode matches the
    // acked failure mode — suppressed paragraph visible, no
    // silenced-transition badge.
    await page.goto("/");

    const suppressed = page.locator(
      '[data-testid="text-ledger-monitor-suppressed"]',
    );
    await expect(suppressed).toBeVisible();
    await expect(suppressed).toContainText("alerts suppressed — acknowledged");
    await expect(suppressed).toHaveAttribute(
      "data-acknowledged-alert-id",
      ackedId,
    );

    const ackLink = page.locator('[data-testid="link-ledger-monitor-ack-id"]');
    await expect(ackLink).toBeVisible();
    await expect(ackLink).toHaveAttribute("href", `#alert-${ackedId}`);
    await expect(ackLink).toHaveText(`${ackedId.slice(0, 12)}…`);

    await expect(
      page.locator(
        '[data-testid="badge-ledger-monitor-silenced-transition"]',
      ),
    ).toHaveCount(0);

    // Case 2: live failure mode drifts away from the acked one
    // while the alert is still acknowledged — silenced-transition
    // badge must light up.
    overridesRef.current = {
      status: "mismatch",
      failureMode: "in_place_rewrite",
      lastAcknowledgedAlertId: ackedId,
      lastAlertedFailureMode: "truncation",
    };
    await page.reload();

    await expect(suppressed).toBeVisible();
    const transitionBadge = page.locator(
      '[data-testid="badge-ledger-monitor-silenced-transition"]',
    );
    await expect(transitionBadge).toBeVisible();
    await expect(transitionBadge).toContainText(
      "failure mode changed while silenced → in_place_rewrite",
    );

    // Case 3: control — no acknowledged alert id, the entire
    // suppressed paragraph (and its child badge) stays out of the
    // DOM.
    overridesRef.current = {
      status: "ok",
      failureMode: null,
      lastAcknowledgedAlertId: null,
      lastAlertedFailureMode: null,
    };
    await page.reload();

    await expect(
      page.locator('[data-testid="text-ledger-monitor-suppressed"]'),
    ).toHaveCount(0);
    await expect(
      page.locator('[data-testid="link-ledger-monitor-ack-id"]'),
    ).toHaveCount(0);
    await expect(
      page.locator(
        '[data-testid="badge-ledger-monitor-silenced-transition"]',
      ),
    ).toHaveCount(0);
  });
});
