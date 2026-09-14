#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path

CID_RE = re.compile(r"\b[IiLl][0-9a-fA-F]{40}\b")
CSV_DATE_FMT = "%Y-%m-%d %H:%M:%S"
CSV_CHANGE_ID_COLUMN = "Gerrit Change-Id"
CSV_DATE_COLUMN = "committer date"
CSV_SUMMARY_COLUMN = "commit summary"
CSV_MASTER_COMMIT_COLUMN = "commit id in the master branch"
CSV_PICK_COLUMN = "To be cherry-picked"


def fmt(cmd):
    return " ".join(shlex.quote(str(c)) for c in cmd)


def run(cmd, check=True, capture=False):
    if not capture:
        print(f"+ {fmt(cmd)}", flush=True)

    p = subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )

    if check and p.returncode != 0:
        raise subprocess.CalledProcessError(p.returncode, cmd, p.stdout, p.stderr)

    return p


def git(*args, check=True, capture=False):
    return run(["git", *args], check=check, capture=capture)


def fail(msg, code=1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def read_change_ids(path):
    text = Path(path).read_text(errors="ignore")
    ids = []
    seen = set()

    for m in CID_RE.finditer(text):
        raw = m.group(0)
        # Gerrit Change-Ids start with uppercase I.
        # This also fixes pasted IDs that look like lowercase l.
        cid = "I" + raw[1:].lower()

        if cid not in seen:
            seen.add(cid)
            ids.append(cid)

    return ids


def normalize_change_id(raw):
    m = CID_RE.search(raw or "")
    if not m:
        return None
    return "I" + m.group(0)[1:].lower()


def is_likely_csv(path):
    if path.suffix.lower() == ".csv":
        return True

    try:
        with path.open(newline="", errors="ignore") as f:
            header = f.readline()
    except OSError:
        return False

    return CSV_CHANGE_ID_COLUMN in header and CSV_DATE_COLUMN in header


def should_pick_row(row):
    value = (row.get(CSV_PICK_COLUMN, "") or "").strip()
    if not value:
        return True
    return value.upper() in {"Y", "YES", "TRUE", "1"}


def read_sorted_csv_changes(path):
    rows = []
    seen = set()

    with path.open(newline="", errors="ignore") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            fail(f"{path} does not contain a CSV header")

        missing = [
            col
            for col in (CSV_CHANGE_ID_COLUMN, CSV_DATE_COLUMN)
            if col not in reader.fieldnames
        ]
        if missing:
            fail(f"{path} is missing required CSV column(s): {', '.join(missing)}")

        for line_no, row in enumerate(reader, start=2):
            if not should_pick_row(row):
                continue

            cid = normalize_change_id(row.get(CSV_CHANGE_ID_COLUMN, ""))
            if not cid:
                fail(
                    f"{path}:{line_no} does not contain a valid Gerrit Change-Id "
                    f"in column '{CSV_CHANGE_ID_COLUMN}'"
                )

            date_raw = (row.get(CSV_DATE_COLUMN, "") or "").strip()
            if not date_raw:
                fail(f"{path}:{line_no} has an empty '{CSV_DATE_COLUMN}' value")

            try:
                commit_dt = datetime.strptime(date_raw, CSV_DATE_FMT)
            except ValueError as e:
                fail(
                    f"{path}:{line_no} has invalid '{CSV_DATE_COLUMN}' value "
                    f"{date_raw!r}: {e}"
                )

            if cid in seen:
                continue

            seen.add(cid)
            rows.append(
                {
                    "change_id": cid,
                    "committer_date": commit_dt,
                    "committer_date_raw": date_raw,
                    "master_commit": (row.get(CSV_MASTER_COMMIT_COLUMN, "") or "").strip(),
                    "summary": (row.get(CSV_SUMMARY_COLUMN, "") or "").strip(),
                    "line_no": line_no,
                }
            )

    # Keep the CSV row order. lts-triage-v2.py writes the report in base
    # branch ancestry order, which is the order the patches have to be
    # picked in. Re-sorting on the committer date would undo that: patches
    # merged together share a timestamp, and a topic branch keeps its
    # original dates but is merged days later, so the dates are not in
    # ancestry order.
    return rows


def write_sorted_list(path, rows):
    header = "committer date | master commit | change-id | summary"
    lines = [header]

    for row in rows:
        lines.append(
            " | ".join(
                [
                    row["committer_date_raw"],
                    row["master_commit"] or "-",
                    row["change_id"],
                    row["summary"] or "-",
                ]
            )
        )

    output = "\n".join(lines) + "\n"
    Path(path).write_text(output)


def load_input(path):
    if is_likely_csv(path):
        rows = read_sorted_csv_changes(path)
        if not rows:
            fail(f"No cherry-pickable CSV rows found in {path}")
        return {
            "mode": "csv",
            "rows": rows,
            "change_ids": [row["change_id"] for row in rows],
        }

    change_ids = read_change_ids(path)
    if not change_ids:
        fail(f"No Gerrit Change-Ids found in {path}")
    return {"mode": "plain", "rows": [], "change_ids": change_ids}


def is_cherry_pick_in_progress():
    p = git("rev-parse", "-q", "--verify", "CHERRY_PICK_HEAD", check=False, capture=True)
    return p.returncode == 0


def tracked_tree_clean():
    git("update-index", "-q", "--refresh", check=False)
    return git("diff-index", "--quiet", "HEAD", "--", check=False).returncode == 0


def ensure_clean():
    if not tracked_tree_clean():
        fail("Your working tree has tracked changes. Commit or stash them first.")


def load_done(done_path):
    if not done_path.exists():
        return set()
    return {x.strip() for x in done_path.read_text().splitlines() if x.strip()}


def mark_done(done_path, cid):
    done = load_done(done_path)
    if cid not in done:
        with done_path.open("a") as f:
            f.write(cid + "\n")


def log_has_fixed_string(s):
    p = git(
        "log",
        "--format=%H",
        "--fixed-strings",
        f"--grep={s}",
        "-n",
        "1",
        "HEAD",
        check=False,
        capture=True,
    )
    return bool(p.stdout.strip())


def latest_commit_message():
    return git("log", "-1", "--pretty=%B", capture=True).stdout


def resume_pending(done_path, pending_path):
    if not pending_path.exists():
        return

    data = json.loads(pending_path.read_text())
    cid = data["change_id"]
    revision = data["revision"]

    if is_cherry_pick_in_progress():
        fail(
            "A cherry-pick is still in progress.\n"
            "Resolve conflicts, then run:\n"
            "  git add <files>\n"
            "  git cherry-pick --continue\n"
            "Then rerun this script."
        )

    msg = latest_commit_message()
    marker = f"(cherry picked from commit {revision})"

    if marker in msg:
        print(f"Previous pending cherry-pick completed: {cid}")
        mark_done(done_path, cid)
        pending_path.unlink()
        return

    fail(
        f"Pending state exists for {cid}, but HEAD does not contain:\n"
        f"  {marker}\n\n"
        f"If you aborted that cherry-pick, delete {pending_path} and rerun."
    )


def query_gerrit(args, cid):
    cmd = [
        "ssh",
        "-p",
        str(args.port),
        f"{args.user}@{args.host}",
        "gerrit",
        "query",
        "--format=JSON",
        "--current-patch-set",
        f"project:{args.project}",
        f"change:{cid}",
    ]

    if args.branch:
        cmd.append(f"branch:{args.branch}")

    p = run(cmd, check=False, capture=True)

    if p.returncode != 0:
        print(p.stdout, file=sys.stderr)
        print(p.stderr, file=sys.stderr)
        fail(f"Gerrit query failed for {cid}")

    results = []

    for line in p.stdout.splitlines():
        line = line.strip()
        if not line:
            continue

        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        if obj.get("type") != "stats":
            results.append(obj)

    if not results:
        fail(f"No Gerrit change found for {cid}")

    if len(results) > 1:
        print(f"Multiple Gerrit changes found for {cid}:", file=sys.stderr)
        for r in results:
            cps = r.get("currentPatchSet") or {}
            print(
                f"  number={r.get('number')} "
                f"branch={r.get('branch')} "
                f"status={r.get('status')} "
                f"ref={cps.get('ref')}",
                file=sys.stderr,
            )
        fail("Rerun with --branch <branch-name> to make this unambiguous.")

    r = results[0]
    cps = r.get("currentPatchSet") or {}

    if not cps.get("ref") or not cps.get("revision"):
        fail(f"Gerrit result for {cid} did not contain current patch-set ref/revision.")

    return {
        "number": str(r.get("number")),
        "branch": r.get("branch", ""),
        "status": r.get("status", ""),
        "ref": cps["ref"],
        "revision": cps["revision"],
    }


def verify_trailers(expected_cid):
    msg = latest_commit_message()
    missing = []

    if not re.search(rf"^Change-Id:\s+{re.escape(expected_cid)}\s*$", msg, re.M | re.I):
        missing.append("Change-Id")

    if not re.search(r"^Signed-off-by:\s+.+ <[^>]+>\s*$", msg, re.M):
        missing.append("Signed-off-by")

    if not re.search(r"^\(cherry picked from commit [0-9a-fA-F]{7,64}\)$", msg, re.M):
        missing.append("(cherry picked from commit ...)")

    if missing:
        print(f"WARNING: latest commit may be missing trailer(s): {', '.join(missing)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "change_file",
        help="Text file containing Gerrit Change-Ids or a CSV export with Gerrit metadata",
    )
    ap.add_argument("--user", default=os.getenv("GERRIT_USER", "ManishVB-Arm"))
    ap.add_argument("--host", default=os.getenv("GERRIT_HOST", "review.trustedfirmware.org"))
    ap.add_argument("--port", default=os.getenv("GERRIT_PORT", "29418"))
    ap.add_argument("--project", default=os.getenv("GERRIT_PROJECT", "TF-A/trusted-firmware-a"))
    ap.add_argument("--branch", default=os.getenv("BRANCH", ""))
    ap.add_argument(
        "--signoff",
        action="store_true",
        default=os.getenv("SIGNOFF") == "1",
        help="Add your own Signed-off-by using git cherry-pick -s",
    )
    ap.add_argument("--state-dir", default=".")
    ap.add_argument(
        "--output-sorted-list",
        help=(
            "When the input is CSV, write the pick order to this file "
            "before cherry-picking"
        ),
    )
    ap.add_argument(
        "--list-only",
        action="store_true",
        help="Parse input, optionally write the pick order, and exit without cherry-picking",
    )
    args = ap.parse_args()

    input_path = Path(args.change_file).expanduser()
    loaded = load_input(input_path)
    change_ids = loaded["change_ids"]

    print(f"Found {len(change_ids)} Change-Ids")

    if loaded["mode"] == "csv":
        print("CSV input detected; using the row order of the report.")
        if args.output_sorted_list:
            output_path = Path(args.output_sorted_list).expanduser()
            write_sorted_list(output_path, loaded["rows"])
            print(f"Wrote sorted list to {output_path}")

    if args.list_only:
        return

    inside = git("rev-parse", "--is-inside-work-tree", check=False, capture=True)
    if inside.returncode != 0 or inside.stdout.strip() != "true":
        fail("Run this from inside the target git repository.")

    state_dir = Path(args.state_dir).expanduser()
    done_path = state_dir / ".gerrit-cherry-pick.done"
    pending_path = state_dir / ".gerrit-cherry-pick.pending"

    resume_pending(done_path, pending_path)

    if is_cherry_pick_in_progress():
        fail("A cherry-pick is already in progress. Resolve/abort it first.")

    ensure_clean()

    remote_url = f"ssh://{args.user}@{args.host}:{args.port}/{args.project}"
    done = load_done(done_path)

    for idx, cid in enumerate(change_ids, start=1):
        print(f"\n=== [{idx}/{len(change_ids)}] {cid} ===")

        if cid in done:
            print("Already done according to state file; skipping.")
            continue

        if log_has_fixed_string(f"Change-Id: {cid}"):
            print("Change-Id already appears in current branch history; marking done.")
            mark_done(done_path, cid)
            continue

        meta = query_gerrit(args, cid)
        print(
            f"Resolved to Gerrit change {meta['number']} "
            f"branch={meta['branch']} status={meta['status']} ref={meta['ref']}"
        )

        if log_has_fixed_string(f"(cherry picked from commit {meta['revision']})"):
            print("Source commit already appears as cherry-picked in history; marking done.")
            mark_done(done_path, cid)
            continue

        git("fetch", remote_url, meta["ref"])

        pick_cmd = ["cherry-pick", "-x"]
        if args.signoff:
            pick_cmd.append("-s")
        pick_cmd.append("FETCH_HEAD")

        p = git(*pick_cmd, check=False)

        if p.returncode != 0:
            if is_cherry_pick_in_progress() and tracked_tree_clean():
                print("Cherry-pick became empty; skipping it and marking done.")
                git("cherry-pick", "--skip")
                mark_done(done_path, cid)
                continue

            pending_path.write_text(
                json.dumps(
                    {"change_id": cid, "revision": meta["revision"]},
                    indent=2,
                )
            )

            print(
                "\nCherry-pick stopped, probably due to conflicts.\n"
                "Resolve conflicts, then run:\n"
                "  git add <files>\n"
                "  git cherry-pick --continue\n\n"
                "Then rerun the same script command; it will continue from here.\n",
                file=sys.stderr,
            )
            sys.exit(p.returncode)

        verify_trailers(cid)
        mark_done(done_path, cid)

    print("\nAll requested Change-Ids processed.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {fmt(e.cmd)}", file=sys.stderr)
        if e.stdout:
            print(e.stdout, file=sys.stderr)
        if e.stderr:
            print(e.stderr, file=sys.stderr)
        sys.exit(e.returncode)
