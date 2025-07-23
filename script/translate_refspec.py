#!/usr/bin/env python3
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This scripts translates certain accepted refspec schemes to something that can
# be used on git command line. For example, given the refspec 'topic:foo/bar'
# for a given project, this script translates and prints the full commit hash.
#
# If a scheme is not recognized, print the received refspec unchanged.

import argparse
import gerrit
import sys

# Gerrit servers we care about.
gerrit_arm = gerrit.GerritServer("gerrit.oss.arm.com")
gerrit_tforg = gerrit.GerritServer("review.trustedfirmware.org")

# Trusted Firmware-A and associated projects.
# Different projects are hosted on different Gerrit servers.
projects = {
    # Projects hosted on Arm Gerrit server.
    "arm": {
        "trusted-firmware": gerrit.GerritProject("pdcs-platforms/ap/tf-topics", gerrit_arm),
        "trusted-firmware-tf": gerrit.GerritProject("trusted-firmware/tf-a-tests", gerrit_arm),
        "trusted-firmware-ci": gerrit.GerritProject("pdswinf/ci/pdcs-platforms/platform-ci", gerrit_arm),
	"cc_plugin": gerrit.GerritProject("tests/lava/test-definitions.git", gerrit_arm),
        "scp": gerrit.GerritProject("scp/firmware", gerrit_arm),
        "spm": gerrit.GerritProject("trusted-firmware/spm", gerrit_arm),
        "tf-rmm": gerrit.GerritProject("trusted-firmware/tf-rmm", gerrit_arm),
        "tf-m-tests": gerrit.GerritProject("iot-sw/tf-m/internal/tf-m-tests", gerrit_arm),
        "tf-m-extras": gerrit.GerritProject("iot-sw/tf-m/internal/tf-m-extras", gerrit_arm),
    },

    # Projects hosted on trustedfirmware.org Gerrit server.
    "tforg": {
        "trusted-firmware": gerrit.GerritProject("TF-A/trusted-firmware-a", gerrit_tforg),
        "rusted-firmware": gerrit.GerritProject("RF-A/rusted-firmware-a", gerrit_tforg),
        "trusted-firmware-tf": gerrit.GerritProject("TF-A/tf-a-tests", gerrit_tforg),
        "trusted-firmware-ci": gerrit.GerritProject("ci/tf-a-ci-scripts", gerrit_tforg),
        "spm": gerrit.GerritProject("hafnium/hafnium", gerrit_tforg),
        "tf-rmm": gerrit.GerritProject("TF-RMM/tf-rmm", gerrit_tforg),
        "tf-m-tests": gerrit.GerritProject("TF-M/tf-m-tests", gerrit_tforg),
        "tf-m-extras": gerrit.GerritProject("TF-M/tf-m-extras", gerrit_tforg),
    },
}

# Argument setup
parser = argparse.ArgumentParser()
parser.add_argument("--project", "-p",
                    help="Gerrit project identifier this refspec belongs to")
parser.add_argument("--server", "-s", help="Gerrit server hosting this project",
                    choices=["arm", "tforg"])
parser.add_argument("--user", "-u",
                    help="Username to use to query the Gerrit server")
parser.add_argument("--key", "-k",
                    help="SSH private key to use to authenticate with the Gerrit server")
parser.add_argument("refspec", help="Refspec to translate")
opts = parser.parse_args()

project = projects[opts.server][opts.project]

# Default action: print refspec and exit
def do_default():
    print(opts.refspec)
    sys.exit(0)

def print_topic_tip(query_results):
    patchsets = []
    parents = []

    # For each change, get its most recent patchset
    for change in query_results:
        patchsets.append(change["patchSets"][-1])

    # For each patchset, get its parent commit
    for patchset in patchsets:
        parents.append(patchset["parents"][0])

    # If a patchset's revision is NOT in the list of parents then it should
    # be the tip commit
    tips = list(filter(lambda x: x["revision"] not in parents, patchsets))

    # There must be only one patchset remaining, otherwise the tip is ambiguous
    if len(tips) > 1:
        raise Exception("{} in {} has no unique tip commit.".format(opts.refspec,
                                                                    opts.project))
    if len(tips) == 0:
        raise Exception("No tip commit found for {} in {}.".format(opts.refspec,
                                                                   opts.project))
    # Print the reference of the topic tip patchset
    print(tips[0]["ref"])

query = ["status:open"]

# If we don't understand the refspec, that's OK. We don't translate it, but
# print it as is.
try:
    scheme, rest = opts.refspec.split(":")
    if scheme == "topic":
        query += ["topic:" + rest]
    elif scheme == "change":
        query += [opts.refspec]
    else:
        do_default()
except:
    do_default()

changes = project.query(query, username=opts.user, keyfile=opts.key)

# The last object is a summary; drop it as it's not of interest to us.
changes.pop()

if not changes:
    raise Exception("{} for {} resolved to nothing.".format(opts.refspec,
                                                            opts.project))

if scheme == "topic":
    if len(changes) > 1:
       print_topic_tip(changes)
    else:
        print(changes[0]["currentPatchSet"]["ref"])
elif scheme == "change":
    if len(changes) > 1:
        # When querying for a specific change there must be just a single result
        raise Exception("{} for {} did not resolve uniquely.".format(opts.refspec,
                                                                     opts.project))
    print(changes[0]["currentPatchSet"]["revision"])
