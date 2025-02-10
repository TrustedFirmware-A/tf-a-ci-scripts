#!/usr/bin/env bash
#
# Copyright (c) 2019-2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e
set -x
export COVERAGE_ON=$((echo "$RUN_CONFIG" | grep -v 'aarch32' | grep -qE 'bmcov' && echo 1) ||
										(echo "${TEST_GROUP}" | grep -v 'aarch32' | grep -qE 'code-coverage' && echo 1) ||
										echo 0)
echo "COVERAGE_ON=${COVERAGE_ON}"

if [ $COVERAGE_ON -eq 1 ]; then
	# Load code coverage binary
	echo "Code coverage for binaries enabled..."
	export OUTDIR=${WORKSPACE}/html
	mkdir -p $OUTDIR
	source "$CI_ROOT/script/qa-code-coverage.sh"
fi


if [ $COVERAGE_ON -eq 1 ]; then
	LIST_OF_BINARIES=""
	OBJDUMP="$(which 'aarch64-none-elf-objdump')"
	READELF="$(which 'aarch64-none-elf-readelf')"
	FALLBACK_PLUGIN_URL="${FALLBACK_PLUGIN_URL:-${DOWNLOAD_SERVER_URL}/coverage-plugin/qa-tools/coverage-tool}"
	FALLBACK_PLUGIN_URL_ALT="${FALLBACK_PLUGIN_URL_ALT:-https://artifactory.eu02.arm.com/artifactory/trustedfirmware.downloads/coverage-plugin}"
	FALLBACK_FILES="${FALLBACK_FILES:-coverage_trace.so,coverage_trace.o,plugin_utils.o}"
	FALLBACK_FILES_ALT="${FALLBACK_FILES_ALT:-CoverageTrace.so,CoverageTrace.o,PluginUtils.o}"

	if [[ "$TEST_GROUP" == scp* ]]; then
		PROJECT="SCP"
		LIST_OF_BINARIES="scp_ram.elf scp_rom.elf mcp_rom.elf mcp_ram.elf"
		OBJDUMP="$(which 'arm-none-eabi-objdump')"
		READELF="$(which 'arm-none-eabi-readelf')"
		FALLBACK_PLUGIN_URL="${FALLBACK_PLUGIN_URL_ALT}"
		FALLBACK_FILES="${FALLBACK_FILES_ALT}"
	elif [[ "$TEST_GROUP" == spm* ]];then
			PROJECT="HAFNIUM"
			LIST_OF_BINARIES="secure_hafnium.elf hafnium.elf"
	elif [[ "$TEST_GROUP" == tf* ]];then
		PROJECT="TF-A"
		LIST_OF_BINARIES="bl1.elf bl2.elf bl31.elf"
		FALLBACK_PLUGIN_URL="${FALLBACK_PLUGIN_URL_ALT}"
		FALLBACK_FILES="${FALLBACK_FILES_ALT}"
	else
		echo "No project assigned for $TEST_GROUP ..."
		exit -1
	fi
	# Plugin has to be built before running model
	build_tool
fi

"$CI_ROOT/script/build_package.sh"
if [ "$skip_runs" ]; then
	exit 0
fi

# Execute test locally for FVP configs
if [ "$RUN_CONFIG" != "nil" ] && echo "$RUN_CONFIG" | grep -iq '^fvp'; then
	export BIN_MODE=debug
	"$CI_ROOT/script/run_package.sh"

	if [ $COVERAGE_ON -eq 1 ]; then
		sync
		sleep 5 # wait for trace files to be written
		ELF_FOLDER=$artefacts/$BIN_MODE
		TRACE_FOLDER=$artefacts/$BIN_MODE
		echo "Toolchain:$OBJDUMP"
		create_intermediate_layer "${TRACE_FOLDER}" "${ELF_FOLDER}" "${LIST_OF_BINARIES}"
		create_coverage_report
	fi
fi
