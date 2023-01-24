#!/usr/bin/env python3
#
# Copyright (c) 2022 Google LLC. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# quick hacky script to check patches if they are candidates for lts. it checks
# only the non-merge commits.

import pkg_resources
import os
import git
import re
import argparse
from io import StringIO
pkg_resources.require("unidiff>=0.7.4")
from unidiff import PatchSet

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

SUBJECT_TOKENS = r'fix\(cpus\)|revert\(cpus\)|fix\(errata\)|\(security\)'
CPU_PATH_TOKEN = r'lib/cpus/aarch(32|64)/.*\.S'
CPU_ERRATA_TOKEN = r'^report_errata ERRATA_'
DOC_PATH_TOKEN = r'docs/design/cpu-specific-build-macros.rst'
DOC_ERRATA_TOKEN = r'^^-\s*``ERRATA_'
# REBASE_DEPTH is number of commits from tip of integration branch that we need
# to check to find the commit that the current patch set is based on
REBASE_DEPTH = 50
# MAX_PATCHSET_DEPTH is the maximum number of patches that we expect in the current
# patch set. for each commit in the patch set we will look at past REBASE_DEPTH commits
# of integration branch. if there is a match we'd know the current patch set was based
# off of that matching commit. This is not necessarily the optimal method but I'm not
# familiar with gerrit API. If there is a way to do this better we should implement that.
MAX_PATCHSET_DEPTH = 50
CHECK_AGAINST = 'integration'
TO_CHECK = 'to_check'


## TODO: for case like 921081049ec3 where we need to refactor first for security
#       patch to be applied then we should:
#       1. find the security patch
#       2. from that patch find CVE number if any
#       3. look for all patches that contain that CVE number in commit message

## TODO: similar to errata macros and rst file additions, we have CVE macros and rst file
#       additions. so we can use similar logic for that.

## TODO: for security we should look for CVE numbed regex match and if found flag it
def main():
    parser = argparse.ArgumentParser(prog="lts-triage.py", description="check patches for LTS candidacy")
    parser.add_argument("--repo", required=True, help="path to tf-a git repo")
    parser.add_argument("--debug", help="print debug logs", action="store_true")

    args = parser.parse_args()
    global global_debug
    global_debug = args.debug

    repo = git.Repo(args.repo)

    # collect the integration hashes in a list
    rebase_hashes = []
    for cmt in repo.iter_commits(CHECK_AGAINST):
        rebase_hashes.append(cmt.hexsha)
        if len(rebase_hashes) == REBASE_DEPTH:
            break

    cnt = MAX_PATCHSET_DEPTH
    for cmt in repo.iter_commits(TO_CHECK):
        score = 0

        # if we find a same commit hash among the ones we collected from integration branch
        # then we have seen all the new patches in this patch set, so we should exit.
        if cmt.hexsha in rebase_hashes:
            debug_print("## stopping because found sha1 common between the two branches: ", cmt.hexsha)
            break;

        # don't process merge commits
        if len(cmt.parents) > 1:
            continue

        tok = re.compile(SUBJECT_TOKENS)
        if tok.search(cmt.summary) is not None:
            debug_print("## subject match")
            score = score + 1

        diff_text = repo.git.diff(cmt.hexsha + "~1", cmt.hexsha, ignore_blank_lines=True, ignore_space_at_eol=True)
        ps = PatchSet(StringIO(diff_text))
        debug_print("# score before process_ps:", score)
        score = score + process_ps(ps)
        debug_print("# score after process_ps:", score)

        print("{}:    {}".format(cmt.hexsha, score))

        cnt = cnt - 1
        if cnt == 0:
            break

if __name__ == '__main__':
    main()
