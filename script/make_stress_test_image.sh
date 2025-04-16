#!/usr/bin/env bash
#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
#
# When pointed to a root file system archive ($root_fs) this script creates a
# disk image file ($img_file of size $size_gb, or 5GB by default) with 2
# partitions. Linaro OE ramdisk specifies the second partition as root device;
# the first partition is unused. The second partition is formatted as ext2, and
# the root file system extracted into it.
#
# Test suites for stress testing are created under /opt/tests.

set -e

if ! [ -x "$(command -v gawk)" ]; then
	echo "Error: gawk is not installed."
	echo "Run 'apt-get install gawk' to install"
	exit 1
fi

extract_script() {
	local to="${name:?}.sh"

	sed -n "/BEGIN $name/,/END $name/ {
		/^#\\(BEGIN\\|END\\)/d
		s/^#//
		p
	}" < "${progname:?}" > "$to"

	chmod +x "$to"
}

progname="$(readlink -f $0)"
root_fs="$(readlink -f ${root_fs:?})"
img_file="$(readlink -f ${img_file:?})"

mount_dir="${mount_dir:-/mnt}"
mount_dir="$(readlink -f $mount_dir)"

# Create an image file. We assume 5G is enough
size_gb="${size_gb:-5}"
echo "Creating image file $img_file (${size_gb}GB)..."
dd if=/dev/zero of="$img_file" bs=1M count="${size_gb}000" &>/dev/null

# Create a partition table, and then create 2 partitions. The boot expects the
# root file system to be present in the second partition.
echo "Creating partitions in $img_file..."
sed 's/ *#.*$//' <<EOF | fdisk "$img_file" &>/dev/null
o     # Create new partition table
n     # New partition
p     # Primary partition
      # Default partition number
      # Default start sector
+1M   # Dummy partition of 1MB
n     # New partition
p     # Primary partition
      # Default partition number
      # Default start sector
      # Default end sector
w
q
EOF

# Get the offset of partition
fdisk_out="$(fdisk -l "$img_file" | sed -n '$p')"

offset="$(echo "$fdisk_out" | awk '{print $2 * 512}')"
size="$(echo "$fdisk_out" | awk '{print (($3 - $2) * 512)}')"

# Setup and identify loop device
loop_dev="$(losetup --offset "$offset" --sizelimit "$size" --show --find \
	"$img_file")"

# Create ext2 file system on the mount
echo "Formatting partition as ext2 in $img_file..."
mkfs.ext2 "$loop_dev" &>/dev/null

# Mount loop device
mount "$loop_dev" "$mount_dir"

# Extract the root file system into the mount
cd "$mount_dir"
echo "Extracting $root_fs to $img_file..."
tar -xzf "$root_fs"

tests_dir="$mount_dir/opt/tests"
mkdir -p "$tests_dir"
cd "$tests_dir"

# Extract embedded scripts into the disk image
name="hotplug" extract_script
name="execute_pmqa" extract_script

echo
rm -rf "test_assets"
echo "Cloning test assets..."
git clone -q --depth 1 https://gerrit.oss.arm.com/tests/test_assets
echo "Cloned test assets."

cd test_assets
rm -rf "pm-qa"
echo "Cloning pm-qa..."
git clone -q --depth 1 https://git.linaro.org/tools/pm-qa.git
echo "Cloned pm-qa."

cd
umount "$mount_dir"

losetup -d "$loop_dev"

if [ "$SUDO_USER" ]; then
	chown "$SUDO_USER:$SUDO_USER" "$img_file"
fi

echo "Updated $img_file with stress tests."

#BEGIN hotplug
##!/bin/sh
#
#if [ -n "$1" ]
#then
#	min_cpu=$1
#	shift
#fi
#
#if [ -n "$1" ]
#then
#	max_cpu=$1
#	shift
#fi
#
#f_kconfig="/proc/config.gz"
#f_max_cpus="/sys/devices/system/cpu/present"
#hp_support=0
#hp="`gunzip -c /proc/config.gz | sed -n '/HOTPLUG.*=/p' 2>/dev/null`"
#
#if [ ! -f "$f_kconfig" ]
#then
#	if [ ! -f "$f_max_cpus" ]
#	then
#		echo "Unable to detect hotplug support. Exiting..."
#		exit -1
#	else
#		hp_support=1
#	fi
#else
#	if [ -n "$hp" ]
#	then
#		hp_support=1
#	else
#		echo "Unable to detect hotplug support. Exiting..."
#		exit -1
#	fi
#fi
#
#if [ -z "$max_cpu" ]
#then
#	max_cpu=`sed -E -n 's/([0-9]+)-([0-9]+)/\2/gpI' < $f_max_cpus`
#fi
#if [ -z "$min_cpu" ]
#then
#	min_cpu=`sed -E -n 's/([0-9]+)-([0-9]+)/\1/gpI' < $f_max_cpus`
#fi
#
#max_cpu=$(($max_cpu + 1))
#min_cpu=$(($min_cpu + 1))
#max_op=2
#
#while :
#do
#	cpu=$((RANDOM % max_cpu))
#	op=$((RANDOM % max_op))
#
#	if [ $op -eq 0 ]
#	then
##	   echo "Hotpluging out cpu$cpu..."
##	   echo $op > /sys/devices/system/cpu/cpu$cpu/online >/dev/null
##	   echo $op > /sys/devices/system/cpu/cpu$cpu/online | grep -i "err"
#		echo $op > /sys/devices/system/cpu/cpu$cpu/online
#	else
##	   echo "Hotpluging in cpu$cpu..."
##	   echo $op > /sys/devices/system/cpu/cpu$cpu/online >/dev/null
##	   echo $op > /sys/devices/system/cpu/cpu$cpu/online | grep -i "err"
#		echo $op > /sys/devices/system/cpu/cpu$cpu/online
#
#	fi
#done
#
#exit 0
#
#MAXCOUNT=10
#count=1
#
#echo
#echo "$MAXCOUNT random numbers:"
#echo "-----------------"
#while [ "$count" -le $MAXCOUNT ]	  # Generate 10 ($MAXCOUNT) random integers.
#do
#	number=$RANDOM
#	echo $number
#	count=$(($count + 1))
#done
#echo "-----------------"
#END hotplug


#BEGIN execute_pmqa
##!/bin/sh
#
#usage ()
#{
#        printf "\n***************   Usage    *******************\n"
#        printf "sh execute_pmqa.sh args\n"
#        printf "args:\n"
#        printf "t -> -t|--targets=Folders (tests) within PM QA folder to be executed by make, i.e. cpufreq, cpuidle, etc. Defaults to . (all)\n"
#        printf "\t -> -a|--assets=Test assets folder (within the FS) where resides the PM QA folder. Required.\n"
#}
#
#for i in "$@"
#do
#        case $i in
#            -t=*|--targets=*)
#            TARGETS="${i#*=}"
#            ;;
#            -a=*|--assets=*)
#            TEST_ASSETS_FOLDER="${i#*=}"
#            ;;
#            *)
#                    # unknown option
#                printf "Unknown argument $i in arguments $@\n"
#                usage
#                exit 1
#            ;;
#        esac
#done
#
#if [ -z "$TEST_ASSETS_FOLDER" ]; then
#        usage
#        exit 1
#fi
#
#TARGETS=${TARGETS:-'.'}
#cd $TEST_ASSETS_FOLDER/pm-qa && make -C utils
#for j in $TARGETS
#do
#        make -k -C "$j" check
#done
#make clean
#rm -f ./utils/cpuidle_killer
#tar -zcvf ../pm-qa.tar.gz ./
#END execute_pmqa
