#!/usr/bin/env python3
#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Run the Coverity tool on the Trusted Firmware and produce a tarball ready to
# be submitted to Coverity Scan Online.
#

import sys
import argparse
import urllib.request
import tarfile
import os
import subprocess
import re
import utils
import coverity_tf_conf


def tarball_name(filename):
    "Isolate the tarball name without the filename's extension."
    # Handle a selection of "composite" extensions
    for ext in [".tar.gz", ".tar.bz2"]:
        if filename.endswith(ext):
            return filename[:-len(ext)]
    # For all other extensions, let the vanilla splitext() function handle it
    return os.path.splitext(filename)[0]

assert tarball_name("foo.gz") == "foo"
assert tarball_name("bar.tar.gz") == "bar"
assert tarball_name("baz.tar.bz2") == "baz"


def get_coverity_tool():
    coverity_tarball = "coverity_tool.tgz"
    url = "${DOWNLOAD_SERVER_URL}/tf-a/tf-a-coverity/" + coverity_tarball
    print("Downloading Coverity Build tool from %s..." % url)
    file_handle = urllib.request.urlopen(url)
    output = open(coverity_tarball, "wb")
    output.write(file_handle.read())
    output.close()
    print("Download complete.")

    print("\nUnpacking tarball %s..." % coverity_tarball)
    tarfile.open(coverity_tarball).extractall()
    print("Tarball unpacked.")

    print("\nNow please load the Coverity tool in your PATH...")
    print("E.g.:")
    cov_version = "2023.6.2"
    cov_dir_name = "cov-analysis-linux64-" + cov_version
    cov_dir_path = os.path.abspath(os.path.join(cov_dir_name, "bin"))
    print("  export PATH=%s$PATH" % (cov_dir_path + os.pathsep))

def print_coverage(coverity_dir, tf_dir, exclude_paths=[], log_filename=None):
    analyzed = []
    not_analyzed = []
    excluded = []

    # Print the coverage report to a file (or stdout if no file is specified)
    if log_filename is not None:
        log_file = open(log_filename, "w")
    else:
        log_file = sys.stdout

    # Get the list of files analyzed by Coverity.
    #
    # To do that, we examine the build log file Coverity generated and look for
    # compilation lines. These are the lines starting with "COMPILING:" or
    # "EXECUTING:". We consider only those lines that actually compile C files,
    # i.e. lines of the form:
    #   gcc -c file.c -o file.o
    # This filters out other compilation lines like generation of dependency files
    # (*.d) and such.
    # We then extract the C filename.
    coverity_build_log = os.path.join(coverity_dir, "build-log.txt")
    with open(coverity_build_log, encoding="utf-8") as build_log:
        for line in build_log:
            line = re.sub('//','/', line)
            results = re.search("(?:COMPILING|EXECUTING):.*-c  *(.*\.c).*-o.*\.o", line)
            if results is not None:
                filename = results.group(1)
                if filename not in analyzed:
                    analyzed.append(filename)

    # Now get the list of C files in the Trusted Firmware source tree.
    # Header files and assembly files are ignored, as well as anything that
    # matches the patterns list in the exclude_paths[] list.
    # Build a list of files that are in this source tree but were not analyzed
    # by comparing the 2 sets of files.
    all_files_count = 0
    old_cwd = os.path.abspath(os.curdir)
    os.chdir(tf_dir)
    git_process = utils.exec_prog("git", ["ls-files", "*.c"],
                                  out=subprocess.PIPE, out_text_mode=True)
    for filename in git_process.stdout:
        # Remove final \n in filename
        filename = filename.strip()

        def is_excluded(filename, excludes):
            for pattern in excludes:
                if re.match(pattern[0], filename):
                    excluded.append((filename, pattern[1]))
                    return True
            return False

        if is_excluded(filename, exclude_paths):
            continue

        # Keep track of the number of C files in the source tree. Used to
        # compute the coverage percentage at the end.
        all_files_count += 1
        if filename not in analyzed:
            not_analyzed.append(filename)
    os.chdir(old_cwd)

    # Compute the coverage percentage
    # Note: The 1.0 factor here is used to make a float division instead of an
    # integer one.
    percentage = (1 - ((1.0 * len(not_analyzed) ) / all_files_count)) * 100

    #
    # Print a report
    #
    log_file.write("Files coverage: %d%%\n\n" % percentage)
    log_file.write("Analyzed %d files\n" % len(analyzed))

    if len(excluded) > 0:
        log_file.write("\n%d files were ignored on purpose:\n" % len(excluded))
        for exc in excluded:
            log_file.write(" - {0:50}   (Reason: {1})\n".format(exc[0], exc[1]))

    if len(not_analyzed) > 0:
        log_file.write("\n%d files were not analyzed:\n" % len(not_analyzed))
        for f in not_analyzed:
            log_file.write(" - %s\n" % f)
        log_file.write("""
===============================================================================
Please investigate why the above files are not run through Coverity.

There are 2 possible reasons:

1) The build coverage is insufficient. Please review the tf-cov-make script to
   add the missing build config(s) that will involve the file in the build.

2) The file is expected to be ignored, for example because it is deprecated
   code. Please update the TF Coverity configuration to list the file and
   indicate the reason why it is safe to ignore it.
===============================================================================
""")
    log_file.close()


