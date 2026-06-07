#!/usr/bin/env python3
"""opera_push.py -- Portable GitHub push + release script for Opera Numerorum

Drop this file into any Replit workspace that is part of the Opera Numerorum
suite.  Run it once to push all content to GitHub and optionally create a
tagged release for Zenodo archival.

Prerequisites:
  - GITHUB_PAT environment variable set (Replit secret named GITHUB_PAT)
  - The GitHub repo must already exist at github.com/DavidFox998/<repo-name>
    Create it manually or via: python3 opera_push.py --create-repo

Usage:
    python3 opera_push.py                      # push only
    python3 opera_push.py --release            # push + tag v1.0.0 + release
    python3 opera_push.py --release --tag v1.1.0   # custom tag
    python3 opera_push.py --dry-run            # list files, no API calls
    python3 opera_push.py --create-repo        # create GitHub repo then push
    python3 opera_push.py --create-repo --release  # all-in-one first-time setup

Configuration (edit GITHUB_USER and REPO_NAME below, or set env vars):
    OPERA_GITHUB_USER -- defaults to "DavidFox998"
    OPERA_REPO_NAME   -- defaults to the workspace directory name
"""

import base64, hashlib, json, os, sys, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.parse

# ── Config ────────────────────────────────────────────────────────────────────

PAT       = os.environ.get("GITHUB_PAT", "")
USER      = os.environ.get("OPERA_GITHUB_USER", "DavidFox998")
BRANCH    = "main"
WORKSPACE = os.path.dirname(os.path.abspath(__file__))

# Detect repo name from directory name if not overridden
_dir_name = os.path.basename(WORKSPACE)
REPO      = os.environ.get("OPERA_REPO_NAME", _dir_name)

AUTHOR = {"name": "David Fox", "email": "david@opera-numerorum"}

# Directories never pushed to GitHub
EXCLUDE_DIRS = {
    '.git', 'node_modules', '.pnpm-store', '__pycache__', '.local',
    'artifacts', 'lib', 'scripts', '.cache', '.pythonlibs',
    'attached_assets', 'HISTORICAL',
    # Opera Numerorum private content -- only in the main workspace
    'AUREUM_REPO', 'AUREUM_STAGE', 'M_DRAFT', 'M_FINAL',
}

# Files never pushed (oversized archives and private content)
EXCLUDE_FILES = {
    'CLAY_REPO.tar.gz', 'AUREUM_REPO.tar.gz', 'M_FINAL.zip',
    'MORNING_STAR_REPO.tar.gz', 'HISTORICAL.zip',
    'opera_numerorum_section8.zip',
}

MAX_BLOB_BYTES = 50 * 1024 * 1024  # 50 MB -- GitHub API limit

# ── HTTP helpers ──────────────────────────────────────────────────────────────

