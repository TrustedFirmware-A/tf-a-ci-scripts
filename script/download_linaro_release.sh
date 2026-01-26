#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Given the name of the release (e.g., 18.04), this script downloads all
# Linaro release archives to the current directory, verifies, extracts, and
# finally removes the archive files.

set -e

# Download all ZIP files from the chosen Linaro release
base="https://downloads.trustedfirmware.org/infra-assets/linaro_artifacts/releases/${1:?}"

wget -q "$base/MD5SUMS"

for file in $(awk '{print $2}' < MD5SUMS); do
  wget "$base/$file"
done

# Check files didn't get corrupted in the transfer
md5sum -c MD5SUMS

# Uncompress each ZIP file in its own directory (named after the ZIP file)
for zipfile in $(echo *.zip); do
	echo
	echo "Uncompressing file $zipfile"

	directory_name="${zipfile%.zip}"
	mkdir "$directory_name"

	cd "$directory_name"
	unzip "../$zipfile"
	cd -
done

rm -rf *.zip *.xz *.gz
