#!/usr/bin/env python3
"""Print the most recent ledger-integrity alerts from the on-disk ring
buffer (`data/ledger-alerts.jsonl`) for operators who are SSH'd into a
degraded server and don't want to boot the React dashboard.

Task #93. Reads `kernel.read_recent_alerts()` and renders one line per
entry, newest first, with timestamp, workflow, failure_mode, and the
per-transport delivery status.

Task #103. Cross-references the dashboard's dismissal sidecar
(`data/ledger-alerts.ack.json`) so on-call engineers running the CLI
don't see ghost incidents that the dashboard already considers
handled. By default acked entries are skipped; pass
`--include-acknowledged` to print them with an `ack'd <ts>` suffix.
Missing or malformed sidecar is a soft failure (matches the server's
behavior in `artifacts/api-server/src/lib/alertAckStore.ts`).

Exit code is always 0 when the log is missing or empty: this is an
informational surface, not a correctness gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import kernel  # noqa: E402

ALERTS_ACK_PATH = REPO_ROOT / "data" / "ledger-alerts.ack.json"
_ACK_KEY_RE = re.compile(r"^[0-9a-f]{64}$")


def _compute_alert_id(timestamp: str, message: str) -> str:
    """Mirror `computeAlertId` in `artifacts/api-server/src/lib/alertAckStore.ts`:
    sha256 of `timestamp + "\\n" + message`, hex-encoded."""
    return hashlib.sha256((timestamp + "\n" + message).encode("utf-8")).hexdigest()


def _read_ack_map(path: Path) -> "dict[str, str]":
    """Read the dashboard's dismissal sidecar. Missing or malformed
    file is a soft failure — return `{}` rather than raising, matching
    `readAckMap` on the server side."""
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    trimmed = raw.strip()
    if not trimmed:
        return {}
    try:
        parsed = json.loads(trimmed)
    except json.JSONDecodeError:
        return {}
    if not isinstance(parsed, dict):
        return {}
    out: "dict[str, str]" = {}
    for k, v in parsed.items():
        if isinstance(k, str) and _ACK_KEY_RE.match(k) and isinstance(v, str):
            out[k] = v
    return out


_SINCE_DURATION_RE = re.compile(r"^(\d+)([smhd])$")
_SINCE_UNIT_SECONDS = {"s": 1, "m": 60, "h": 3600, "d": 86400}


def _parse_since(raw: str) -> datetime:
    """Parse `--since` as either a duration (`30m`, `2h`, `1d`, `45s`)
    interpreted as "now minus that interval" or an absolute ISO-8601
    timestamp (`2026-05-26T00:00Z`, `2026-05-26T12:34:56+00:00`).
    Returns a tz-aware UTC datetime. Raises `argparse.ArgumentTypeError`
    on malformed input so argparse surfaces a clean error."""
    s = raw.strip()
    if not s:
        raise argparse.ArgumentTypeError("--since: empty value")
    m = _SINCE_DURATION_RE.match(s)
    if m:
        n = int(m.group(1))
        unit = m.group(2)
        return datetime.now(timezone.utc) - timedelta(
            seconds=n * _SINCE_UNIT_SECONDS[unit]
        )
    iso = s.replace("Z", "+00:00") if s.endswith("Z") else s
    try:
        dt = datetime.fromisoformat(iso)
    except ValueError as e:
        raise argparse.ArgumentTypeError(
            f"--since: not a duration (e.g. 1h) or ISO-8601 timestamp: {raw}"
        ) from e
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _entry_timestamp(entry: dict) -> "datetime | None":
    ts = entry.get("timestamp")
    if not isinstance(ts, str):
        return None
    iso = ts.replace("Z", "+00:00") if ts.endswith("Z") else ts
    try:
        dt = datetime.fromisoformat(iso)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _entry_matches_filters(
    entry: dict,
    since: "datetime | None",
    failure_modes: "set[str] | None",
) -> bool:
    if since is not None:
        dt = _entry_timestamp(entry)
        if dt is None or dt < since:
            return False
    if failure_modes:
        fm = entry.get("failure_mode")
        if not isinstance(fm, str) or fm not in failure_modes:
            return False
    return True


def _fmt_transport(name: str, info: object) -> str:
    if not isinstance(info, dict):
        return f"{name}=?"
    status = info.get("status", "?")
    if status == "failed":
        err = info.get("error", "")
        if err:
            return f"{name}=failed({err})"
        return f"{name}=failed"
    return f"{name}={status}"


def _fmt_entry(entry: dict, ack_ts: "str | None" = None) -> str:
    ts = entry.get("timestamp", "?")
    workflow = entry.get("workflow", "?")
    failure_mode = entry.get("failure_mode", "?")
    delivery = entry.get("delivery") or {}
    transports = " ".join(
        _fmt_transport(name, delivery.get(name))
        for name in ("webhook", "email")
    )
    line = f"{ts}  {workflow}  {failure_mode}  [{transports}]"
    if ack_ts:
        line += f"  ack'd {ack_ts}"
    return line


def main(argv: "list[str] | None" = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Show the most recent ledger-integrity alerts and their "
            "per-transport delivery status."
        )
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="How many of the newest entries to show (default: 10).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a JSON array instead of a human-readable table.",
    )
    parser.add_argument(
        "--since",
        type=_parse_since,
        default=None,
        metavar="WHEN",
        help=(
            "Only show entries newer than WHEN. WHEN is either a "
            "duration like `30m`, `2h`, `1d`, `45s` (interpreted as "
            "now minus that interval) or an ISO-8601 timestamp like "
            "`2026-05-26T00:00Z`."
        ),
    )
    parser.add_argument(
        "--failure-mode",
        action="append",
        default=[],
        metavar="MODE",
        help=(
            "Only show entries with this `failure_mode`. May be "
            "repeated to allow multiple modes (e.g. "
            "`--failure-mode hits_truncated --failure-mode "
            "hits_rewritten`)."
        ),
    )
    parser.add_argument(
        "--include-acknowledged",
        action="store_true",
        help=(
            "Also print alerts that operators dismissed via the "
            "dashboard (sidecar `data/ledger-alerts.ack.json`). "
            "Default is to hide them so the CLI and dashboard agree."
        ),
    )
    args = parser.parse_args(argv)

    limit = max(0, args.limit)
    failure_modes: "set[str] | None" = (
        set(args.failure_mode) if args.failure_mode else None
    )
    since: "datetime | None" = args.since
    has_filters = since is not None or failure_modes is not None

    if limit == 0:
        entries: "list[dict]" = []
    else:
        ack_map = _read_ack_map(ALERTS_ACK_PATH)
        skip_acked = not args.include_acknowledged and bool(ack_map)

        if not skip_acked and not has_filters:
            entries = kernel.read_recent_alerts(limit=limit)
        else:
            # Over-fetch so that, after dropping acked / filtered-out
            # entries, we can still return up to `limit` actionable
            # ones. We don't know how many entries on disk fail a
            # `--since` / `--failure-mode` filter, so when those are
            # set we fetch the whole ring buffer (capped by kernel at
            # `_ALERTS_MAX_ENTRIES`) and slice after filtering.
            if has_filters:
                fetch_n = kernel._ALERTS_MAX_ENTRIES
            else:
                fetch_n = limit + len(ack_map)
            raw_entries = kernel.read_recent_alerts(limit=fetch_n)
            entries = []
            for e in raw_entries:
                if skip_acked:
                    ts = e.get("timestamp", "")
                    msg = e.get("message", "")
                    if isinstance(ts, str) and isinstance(msg, str):
                        alert_id = _compute_alert_id(ts, msg)
                        if alert_id in ack_map:
                            continue
                if not _entry_matches_filters(e, since, failure_modes):
                    continue
                entries.append(e)
                if len(entries) >= limit:
                    break

    if args.json:
        if args.include_acknowledged:
            for e in entries:
                ts = e.get("timestamp", "")
                msg = e.get("message", "")
                if isinstance(ts, str) and isinstance(msg, str):
                    aid = _compute_alert_id(ts, msg)
                    ack_ts = _read_ack_map(ALERTS_ACK_PATH).get(aid)
                    if ack_ts:
                        e["acknowledged_at"] = ack_ts
        json.dump(entries, sys.stdout, indent=2, sort_keys=True, default=str)
        sys.stdout.write("\n")
        return 0

    if not entries:
        print(
            f"No alerts recorded (log: {kernel.ALERTS_LOG}).",
            file=sys.stderr,
        )
        return 0

    print(f"# {len(entries)} most-recent alert(s) from {kernel.ALERTS_LOG}")
    print("# timestamp                         workflow  failure_mode  [transports]")
    ack_map_for_render = (
        _read_ack_map(ALERTS_ACK_PATH) if args.include_acknowledged else {}
    )
    for entry in entries:
        ack_ts = None
        if args.include_acknowledged:
            ts = entry.get("timestamp", "")
            msg = entry.get("message", "")
            if isinstance(ts, str) and isinstance(msg, str):
                ack_ts = ack_map_for_render.get(_compute_alert_id(ts, msg))
        print(_fmt_entry(entry, ack_ts=ack_ts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
