#!/usr/bin/env -S python3 -u
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
import argparse
import datetime
import re
from subprocess import check_call, check_output


REMOTE = "ssh://%s@review.trustedfirmware.org:29418/TF-A/trusted-firmware-a"
# Remove references having timestamps older than so many days.
CUTOFF_DAYS = 30


def check_call_maybe_dry(args, cmd):
    if args.dry_run:
        print("Would run:", " ".join(cmd))
        return
    check_call(cmd)


def main():
    argp = argparse.ArgumentParser(description="Clean up old sandbox tags/branches in TF-A project")
    argp.add_argument("--user", help="user to connect to Gerrit")
    argp.add_argument("--limit", type=int, default=-1, help="limit deletions to this number")
    argp.add_argument("--dry-run", action="store_true", help="don't perform any changes")
    args = argp.parse_args()

    if not args.user:
        argp.error("--user parameter is required")
    global REMOTE
    REMOTE = REMOTE % args.user

    cutoff = (datetime.datetime.now() - datetime.timedelta(days=CUTOFF_DAYS)).strftime("%Y%m%d")

    print("Cutoff date:", cutoff)

    del_cnt = 0

    def process_ref_pattern(ref_pat):
        nonlocal del_cnt

        out = check_output(["git", "ls-remote", REMOTE, ref_pat], text=True)

        for line in out.rstrip().split("\n"):
            rev, tag = line.split(None, 1)
            m = re.match(r".+-(\d{8}T\d{4})", tag)
            delete = False
            if not m:
                print("Warning: Cannot parse timestamp from tag '%s', assuming stray ref and deleting" % tag)
                delete = True
            else:
                tstamp = m.group(1)
                delete = tstamp < cutoff

            if delete:
                check_call_maybe_dry(args, ["git", "push", REMOTE, ":" + tag])
                del_cnt += 1
                if del_cnt == args.limit:
                    break

    process_ref_pattern("refs/tags/sandbox/*")
    if del_cnt != args.limit:
        process_ref_pattern("refs/heads/sandbox/*")


if __name__ == "__main__":
    main()
