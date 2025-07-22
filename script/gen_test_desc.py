#!/usr/bin/env python3
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
#
# Generate .test files in $workspace based on the $TEST_GROUPS parameter. Test
# files are prefixed with a zero-padded number for a predictable ordering
# amongst them.

import os

TEST_SUFFIX = ".test"


def touch(a_file):
    with open(a_file, "w"):
        pass


# Obtain the value of either $variable or $VARIABLE.
def get_env(variable):
    var_list = [variable, variable.upper()]
    for v in var_list:
        value = os.environ.get(v)
        if value:
            return value
    else:
        raise Exception("couldn't find {} in env".format(" or ".join(var_list)))


# Perform group-specific translation on the build config
def translate_build_config(group, config_list):
    # config_list contains build configs as read from the test config
    if group.startswith("scp-"):
        # SCP configs would be specified in the following format:
        #  scp_config, tf_config, tftf_config, scp_tools
        # Reshuffle them into the canonical format
        config_list = [config_list[1], config_list[2], config_list[0], config_list[3]]

    if group.startswith("spm-"):
        # SPM configs would be specified in the following format:
        #  spm_config, tf_config, tftf_config, scp_config, scp_tools
        # Reshuffle them into the canonical format
        config_list = [config_list[1], config_list[2], config_list[3], config_list[4], config_list[0]]

    if group.startswith("rmm-"):
        # RMM configs would be specified in the following format:
        #  rmm_config, tf_config, tftf_config, spm_config, scp_config, scp_tools
        # Reshuffle them into the canonical format
        config_list = [config_list[1], config_list[2], config_list[4], config_list[5], config_list[3], config_list[0]]

    if group.startswith("rfa-"):
        # RF-A configs would be specified in the following format:
        #  rfa_config, rmm_config, tf_config
        # Reshuffle them into the canonical format
        config_list = [config_list[2], config_list[3], config_list[5], config_list[6], config_list[4], config_list[1], config_list[0]]

    if group.startswith("tf-l3-code-coverage"):
        # coverage configs would be specified in the following format:
        #  tf_config, tftf_config, spm_config, scp_config, scp_tools
        # Reshuffle them into the canonical format
        config_list = [config_list[0], config_list[1], config_list[3], config_list[4], config_list[2]]

    return config_list


def gen_desc(group, test):
    global num_spawn

    build_config, run_config = test.split(":")

    # Test descriptors are always generated in the following order:
    #  tf_config, tftf_config, scp_config, scp_tools, spm_config, rmm_config, rfa_config
    # Fill missing configs to the right with "nil".
    config_list = (build_config.split(",") + ["nil"] * 7)[:7]

    # Perform any group-specific translation on the config
    config_list = translate_build_config(group, config_list)

    test_config = ",".join(config_list) + ":" + run_config

    # Create descriptor. Write the name of the original test config as its
    # content.
    desc_base = "%".join([str(num_spawn).zfill(4), os.path.basename(group),
        test_config + TEST_SUFFIX])
    desc = os.path.join(workspace, desc_base)
    with open(desc, "wt") as fd:
        print(test, file=fd)
    # Create .testprop file for smoother integration with Jenkins
    # (allows to pass test config as a normal string param instead
    # of binary file which takes extra clicks to view).
    with open(desc + "prop", "wt") as fd:
        print("TEST_CONFIG={}".format(test), file=fd)
        print("TEST_DESC={}".format(desc_base), file=fd)

    num_spawn += 1


def process_item(item):
    # If an item starts with @, then it's deemed to be an indirection--a file
    # from which test groups are to be read.
    if item.startswith("@"):
        with open(item[1:]) as fd:
            for line in fd:
                line = line.strip()
                if not line:
                    continue
                process_item(line)

        return

    item_loc = os.path.join(group_dir, item)

    if os.path.isfile(item_loc):
        gen_desc(*item_loc.split(os.sep)[-2:])
    elif os.path.isdir(item_loc):
        # If it's a directory, select all files inside it
        for a_file in next(os.walk(item_loc))[2]:
            if a_file.endswith(".inactive"):
                continue
            gen_desc(item, a_file)
    else:
        # The item doesn't exist
        if ":" in item:
            # A non-existent test config is specified
            if "/" in item:
                # The test config doesn't exist, and a group is also specified.
                # This is not allowed.
                raise Exception("'{}' doesn't exist.".format(item))
            else:
                # The user probably intended to create one on the fly; so create
                # one in the superficial 'GENERATED' group.
                print("note: '{}' doesn't exist; generated.".format(item))
                touch(os.path.join(generated_dir, item))
                gen_desc(os.path.basename(generated_dir), item)
        else:
            raise Exception("'{}' is not valid for test generation!".format(item))


ci_root = os.path.abspath(os.path.join(__file__, os.pardir, os.pardir))
group_dir = os.path.join(ci_root, "group")
num_spawn = 0

# Obtain variables from environment
test_groups = get_env("test_groups")
workspace = get_env("workspace")

# Remove all test files, if any
_, _, files = next(os.walk(workspace))
for test_file in files:
    if test_file.endswith(TEST_SUFFIX):
        os.remove(os.path.join(workspace, test_file))

generated_dir = os.path.join(group_dir, "GENERATED")
os.makedirs(generated_dir, exist_ok=True)

for item in test_groups.split():
    process_item(item)

print()
print("{} test configurations to be built...".format(num_spawn))
print()
