#!/usr/bin/env python3
import argparse
import sys
import os
import re
import subprocess


WORKDIR = "trusted-firmware-a"

SKIP_PATTERNS = [
    r"docs\(changelog\): ",
    r"Merge changes from topic ",
    r"Merge \".+\" into ",
    r"Merge changes .+ into ",
]


def run(cmd):
    return subprocess.check_call(cmd, shell=True)


def maybe_int(s):
    if s.isdigit():
        return int(s)
    return s


def main():
    argp = argparse.ArgumentParser(description="Prepare TF-A LTS release email content")
    argp.add_argument("--latest", action="store_true", help="use latest release tag")
    argp.add_argument("release_tag", nargs="?", help="release tag")
    args = argp.parse_args()
    if not args.release_tag and not args.latest:
        argp.error("Either release_tag or --latest is required")

    with open(os.path.dirname(__file__) + "/lts-release-mail.txt") as f:
        mail_template = f.read()

    if not os.path.exists(WORKDIR):
        run("git clone https://review.trustedfirmware.org/TF-A/trusted-firmware-a %s" % WORKDIR)
        os.chdir(WORKDIR)
    else:
        os.chdir(WORKDIR)
        run("git pull --quiet")

    if args.latest:
        latest = []
        for l in os.popen("git tag"):
            if not re.match(r"lts-v\d+\.\d+\.\d+", l):
                continue
            l = l.rstrip()
            comps = [maybe_int(x) for x in l.split(".")]
            comps.append(l)
            if comps > latest:
                latest = comps
        if not latest:
            argp.error("Could not find latest LTS tag")
        args.release_tag = latest[-1]

    comps = args.release_tag.split(".")
    prev_comps = comps[:-1] + [str(int(comps[-1]) - 1)]
    prev_release = ".".join(prev_comps)

    subjects = []
    for l in os.popen("git log --oneline --reverse %s..%s" % (prev_release, args.release_tag)):
        skip = False
        for pat in SKIP_PATTERNS:
            if re.match(pat, l.split(" ", 1)[1]):
                skip = True
        if not skip:
            subjects.append(l.rstrip())

    urls = []
    for s in subjects:
        commit_id, _ = s.split(" ", 1)
        for l in os.popen("git show %s" % commit_id):
            if "Change-Id:" in l:
                _, change_id = l.strip().split(None, 1)
                urls.append("https://review.trustedfirmware.org/q/" + change_id)

    assert len(subjects) == len(urls)

    commits = ""
    for i, s in enumerate(subjects, 1):
        commits += "%s [%d]\n" % (s, i)

    references = ""
    for i, s in enumerate(urls, 1):
        references += "[%d] %s\n" % (i, s)

    # Strip trailing newline, as it's encoded in template.
    commits = commits.rstrip()
    references = references.rstrip()

    version = args.release_tag[len("lts-v"):]
    sys.stdout.write(
        mail_template.format(
            version=version,
            commits=commits,
            references=references,
        )
    )


if __name__ == "__main__":
    main()
