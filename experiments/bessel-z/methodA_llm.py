#!/usr/bin/env python3
"""
Method A [T=0] — genuine LLM direct-generation measurement of I_n(x).

HONESTY:
  * These are REAL LLM calls via the Replit AI Integrations Anthropic proxy
    (billed to the user's credits). No values are fabricated.
  * temperature=0 (the "T=0" regime). At temperature 0 the model is
    near-deterministic, so trials largely repeat; we run TRIALS_PER_CASE
    trials and record what actually came back (errors counted honestly).
  * If a call fails or the reply cannot be parsed as a number, that trial is
    counted as an ERROR (not silently dropped, not back-filled).

Output: BesselI_methodA_raw.json  (per-(case,trial) raw outputs)
"""
import os, json, urllib.request, urllib.error, re, time
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
TRIALS_PER_CASE = int(os.environ.get("BESSEL_A_TRIALS", "5"))
MODEL = os.environ.get("BESSEL_A_MODEL", "claude-haiku-4-5")
MAX_WORKERS = int(os.environ.get("BESSEL_A_WORKERS", "8"))

BASE = os.environ["AI_INTEGRATIONS_ANTHROPIC_BASE_URL"].rstrip("/")
KEY = os.environ["AI_INTEGRATIONS_ANTHROPIC_API_KEY"]
URL = BASE + "/v1/messages"

PROMPT = (
    "Compute the modified Bessel function of the first kind I_{n}(x) for "
    "n={n} and x={x}. This is a direct-recall numerical task: do NOT use any "
    "tool, code, or step-by-step arithmetic. Reply with ONLY the decimal "
    "value to as many significant digits as you can, and nothing else."
)

NUM_RE = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")


def call_once(n, x):
    body = json.dumps({
        "model": MODEL,
        "max_tokens": 8192,
        "temperature": 0,
        "messages": [{"role": "user", "content": PROMPT.format(n=n, x=x)}],
    }).encode()
    req = urllib.request.Request(URL, data=body, method="POST", headers={
        "x-api-key": KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    })
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                data = json.load(r)
            parts = data.get("content", [])
            text = "".join(p.get("text", "") for p in parts if p.get("type") == "text").strip()
            m = NUM_RE.search(text.replace(",", ""))
            val = float(m.group(0)) if m else None
            return {"raw": text, "value": val, "ok": val is not None}
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 3:
                time.sleep(2 ** attempt)
                continue
            return {"raw": f"HTTPError {e.code}: {e.read().decode()[:200]}", "value": None, "ok": False}
        except Exception as e:  # noqa: BLE001
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            return {"raw": f"ERR {type(e).__name__}: {e}", "value": None, "ok": False}
    return {"raw": "exhausted", "value": None, "ok": False}


def main():
    with open(os.path.join(HERE, "BesselI_TEST_SET.json")) as f:
        cases = json.load(f)
    jobs = []  # (case_idx, trial)
    for ci, _ in enumerate(cases):
        for t in range(TRIALS_PER_CASE):
            jobs.append((ci, t))
    results = {ci: [None] * TRIALS_PER_CASE for ci in range(len(cases))}

    def run(job):
        ci, t = job
        c = cases[ci]
        return job, call_once(c["n"], c["x"])

    done = 0
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futs = [ex.submit(run, j) for j in jobs]
        for fut in as_completed(futs):
            (ci, t), res = fut.result()
            results[ci][t] = res
            done += 1
            if done % 25 == 0:
                print(f"  {done}/{len(jobs)} trials done", flush=True)

    raw = []
    for ci, c in enumerate(cases):
        raw.append({
            "n": c["n"], "x": c["x"], "sym": c["sym"],
            "true_value": c["true_value"],
            "trials": [results[ci][t] for t in range(TRIALS_PER_CASE)],
        })
    out = os.path.join(HERE, "BesselI_methodA_raw.json")
    with open(out, "w") as f:
        json.dump({"model": MODEL, "temperature": 0,
                   "trials_per_case": TRIALS_PER_CASE, "cases": raw}, f, indent=2)
    n_ok = sum(1 for ci in results for r in results[ci] if r and r["ok"])
    print(f"wrote {out}: {len(jobs)} trials, {n_ok} parsed ok, {len(jobs)-n_ok} errors")


if __name__ == "__main__":
    main()