def parse_cmd_line(argv, prog_name):
    parser = argparse.ArgumentParser(
        prog=prog_name,
        description="Run Coverity on Trusted Firmware",
        epilog="""
        Please ensure the AArch64 & AArch32 cross-toolchains are loaded in your
        PATH. Ditto for the Coverity tools. If you don't have the latter then
        you can use the --get-coverity-tool to download them for you.
        """)
    parser.add_argument("--tf", default=None,
                        metavar="<Trusted Firmware source dir>",
                        help="Specify the location of ARM Trusted Firmware sources to analyze")
    parser.add_argument("--get-coverity-tool", default=False,
                        help="Download the Coverity build tool and exit",
                        action="store_true")
    parser.add_argument("--mode", choices=["offline", "online"], default="online",
                        help="Choose between online or offline mode for the analysis")
    parser.add_argument("--output", "-o",
                        help="Name of the output file containing the results of the analysis")
    parser.add_argument("--build-cmd", "-b",
                        help="Command used to build TF through Coverity")
    parser.add_argument("--analysis-profile", "-p",
                        action="append", nargs=1,
                        help="Analysis profile for a local analysis")
    args = parser.parse_args(argv)

    # Set a default name for the output file if none is provided.
    # If running in offline mode, this will be a text file;
    # If running in online mode, this will be a tarball name.
    if not args.output:
        if args.mode == "offline":
            args.output = "arm-tf-coverity-report.txt"
        else:
            args.output = "arm-tf-coverity-results.tgz"

    return args


if __name__ == "__main__":
    prog_name = sys.argv[0]
    args = parse_cmd_line(sys.argv[1:], prog_name)

    # If the user asked to download the Coverity build tool then just do that
    # and exit.
    if args.get_coverity_tool:
        # If running locally, use the commercial version of Coverity from the
        # EUHPC cluster.
        if args.mode == "offline":
            print("To load the Coverity tools, use the following command:")
            print("export PATH=/arm/tools/coverity/static-analysis/8.7.1/bin/:$PATH")
        else:
            get_coverity_tool()
        sys.exit(0)

    if args.tf is None:
        print("ERROR: Please specify the Trusted Firmware sources using the --tf option.",
              file=sys.stderr)
        sys.exit(1)

    # Get some important paths in the platform-ci scripts
    tf_scripts_dir = os.path.abspath(os.path.dirname(prog_name))
    tf_coverity_dir = os.path.join(os.path.normpath(
        os.path.join(tf_scripts_dir, os.pardir, os.pardir)),"coverity")

    if not args.build_cmd:
        tf_build_script = os.path.join(tf_scripts_dir, "tf-cov-make")
        args.build_cmd = tf_build_script + " " + args.tf

    run_coverity_script = os.path.join(tf_coverity_dir, "run_coverity.sh")

    ret = subprocess.call([run_coverity_script, "check_tools", args.mode])
    if ret != 0:
        sys.exit(1)

    ret = subprocess.call([run_coverity_script, "configure"])
    if ret != 0:
        sys.exit(1)

    ret = subprocess.call([run_coverity_script, "build", args.build_cmd])
    if ret != 0:
        sys.exit(1)

    if args.mode == "online":
        ret = subprocess.call([run_coverity_script, "package", args.output])
    else:
        for profile in args.analysis_profile:
            ret = subprocess.call([run_coverity_script, "analyze",
                                   args.output,
                                   args.tf,
                                   profile[0]])
            if ret != 0:
                    break
    if ret != 0:
        print("An error occured (%d)." % ret, file=sys.stderr)
        sys.exit(ret)

    print("-----------------------------------------------------------------")
    print("Results can be found in file '%s'" % args.output)
    if args.mode == "online":
        print("This tarball can be uploaded at Coverity Scan Online:" )
        print("https://scan.coverity.com/projects/arm-software-arm-trusted-firmware/builds/new?tab=upload")
    print("-----------------------------------------------------------------")

    # Temporary workaround to fix an issue with non utf-8 characters in the
    # directory path name
    #print_coverage("cov-int", args.tf, coverity_tf_conf.exclude_paths, "tf_coverage.log")
    #with open("tf_coverage.log") as log_file:
    #    for line in log_file:
    #        print(line, end="")
