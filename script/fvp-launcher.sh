#!/usr/bin/env bash
#
# Copyright (c) 2021 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Given the name of the release (e.g., 18.04), this script downloads all
# Linaro release archives to the current directory, verifies, extracts, and
# finally removes the archive files.

# FVP launcher: Script that generates docker and baremetal commands based on LAVA
# log stored at [TF Open CI](http://ci.trustedfirmware.org/)
#
# Usage:
# Run the `fvp-launcher.sh` script, providing a https://ci.trustedfirmware.org/view/TF-A/job/tf-a-builder/
# job as parameter, for example
#
# $ ./fvp-launcher.sh https://ci.trustedfirmware.org/job/tf-a-builder/252606/
#
# executon will fetch all artefacts locally and finally generating the two commands: docker and baremetal commands,
# any can be run depending on the scenario.


# safe execution
set -ue

function r_curl(){
    local target="$1"
    local source="$2"
    curl --connect-timeout 5 --retry 5 --retry-delay 1 -fsSLo "$1" "$2"
}

declare -A saveas
declare -A urls

## Must params
JENKINS_PUBLIC_URL="${1:?}"


## Optional params passed through env variables
USE_LOCAL_IMAGE="${USE_LOCAL_IMAGE:-false}"
NO_ARM_LICENSE="${NO_ARM_LICENSE:-true}"
NO_TTY="${NO_TTY:-true}"
LAVA_LOG="${LAVA_LOG:-./lava.log}"
DOCKER_CMDS_FILE="${DOCKER_CMDS_FILE:-./docker.txt}"
BM_CMDS_FILE="${BM_CMDS_FILE:-./bm.txt}"

JENKINS_PUBLIC_URL="${JENKINS_PUBLIC_URL}/artifact/lava.log"


# Fetch the LAVA log
r_curl "${LAVA_LOG}" "${JENKINS_PUBLIC_URL}"

# Get download directories from the lava log
i=1
for sa in $(awk '/saving as/ {print $4}' $LAVA_LOG); do
    # NOTE the leading dot, which modifies original LAVA paths
    saveas[$i]=".$sa"
    i=$((i + 1))
done

i=1
# Get the artefacts from the lava log
for url in $(awk '/downloading/ {print $3}' $LAVA_LOG); do
    urls[$i]="$url"
    i=$((i + 1))
done

total=$((i -1))

# Fetch artefacts and place it under top dir
mkdir -p $PWD/lava
i=1
for i in $(seq $total); do
    u=${urls[$i]}
    o=${saveas[$i]}

    mkdir -p $(dirname $o)

    # Just fetch in case artefact is not present
    if [ ! -f $o ]; then
       r_curl "$o" "$u"
    fi
    cp -f $o $PWD/lava
done

# allow docker to use local X windows
xhost + > /dev/null

rm -f ${DOCKER_CMDS_FILE} ${BM_CMDS_FILE}

grep -o -E 'docker run .*' $LAVA_LOG | tail -1 | while read line; do
    cmd="$line"
    cmd="$(echo $cmd | sed -e 's;docker run;docker run --env="DISPLAY" --net=host ;g')"

    if [[ "${NO_TTY}" == "true" ]]; then
        cmd="$(echo $cmd | sed 's/--tty//g')"
    fi

    if [[ "${NO_ARM_LICENSE}" == "true" ]]; then
        cmd="$(echo $cmd | sed 's/-e ARMLMD_LICENSE_FILE=27000@ci.trustedfirmware.org//g')"
    fi

    if [[ "${USE_LOCAL_IMAGE}" == "true" ]]; then
        cmd="$(echo $cmd | sed 's/987685672616.dkr.ecr.us-east-1.amazonaws.com\///g')"
    fi

    docker_cmd="$(echo $cmd | sed "s;--volume /;--volume $PWD/;g")"

    # Point model parameters to local lava folder
    bm_cmd=""
    for token in $docker_cmd; do
        bm_token="$(echo $token | sed "s;=/lava.*/;=$PWD/lava/;g")"
        bm_cmd="$bm_cmd $bm_token "
    done

    # trim the docker leading code
    bm_cmd="$(echo "${bm_cmd}" | sed 's;.* /opt/model;/opt/model;g')"

    echo "$docker_cmd" >> $DOCKER_CMDS_FILE
    echo "$bm_cmd" >> $BM_CMDS_FILE

done

echo "Docker command"
echo
cat $DOCKER_CMDS_FILE
echo

echo "Baremetal command"
echo
cat $BM_CMDS_FILE
echo

