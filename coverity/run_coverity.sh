#!/usr/bin/env bash
#
# Copyright (c) 2019-2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Run Coverity on a source tree.
# Then produce a tarball ready to be submitted to Coverity Scan Online.
#
# The following arguments must be passed to this script:
# 1. The command to use to build the software (this can be a script).
# 2. The name of the tarball to produce.
#
# Assumptions:
# The following tools are loaded in the PATH:
#  - the Coverity tools (cov-configure, cov-build, and so on);
#  - the AArch64 cross-toolchain;
#  - the AArch32 cross-toolchain.

# Bail out as soon as an error is encountered
set -e


function do_check_tools()
{
    echo
    echo "Checking all required tools are available..."
    echo

    # Print version of the Coverity tools.
    # This also serves as a check that the tools are available.
    cov-configure --ident
    cov-build --ident

    # Check that the AArch64 cross-toolchain is available.
    aarch64-none-elf-gcc --version

    # Check that the AArch32 cross-toolchain is available.
    arm-none-eabi-gcc --version

    echo
    echo "Checks complete."
    echo
}


function do_configure()
{
    # Create Coverity's configuration directory and its intermediate directory.
    rm -rf cov-config cov-int
    mkdir cov-config cov-int

    # Generate Coverity's configuration files.
    #
    # This needs to be done for each compiler.
    # Each invocation of the cov-configure command adds a compiler configuration in
    # its own subdirectory, and the top XML configuration file contains an include
    # directive for that compiler-specific configuration.
    #   1) AArch64 compiler
    cov-configure				\
	--comptype gcc				\
	--template				\
	--compiler aarch64-none-elf-gcc	\
	--config cov-config/config.xml
    #   2) AArch32 compiler
    cov-configure				\
	--comptype gcc				\
	--template				\
	--compiler arm-none-eabi-gcc			\
	--config cov-config/config.xml
}


function do_build()
{
    local build_cmd=("$*")

    echo
    echo "* The software will be built using the following command line:"
    echo "$build_cmd"
    echo

    # Build the instrumented binaries.
    cov-build				\
	--config cov-config/config.xml	\
	--dir cov-int			\
	$build_cmd

    echo
    echo "Build complete."
    echo
}


function create_results_tarball()
{
    local tarball_name="$1"

    echo
    echo "Creating the tarball containing the results of the analysis..."
    echo
    tar -czvf "$tarball_name" cov-int/
    echo
    echo "Complete."
    echo
}


###############################################################################
PHASE="$1"
echo "Coverity: phase '$PHASE'"
shift

case $PHASE in
    check_tools)
	do_check_tools
    ;;

    configure)
	do_configure
    ;;

    build)
	do_build "$1"
    ;;

    package)
	OUTPUT_FILE="$1"
	create_results_tarball "$OUTPUT_FILE"
	;;

    *)
	echo "Invalid phase '$PHASE'"
esac