def _gh_request(method, url, body=None, extra_headers=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {
        "Authorization": f"token {PAT}",
        "Accept":        "application/vnd.github.v3+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if data:
        headers["Content-Type"] = "application/json"
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        return json.loads(e.read()), e.code

def gh(method, path, body=None):
    return _gh_request(method, f"https://api.github.com/repos/{USER}/{REPO}{path}", body)

def gh_api(method, path, body=None):
    return _gh_request(method, f"https://api.github.com{path}", body)

def gh_upload_asset(upload_url_prefix, name, content, mime="application/octet-stream"):
    url = f"{upload_url_prefix}?name={urllib.parse.quote(name)}"
    req = urllib.request.Request(url, data=content, method="POST")
    req.add_header("Authorization", f"token {PAT}")
    req.add_header("Content-Type", mime)
    req.add_header("Accept", "application/vnd.github.v3+json")
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        return json.loads(e.read()), e.code

# ── File collection ───────────────────────────────────────────────────────────

def collect_files():
    result = []
    for dirpath, dirnames, filenames in os.walk(WORKSPACE):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fname in filenames:
            ab = os.path.join(dirpath, fname)
            rel = os.path.relpath(ab, WORKSPACE)
            if rel in EXCLUDE_FILES:
                continue
            try:
                size = os.path.getsize(ab)
            except OSError:
                continue
            if size > MAX_BLOB_BYTES:
                print(f"  SKIP (>50MB): {rel}  ({size//1024//1024} MB)")
                continue
            result.append((rel, ab))
    result.sort()
    return result

def git_blob_sha(content: bytes) -> str:
    return hashlib.sha1(f"blob {len(content)}\0".encode() + content).hexdigest()

# ── Push logic ────────────────────────────────────────────────────────────────

def create_blob_worker(relpath, abspath):
    with open(abspath, "rb") as f:
        content = f.read()
    resp, code = gh("POST", "/git/blobs", {
        "content": base64.b64encode(content).decode(),
        "encoding": "base64",
    })
    if code in (200, 201):
        return relpath, resp["sha"], None
    return relpath, None, f"HTTP {code}: {resp.get('message','?')}"

def run_push(dry_run=False):
    if not PAT:
        sys.exit("ERROR: GITHUB_PAT environment variable is not set.")

    print(f"==> Collecting local files for '{REPO}' ...")
    files = collect_files()
    print(f"    {len(files)} files in push scope")

    if dry_run:
        for rel, _ in files:
            print(f"  {rel}")
        print("Dry run complete.")
        return None

    # Get current GitHub state
    ref, code = gh("GET", f"/git/refs/heads/{BRANCH}")
    if code != 200:
        sys.exit(f"ERROR: cannot read branch '{BRANCH}' on {REPO}: {ref.get('message','?')}")
    commit_sha = ref["object"]["sha"]
    commit, _ = gh("GET", f"/git/commits/{commit_sha}")
    tree, _ = gh("GET", f"/git/trees/{commit['tree']['sha']}?recursive=1")
    existing = {i["path"]: i["sha"] for i in tree.get("tree", []) if i["type"] == "blob"}
    print(f"    existing blobs: {len(existing)}")

    # Identify new/changed
    to_upload = []
    for rel, ab in files:
        with open(ab, "rb") as f:
            content = f.read()
        if existing.get(rel) != git_blob_sha(content):
            to_upload.append((rel, ab))

    unchanged = len(files) - len(to_upload)
    print(f"    unchanged: {unchanged}  new/changed: {len(to_upload)}")

    if not to_upload:
        print("==> Nothing changed -- GitHub already up to date.")
        return commit_sha

    print(f"==> Creating {len(to_upload)} blobs (8 workers) ...")
    blob_map = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        futs = {pool.submit(create_blob_worker, r, a): r for r, a in to_upload}
        done = 0
        for fut in as_completed(futs):
            rel, sha, err = fut.result()
            done += 1
            if err:
                print(f"  FAIL: {rel} -- {err}")
            else:
                blob_map[rel] = sha
            if done % 50 == 0 or done == len(to_upload):
                print(f"  ... {done}/{len(to_upload)} blobs")

    # Build tree
    entries = []
    for rel, ab in files:
        with open(ab, "rb") as f:
            c = f.read()
        sha = blob_map.get(rel) or existing.get(rel) or git_blob_sha(c)
        entries.append({"path": rel, "mode": "100644", "type": "blob", "sha": sha})

    print(f"==> Creating tree ({len(entries)} entries) ...")
    new_tree, code = gh("POST", "/git/trees", {"tree": entries})
    if code not in (200, 201):
        sys.exit(f"ERROR creating tree: {code}: {new_tree}")

    from datetime import datetime
    date_str = datetime.utcnow().strftime("%Y-%m-%d")
    now_iso  = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    print("==> Creating commit ...")
    new_commit, code = gh("POST", "/git/commits", {
        "message": f"Opera Numerorum -- {date_str}\n\nPart of the Opera Numerorum certified mathematical suite.\nAuthor: David J. Fox | ORCID 0009-0008-1290-6105",
        "tree":    new_tree["sha"],
        "parents": [commit_sha],
        "author":  {**AUTHOR, "date": now_iso},
    })
    if code not in (200, 201):
        sys.exit(f"ERROR creating commit: {code}: {new_commit}")

    print("==> Updating branch ref ...")
    upd, code = gh("PATCH", f"/git/refs/heads/{BRANCH}", {
        "sha": new_commit["sha"], "force": True,
    })
    if code not in (200, 201):
        sys.exit(f"ERROR updating ref: {code}: {upd}")

    new_sha = new_commit["sha"]
    print(f"\nSUCCESS: {len(to_upload)} file(s) pushed")
    print(f"  Commit: https://github.com/{USER}/{REPO}/commit/{new_sha}")
    return new_sha

# ── Release logic ─────────────────────────────────────────────────────────────

def run_release(tag_name, commit_sha, release_assets=None):
    from datetime import datetime
    now_iso = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    print(f"\n==> Creating tag '{tag_name}' ...")
    tag_obj, tc = gh("POST", "/git/tags", {
        "tag":     tag_name,
        "message": f"Opera Numerorum {tag_name} -- {REPO}",
        "object":  commit_sha,
        "type":    "commit",
        "tagger":  {**AUTHOR, "date": now_iso},
    })
    if tc in (200, 201):
        ref_resp, rc = gh("POST", "/git/refs", {
            "ref": f"refs/tags/{tag_name}",
            "sha": tag_obj["sha"],
        })
        if rc in (200, 201):
            print(f"    tag ref: refs/tags/{tag_name}")
        elif rc == 422:
            gh("PATCH", f"/git/refs/tags/{tag_name}", {"sha": tag_obj["sha"], "force": True})
            print(f"    tag ref updated (already existed)")

    print(f"==> Creating release '{tag_name}' ...")
    rel, code = gh("POST", "/releases", {
        "tag_name":         tag_name,
        "target_commitish": BRANCH,
        "name":             f"Opera Numerorum {tag_name} -- {REPO}",
        "body":             f"## {REPO} {tag_name}\n\nPart of the Opera Numerorum certified mathematical suite.\n**Author:** David J. Fox | ORCID 0009-0008-1290-6105\n\nThis release triggers automatic Zenodo archival.\nConnect at: https://zenodo.org/account/settings/github/\n",
        "draft":            False,
        "prerelease":       False,
    })
    if code not in (200, 201):
        if "already_exists" in str(rel):
            print(f"  Release {tag_name} already exists.")
            return
        sys.exit(f"ERROR creating release: {code}: {rel}")

    release_url = rel["html_url"]
    upload_url  = rel["upload_url"].split("{")[0]
    print(f"    Release: {release_url}")

    # Upload any specified release assets
    if release_assets:
        for asset_path in release_assets:
            if not os.path.exists(asset_path):
                print(f"  SKIP asset (not found): {asset_path}")
                continue
            name = os.path.basename(asset_path)
            size = os.path.getsize(asset_path) // 1024 // 1024
            print(f"  Uploading {name} ({size} MB) ...")
            with open(asset_path, "rb") as f:
                content = f.read()
            resp, code = gh_upload_asset(upload_url, name, content)
            if code in (200, 201):
                print(f"    OK: {resp.get('browser_download_url', name)}")
            else:
                print(f"    FAIL ({code}): {resp.get('message','?')}")

# ── Repo creation ─────────────────────────────────────────────────────────────

def create_repo_if_missing():
    info, code = gh("GET", "")
    if code == 200:
        print(f"  Repo already exists: {info['html_url']}")
        return
    print(f"==> Creating github.com/{USER}/{REPO} ...")
    resp, code = gh_api("POST", "/user/repos", {
        "name":        REPO,
        "description": f"Opera Numerorum: {REPO}",
        "private":     False,
        "auto_init":   True,
    })
    if code in (200, 201):
        print(f"  Created: {resp['html_url']}")
        import time; time.sleep(2)  # let GitHub initialize
    else:
        sys.exit(f"ERROR creating repo: {code}: {resp}")

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    dry_run     = "--dry-run"     in sys.argv
    do_release  = "--release"     in sys.argv
    do_create   = "--create-repo" in sys.argv

    tag_name = "v1.0.0"
    for i, arg in enumerate(sys.argv):
        if arg == "--tag" and i + 1 < len(sys.argv):
            tag_name = sys.argv[i + 1]

    # Collect optional release assets from command line (--asset path/to/file)
    release_assets = []
    for i, arg in enumerate(sys.argv):
        if arg == "--asset" and i + 1 < len(sys.argv):
            release_assets.append(sys.argv[i + 1])

    print("=" * 70)
    print(f"Opera Numerorum -- push for '{REPO}'")
    print(f"Target: github.com/{USER}/{REPO}  branch={BRANCH}")
    print("=" * 70)

    if do_create:
        create_repo_if_missing()

    commit_sha = run_push(dry_run=dry_run)

    if do_release and not dry_run and commit_sha:
        run_release(tag_name, commit_sha, release_assets=release_assets or None)
