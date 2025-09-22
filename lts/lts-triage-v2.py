#!/usr/bin/env python3
#
# Copyright (c) 2022 Google LLC. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# quick hacky script to check patches if they are candidates for lts. it checks
# only the non-merge commits.

import os
import git
import re
import sys
import csv
import argparse
import json
import subprocess
from datetime import datetime
from io import StringIO
from unidiff import PatchSet
from config import MESSAGE_TOKENS, CPU_PATH_TOKEN, CPU_ERRATA_TOKEN, DOC_PATH_TOKEN, DOC_ERRATA_TOKEN

global_debug = False
def debug_print(*args, **kwargs):
    global global_var
    if global_debug:
        print(*args, **kwargs)

def contains_re(pf, tok):
    for hnk in pf:
        for ln in hnk:
            if ln.is_context:
                continue
            # here means the line is either added or removed
            txt = ln.value.strip()
            if tok.search(txt) is not None:
                return True

    return False

def process_ps(ps):
    score = 0

    cpu_tok = re.compile(CPU_PATH_TOKEN)
    doc_tok = re.compile(DOC_PATH_TOKEN)

    for pf in ps:
        if pf.is_binary_file or not pf.is_modified_file:
            continue
        if cpu_tok.search(pf.path) is not None:
            debug_print("* change found in cpu path:", pf.path);
            cpu_tok = re.compile(CPU_ERRATA_TOKEN)
            if contains_re(pf, cpu_tok):
                score = score + 1
                debug_print("    found", CPU_ERRATA_TOKEN)

        if doc_tok.search(pf.path) is not None:
            debug_print("* change found in macros doc path:", pf.path);
            doc_tok = re.compile(DOC_ERRATA_TOKEN)
            if contains_re(pf, doc_tok):
                score = score + 1
                debug_print("    found", DOC_ERRATA_TOKEN)

    return score

def query_gerrit(gerrit_user, ssh_key_path, change_id):
    ssh_command = [
        "ssh",
        "-o", "UserKnownHostsFile=/dev/null",
        "-o", "StrictHostKeyChecking=no",
        "-o", "PubkeyAcceptedKeyTypes=+ssh-rsa",
        "-p", "29418",
        "-i", ssh_key_path,
        f"{gerrit_user}@review.trustedfirmware.org",
        f"gerrit query --format=JSON change:'{change_id}'",
        "repo:'TF-A/trusted-firmware-a'"
    ]

    try:
        result = subprocess.run(ssh_command, capture_output=True, text=True, check=True)
        output = result.stdout.strip().split("\n")
        changes = [json.loads(line) for line in output if line.strip()]
        # Create a dictionary with branch as key and URL as value
        branches_urls = {change["branch"]: change["url"] for change in changes if "branch" in change and "url" in change}
        return branches_urls

    except subprocess.CalledProcessError as e:
        print("Error executing SSH command:", e)
        return {}

# REBASE_DEPTH is number of commits from tip of the LTS branch that we need
# to check to find the commit that the current patch set is based on
REBASE_DEPTH = 20


## TODO: for case like 921081049ec3 where we need to refactor first for security
#       patch to be applied then we should:
#       1. find the security patch
#       2. from that patch find CVE number if any
#       3. look for all patches that contain that CVE number in commit message

## TODO: similar to errata macros and rst file additions, we have CVE macros and rst file
#       additions. so we can use similar logic for that.

## TODO: for security we should look for CVE numbed regex match and if found flag it
def main():
    at_least_one_match = False
    parser = argparse.ArgumentParser(prog="lts-triage.py", description="check patches for LTS candidacy")
    parser.add_argument("--repo", required=True, help="path to tf-a git repo")
    parser.add_argument("--csv_path", required=True, help="path including the filename for CSV file")
    parser.add_argument("--lts", required=True, help="LTS branch, ex. lts-v2.8")
    parser.add_argument("--gerrit_user", required=True, help="The user id to perform the Gerrit query")
    parser.add_argument("--ssh_keyfile", required=True, help="The SSH keyfile")
    parser.add_argument("--debug", help="print debug logs", action="store_true")

    args = parser.parse_args()
    lts_branch = args.lts
    gerrit_user = args.gerrit_user
    ssh_keyfile = args.ssh_keyfile
    global global_debug
    global_debug = args.debug

    csv_columns = ["index", "commit id in the integration branch", "committer date", "commit summary",
                   "score", "Gerrit Change-Id", "patch link for the LTS branch",
                   "patch link for the integration branch", "To be cherry-picked"]
    csv_data = []

    repo = git.Repo(args.repo)

    # collect the LTS hashes in a list
    lts_change_ids = set()  # Set to store Gerrit Change-Ids from the LTS branch

    for cmt in repo.iter_commits(lts_branch):
        # Extract Gerrit Change-Id from the commit message
        change_id_match = re.search(r'Change-Id:\s*(\w+)', cmt.message)
        if change_id_match:
            lts_change_ids.add(change_id_match.group(1))

        if len(lts_change_ids) >= REBASE_DEPTH:
            break

    for cmt in repo.iter_commits('integration'):
        score = 0

        # if we find a same Change-Id among the ones we collected from the LTS branch
        # then we have seen all the new patches in the integration branch, so we should exit.
        change_id_match = re.search(r'Change-Id:\s*(\w+)', cmt.message)
        if change_id_match:
            change_id = change_id_match.group(1)
            if change_id in lts_change_ids:
                print("## stopping because found common Gerrit Change-Id between the two branches: ", change_id)
                break;

        # don't process merge commits
        if len(cmt.parents) > 1:
            continue

        tok = re.compile(MESSAGE_TOKENS, re.IGNORECASE)
        if tok.search(cmt.message) is not None:
            debug_print("## commit message match")
            score = score + 1

        diff_text = repo.git.diff(cmt.hexsha + "~1", cmt.hexsha, ignore_blank_lines=True, ignore_space_at_eol=True)
        ps = PatchSet(StringIO(diff_text))
        debug_print("# score before process_ps:", score)
        score = score + process_ps(ps)
        debug_print("# score after process_ps:", score)

        ln = f"{cmt.summary}:    {score}"
        print(ln)

        if score > 0:
            gerrit_links = query_gerrit(gerrit_user, ssh_keyfile, change_id)
            # Append data to CSV
            csv_data.append({
                "commit id in the integration branch": cmt.hexsha,
                "committer date": cmt.committed_date,
                "commit summary": cmt.summary,
                "score": score,
                "Gerrit Change-Id": change_id,
                "patch link for the LTS branch": gerrit_links.get(lts_branch, "N/A"),
                "patch link for the integration branch": gerrit_links.get("integration", "N/A"),
                "To be cherry-picked": "N" if gerrit_links.get(lts_branch) else "Y"
            })
            at_least_one_match = True

    if at_least_one_match == True:
        try:
            # Sort by committer date first (from oldest to newest)
            csv_data.sort(key=lambda row: int(row["committer date"]))

            idx = 1
            with open(args.csv_path, "w", newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=csv_columns)
                writer.writeheader()
                for data in csv_data:
                    # Convert timestamp to human-readable date before writing
                    ts = int(data["committer date"])
                    data["index"] = idx
                    data["committer date"] = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
                    writer.writerow(data)
                    idx += 1
        except:
            print("\n\nERROR: Couldn't open CSV file due to error: ", sys.exc_info()[0])

if __name__ == '__main__':
    main()
