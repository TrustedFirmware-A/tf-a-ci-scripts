#!/usr/bin/env python3
import argparse
import sys
import os
import re
import subprocess


DEFAULT_URL = f"https://review.trustedfirmware.org/{os.environ.get('GERRIT_PROJECT_PREFIX', '')}TF-A/trusted-firmware-a"
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


def is_sandbox_run():
    return os.environ.get("SANDBOX_RUN") != "false"


def main():
    argp = argparse.ArgumentParser(description="Prepare TF-A LTS release email content")
    argp.add_argument("-u", "--url", default=DEFAULT_URL, help="repository URL (default: %(default)s)")
    argp.add_argument("-b", "--branch", default="", help="repository branch for --latest option")
    argp.add_argument("--latest", action="store_true", help="use latest release tag on --branch")
    argp.add_argument("release_tag", nargs="?", help="release tag")
    args = argp.parse_args()
    if not args.release_tag and not args.latest:
        argp.error("Either release_tag or --latest is required")

    with open(os.path.dirname(__file__) + "/lts-release-mail.txt") as f:
        mail_template = f.read()

    if not os.path.exists(WORKDIR):
        run("git clone %s %s" % (args.url, WORKDIR))
        os.chdir(WORKDIR)
    else:
        os.chdir(WORKDIR)
        run("git pull --quiet")

    if args.latest:
        latest = []
        for l in os.popen("git tag"):
            if not re.match(r"lts-v\d+\.\d+\.\d+", l):
                continue
            if not l.startswith(args.branch):
                continue
            l = l.rstrip()
            comps = [maybe_int(x) for x in l.split(".")]
            comps.append(l)
            if comps > latest:
                latest = comps
        if not latest:
            argp.error("Could not find latest LTS tag")
        args.release_tag = latest[-1]

    base_release = args.release_tag
    # If it's "sandbox" tag, convert it to the corresponding release tag for
    # rendering the template.
    if base_release.startswith("sandbox/"):
        m = re.match(r"sandbox/(.+)-\d+", base_release)
        base_release = m.group(1)

    match = re.match(r"(lts-v\d+\.\d+)\.(\d+)", base_release)
    if not match:
        sys.stderr.write(f"Error: Invalid tag format {base_release}\n")
        sys.exit(1)

    branch_prefix = match.group(1)
    patch_version = int(match.group(2))

    if patch_version == 0:
        sys.stderr.write(f"First release of the branch {base_release}. Skipping email.\n")
        return

    prev_release = f"{branch_prefix}.{patch_version - 1}"

    if subprocess.call(f"git rev-parse --verify {prev_release}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) != 0:
        sys.stderr.write(f"Error: Previous release tag {prev_release} not found in repository\n")
        sys.exit(1)

    subjects = []
    for l in os.popen("git log --oneline --reverse %s..%s" % (prev_release, args.release_tag)):
        skip = False
        for pat in SKIP_PATTERNS:
            if re.match(pat, l.split(" ", 1)[1]):
                skip = True
        if not skip:
            subjects.append(l.rstrip())

    if not subjects:
        sys.stderr.write("No changes found, skipping email generation\n")
        return

    urls = []
    for s in subjects:
        commit_id, _ = s.split(" ", 1)
        change_id = None
        for l in os.popen("git show %s" % commit_id):
            # There can be multiple Change-Id lines in some commits, and
            # we're interested in the last in that case.
            if "Change-Id:" in l:
                _, change_id = l.strip().split(None, 1)
        if change_id:
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

    if is_sandbox_run():
        rtd_url = "https://trustedfirmware-a-sandbox.readthedocs.io/en/"
    else:
        rtd_url = "https://trustedfirmware-a.readthedocs.io/en/"
    rtd_slug = args.release_tag.lower().replace("/", "-")
    rtd_url += rtd_slug

    version = base_release[len("lts-v"):]
    sys.stdout.write(
        mail_template.format(
            version=version,
            commits=commits,
            references=references,
            rtd_url=rtd_url,
        )
    )


if __name__ == "__main__":
    main()
