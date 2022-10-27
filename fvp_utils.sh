#!/usr/bin/env bash
#
# Copyright (c) 2020-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

bl1_addr="${bl1_addr:-0x0}"
bl31_addr="${bl31_addr:-0x04001000}"
bl32_addr="${bl32_addr:-0x04003000}"
bl33_addr="${bl33_addr:-0x88000000}"
dtb_addr="${dtb_addr:-0x82000000}"
fip_addr="${fip_addr:-0x08000000}"
initrd_addr="${initrd_addr:-0x84000000}"
kernel_addr="${kernel_addr:-0x80080000}"
el3_payload_addr="${el3_payload_addr:-0x80000000}"

# SPM requires following addresses for RESET_TO_BL31 case
spm_addr="${spm_addr:-0x6000000}"
spmc_manifest_addr="${spmc_addr:-0x0403f000}"
sp1_addr="${sp1_addr:-0x7000000}"
sp2_addr="${sp2_addr:-0x7100000}"
sp3_addr="${sp3_addr:-0x7200000}"
sp4_addr="${sp4_addr:-0x7600000}"
# SPM out directories
export spm_secure_out_dir="${spm_secure_out_dir:-secure_aem_v8a_fvp_clang}"
export spm_non_secure_out_dir="${spm_non_secure_out_dir:-aem_v8a_fvp_clang}"

ns_bl1u_addr="${ns_bl1u_addr:-0x0beb8000}"
fwu_fip_addr="${fwu_fip_addr:-0x08400000}"
backup_fip_addr="${backup_fip_addr:-0x09000000}"
romlib_addr="${romlib_addr:-0x03ff2000}"

uboot32_fip_url="$linaro_release/fvp32-latest-busybox-uboot/fip.bin"

rootfs_url="$linaro_release/lt-vexpress64-openembedded_minimal-armv8-gcc-5.2_20170127-761.img.gz"

# Default FVP model variables
default_model_dtb="dtb.bin"

# FVP containers and model paths
fvp_arm_std_library_11_12="fvp:fvp_arm_std_library_${model_version_11_12}_${model_build_11_12};/opt/model/FVP_ARM_Std_Library/models/${model_flavour_11_12}"
fvp_arm_std_library="fvp:fvp_arm_std_library_${model_version}_${model_build};/opt/model/FVP_ARM_Std_Library/FVP_Base"
fvp_base_revc_2xaemva="fvp:fvp_base_revc-2xaemva_${model_version}_${model_build};/opt/model/Base_RevC_AEMvA_pkg/models/${model_flavour}"
foundation_platform="fvp:foundation_platform_${model_version}_${model_build};/opt/model/Foundation_Platformpkg/models/${model_flavour}"
fvp_base_aemv8r="fvp:fvp_base_aemv8r_${model_version}_${model_build};/opt/model/AEMv8R_base_pkg/models/${model_flavour}"

# FVP associate array, run_config are keys and fvp container parameters are the values
#   Container parameters syntax: <model name>;<model dir>;<model bin>
# FIXMEs: fix those ;;; values with real values

declare -A fvp_models
fvp_models=(
[base-aemv8a-quad]=";;;"
[base-aemv8a-revb]=";;;"
[base-aemv8a-latest-revb]=";;;"
[base-aemva]=";;;"
[base-aemv8a-gic600ae]=";;;"
[foundationv8]="${foundation_platform};Foundation_Platform"
[base-aemv8a]="${fvp_base_revc_2xaemva};FVP_Base_RevC-2xAEMvA"
[baser-aemv8r]=";;;"
[cortex-a32x4]="${fvp_arm_std_library_11_12};FVP_Base_Cortex-A32x4"
[cortex-a35x4]="${fvp_arm_std_library};FVP_Base_Cortex-A35x4"
[cortex-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A53x4"
[cortex-a55x4-a75x4]="${fvp_arm_std_library};FVP_Base_Cortex-A55x4+Cortex-A75x4"
[cortex-a55x4-a76x2]="${fvp_arm_std_library};FVP_Base_Cortex-A55x4+Cortex-A76x2"
[cortex-a57x1-a53x1]="${fvp_arm_std_library};FVP_Base_Cortex-A57x1-A53x1"
[cortex-a57x2-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A57x2-A53x4"
[cortex-a57x4]="${fvp_arm_std_library};FVP_Base_Cortex-A57x4"
[cortex-a57x4-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A57x4-A53x4"
[cortex-a65aex8]="${fvp_arm_std_library};FVP_Base_Cortex-A65AEx8"
[cortex-a65x4]="${fvp_arm_std_library};FVP_Base_Cortex-A65x4"
[cortex-a72x4]="${fvp_arm_std_library};FVP_Base_Cortex-A72x4"
[cortex-a72x4-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A72x4-A53x4"
[cortex-a73x4]="${fvp_arm_std_library};FVP_Base_Cortex-A73x4"
[cortex-a73x4-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A73x4-A53x4"
[cortex-a75x4]="${fvp_arm_std_library};FVP_Base_Cortex-A75x4"
[cortex-a76aex4]="${fvp_arm_std_library};FVP_Base_Cortex-A76AEx4"
[cortex-a76aex2]="${fvp_arm_std_library};FVP_Base_Cortex-A76AEx2"
[cortex-a76x4]="${fvp_arm_std_library};FVP_Base_Cortex-A76x4"
[cortex-a77x4]="${fvp_arm_std_library};FVP_Base_Cortex-A77x4"
[cortex-a78x4]="${fvp_arm_std_library};FVP_Base_Cortex-A78x4"
[cortex-a78cx4]="${fvp_arm_std_library};FVP_Base_Cortex-A78Cx4"
[cortex-x2]="${fvp_arm_std_library};FVP_Base_Cortex-X2x4"
[neoverse_e1x1]="${fvp_arm_std_library};FVP_Base_Neoverse-E1x1"
[neoverse_e1x2]="${fvp_arm_std_library};FVP_Base_Neoverse-E1x2"
[neoverse_e1x4]="${fvp_arm_std_library};FVP_Base_Neoverse-E1x4"
[neoverse_n1]="${fvp_arm_std_library};FVP_Base_Neoverse-N1x4"
[neoverse_n2]="${fvp_arm_std_library_11_12};FVP_Base_Neoverse-N1x4"
[neoverse-v1x4]=";;;"
[cortexa710x4]=";;;"
[css-rdv1]=";;;"
[css-rde1edge]=";;;"
[css-rdn1edge]=";;;"
[css-rdn1edgex2]=";;;"
[css-sgi575]=";;;"
[tc0]=";;;"
[tc1]=";;;"
[tc2]=";;;"
)


# FVP Kernel URLs
declare -A fvp_kernels
fvp_kernels=(
[fvp-aarch32-zimage]="$linaro_release/fvp32-latest-busybox-uboot/Image"
[fvp-busybox-uboot]="$linaro_release/fvp-latest-busybox-uboot/Image"
[fvp-oe-uboot32]="$linaro_release/fvp32-latest-oe-uboot/Image"
[fvp-oe-uboot]="$linaro_release/fvp-latest-oe-uboot/Image"
[fvp-quad-busybox-uboot]="$tfa_downloads/quad_cluster/Image"
)

# FVP initrd URLs
declare -A fvp_initrd_urls
fvp_initrd_urls=(
[aarch32-ramdisk]="$linaro_release/fvp32-latest-busybox-uboot/ramdisk.img"
[dummy-ramdisk]="$linaro_release/fvp-latest-oe-uboot/ramdisk.img"
[dummy-ramdisk32]="$linaro_release/fvp32-latest-oe-uboot/ramdisk.img"
[default]="$linaro_release/fvp-latest-busybox-uboot/ramdisk.img"
)

get_optee_bin() {
	url="$tfa_downloads/optee/tee.bin" \
           saveas="bl32.bin" fetch_file
	archive_file "bl32.bin"
}

# For Measured Boot tests using a TA based on OPTEE, it is necessary to use a
# specific build rather than the default one generated by Jenkins.
get_ftpm_optee_bin() {
	url="$tfa_downloads/ftpm/optee/tee-header_v2.bin" \
		saveas="bl32.bin" fetch_file
	archive_file "bl32.bin"

	url="$tfa_downloads/ftpm/optee/tee-pager_v2.bin" \
		saveas="bl32_extra1.bin" fetch_file
	archive_file "bl32_extra1.bin"

	# tee-pageable_v2.bin is just a empty file, named as bl32_extra2.bin,
	# so just create the file
	touch "bl32_extra2.bin"
	archive_file "bl32_extra2.bin"
}

get_uboot32_bin() {
	local tmpdir="$(mktempdir)"

	pushd "$tmpdir"
	extract_fip "$uboot32_fip_url"
	mv "nt-fw.bin" "uboot.bin"
	archive_file "uboot.bin"
	popd
}

get_uboot_bin() {
	local uboot_url="$linaro_release/fvp-latest-busybox-uboot/bl33-uboot.bin"

	url="$uboot_url" saveas="uboot.bin" fetch_file
	archive_file "uboot.bin"
}

get_uefi_bin() {
	uefi_downloads="${uefi_downloads:-http://files.oss.arm.com/downloads/uefi}"
	uefi_ci_bin_url="${uefi_ci_bin_url:-$uefi_downloads/Artifacts/Linux/github/fvp/static/DEBUG_GCC5/FVP_AARCH64_EFI.fd}"

	url=$uefi_ci_bin_url saveas="uefi.bin" fetch_file
	archive_file "uefi.bin"
}

get_kernel() {
	local kernel_type="${kernel_type:?}"
	local url="${fvp_kernels[$kernel_type]}"

	url="${url:?}" saveas="kernel.bin" fetch_file
	archive_file "kernel.bin"
}

get_initrd() {
	local initrd_type="${initrd_type:?}"
	local url="${fvp_initrd_urls[$initrd_type]}"

	url="${url:?}" saveas="initrd.bin" fetch_file
	archive_file "initrd.bin"
}

get_dtb() {
	local dtb_type="${dtb_type:?}"
	local dtb_url
	local dtb_saveas="$workspace/dtb.bin"
	local cc="$(get_tf_opt CROSS_COMPILE)"
	local pp_flags="-P -nostdinc -undef -x assembler-with-cpp"

	case "$dtb_type" in
		"fvp-base-quad-cluster-gicv3-psci")
			# Get the quad-cluster FDT from pdsw area
			dtb_url="$tfa_downloads/quad_cluster/fvp-base-quad-cluster-gicv3-psci.dtb"
			url="$dtb_url" saveas="$dtb_saveas" fetch_file
			;;
		*)
			# Preprocess DTS file
			${cc}gcc -E ${pp_flags} -I"$tf_root/fdts" -I"$tf_root/include" \
				-o "$workspace/${dtb_type}.pre.dts" \
				"$tf_root/fdts/${dtb_type}.dts"
			# Generate DTB file from DTS
			dtc -I dts -O dtb \
				"$workspace/${dtb_type}.pre.dts" -o "$dtb_saveas"
	esac

	archive_file "$dtb_saveas"
}

get_rootfs() {
	local tmpdir
	local fs_base="$(echo $(basename $rootfs_url) | sed 's/\.gz$//')"
	local cached="$project_filer/ci-files/$fs_base"

	if upon "$jenkins_run" && [ -f "$cached" ]; then
		# Job workspace is limited in size, and the root file system is
		# quite large. This means, parallel runs of root file system
		# tests could fail. So, for Jenkins runs, copy and use the root
		# file system image from the $CI_SCRATCH location
		local private="$CI_SCRATCH/$JOB_NAME-$BUILD_NUMBER"
		mkdir -p "$private"
		rm -f "$private/rootfs.bin"
		url="$cached" saveas="$private/rootfs.bin" fetch_file
		ln -s "$private/rootfs.bin" "$archive/rootfs.bin"
		return
	fi

	tmpdir="$(mktempdir)"
	pushd "$tmpdir"
	url="$rootfs_url" saveas="rootfs.bin" fetch_file

	# Possibly, the filesystem image we just downloaded is compressed.
	# Decompress it if required.
	if file "rootfs.bin" | grep -iq 'gzip compressed data'; then
		echo "Decompressing root file system image rootfs.bin ..."
		gunzip --stdout "rootfs.bin" > uncompressed_fs.bin
		mv uncompressed_fs.bin "rootfs.bin"
	fi

	archive_file "rootfs.bin"
	popd
}

fvp_romlib_jmptbl_backup="$(mktempdir)/jmptbl.i"

fvp_romlib_runtime() {
	local tmpdir="$(mktempdir)"

	# Save BL1 and romlib binaries from original build
	mv "${tf_build_root:?}/${plat:?}/${mode:?}/romlib/romlib.bin" "$tmpdir/romlib.bin"
	mv "${tf_build_root:?}/${plat:?}/${mode:?}/bl1.bin" "$tmpdir/bl1.bin"

	# Patch index file
	cp "${tf_root:?}/plat/arm/board/fvp/jmptbl.i" "$fvp_romlib_jmptbl_backup"
	sed -i '/fdt/ s/.$/&\ patch/' ${tf_root:?}/plat/arm/board/fvp/jmptbl.i

	# Rebuild with patched file
	echo "Building patched romlib:"
	build_tf

	# Retrieve original BL1 and romlib binaries
	mv "$tmpdir/romlib.bin" "${tf_build_root:?}/${plat:?}/${mode:?}/romlib/romlib.bin"
	mv "$tmpdir/bl1.bin" "${tf_build_root:?}/${plat:?}/${mode:?}/bl1.bin"
}

fvp_romlib_cleanup() {
	# Restore original index
	mv "$fvp_romlib_jmptbl_backup" "${tf_root:?}/plat/arm/board/fvp/jmptbl.i"
}


fvp_gen_bin_url() {
    local bin_mode="${bin_mode:?}"
    local bin="${1:?}"

    if upon "$jenkins_run"; then
        echo "$jenkins_url/job/$JOB_NAME/$BUILD_NUMBER/artifact/artefacts/$bin_mode/$bin"
    else
        echo "file://$workspace/artefacts/$bin_mode/$bin"
    fi
}

# Generates the template for YAML-based LAVA job definitions from a file
# corresponding to the currently-selected payload, e.g.:
#
# - `lava-templates/fvp-linux.yaml`
# - `lava-templates/fvp-tftf.yaml`
#
# The job definition template is itself expanded with visibility of all
# variables that are available from within the function, including those with
# local scope.
#
# TODO: Move the Gerrit metadata generation to to the main YAML generation phase
#   so that we can template the file in one phase.
gen_fvp_yaml_template() {
    if [ -n "${GERRIT_CHANGE_NUMBER}" ]; then
        local gerrit_url="https://review.trustedfirmware.org/c/${GERRIT_CHANGE_NUMBER}/${GERRIT_PATCHSET_NUMBER}"
    elif [ -n "${GERRIT_REFSPEC}" ]; then
        local gerrit_url=$(echo ${GERRIT_REFSPEC} |
            awk -F/ '{print "https://review.trustedfirmware.org/c/" $4 "/" $5}')
    fi

    local yaml_template_file="${workspace}/fvp_template.yaml"

    pushd "${ci_root}/script/lava-templates"
    expand_template "fvp-${payload_type:?}.yaml" > "$yaml_template_file"
    popd

    archive_file "${yaml_template_file}"
}

gen_fvp_yaml() {
    local model="${model:?}"

    local yaml_template_file="$workspace/fvp_template.yaml"
    local yaml_file="$workspace/fvp.yaml"
    local yaml_job_file="$workspace/job.yaml"
    local lava_model_params="$workspace/lava_model_params"

    # this function expects a template, quit if it is not present
    if [ ! -f "$yaml_template_file" ]; then
	return
    fi

    local model_params="${fvp_models[$model]}"
    local model_name="$(echo "${model_params}" | awk -F ';' '{print $1}')"
    local model_dir="$(echo "${model_params}"  | awk -F ';' '{print $2}')"
    local model_bin="$(echo "${model_params}"  | awk -F ';' '{print $3}')"

    # model params are required for correct yaml creation, quit if empty
    if [ -z "${model_name}" ]; then
       echo "FVP model param 'model_name' variable empty, yaml not produced"
       return
    elif [ -z "${model_dir}" ]; then
       echo "FVP model param 'model_dir' variable empty, yaml not produced"
       return
    elif [ -z "${model_bin}"  ]; then
       echo "FVP model param 'model_bin' variable empty, yaml not produced"
       return
    fi

    echo "FVP model params: model_name=$model_name model_dir=$model_dir model_bin=$model_bin"

    # optional parameters, defaults to globals
    local model_dtb="${model_dtb:-$default_model_dtb}"

    # possible artefacts
    backup_fip="$(fvp_gen_bin_url backup_fip.bin)"
    bl1="$(fvp_gen_bin_url bl1.bin)"
    bl2="$(fvp_gen_bin_url bl2.bin)"
    bl31="$(fvp_gen_bin_url bl31.bin)"
    bl32="$(fvp_gen_bin_url bl32.bin)"
    busybox="$(fvp_gen_bin_url busybox.bin.gz)"
    cactus_primary="$(fvp_gen_bin_url cactus-primary.pkg)"
    cactus_secondary="$(fvp_gen_bin_url cactus-secondary.pkg)"
    cactus_tertiary="$(fvp_gen_bin_url cactus-tertiary.pkg)"
    coverage_trace_plugin="${coverage_trace_plugin}"
    dtb="$(fvp_gen_bin_url ${model_dtb})"
    el3_payload="$(fvp_gen_bin_url el3_payload.bin)"
    fip="$(fvp_gen_bin_url fip.bin)"
    fip_gpt="$(fvp_gen_bin_url fip_gpt.bin)"
    fvp_spmc_manifest_dtb="$(fvp_gen_bin_url fvp_spmc_manifest.dtb)"
    fwu_fip="$(fvp_gen_bin_url fwu_fip.bin)"
    generic_trace="${tfa_downloads}/FastModelsPortfolio_${model_version}/plugins/${model_flavour}/GenericTrace.so"
    hafnium="$(fvp_gen_bin_url hafnium.bin)"
    image="$(fvp_gen_bin_url kernel.bin)"
    ivy="$(fvp_gen_bin_url ivy.pkg)"
    manifest_dtb="$(fvp_gen_bin_url manifest.dtb)"
    mcp_rom="$(fvp_gen_bin_url mcp_rom.bin)"
    mcp_rom_hyphen="$(fvp_gen_bin_url mcp-rom.bin)"
    ns_bl1u="$(fvp_gen_bin_url ns_bl1u.bin)"
    ns_bl2u="$(fvp_gen_bin_url ns_bl2u.bin)"
    ramdisk="$(fvp_gen_bin_url initrd.bin)"
    romlib="$(fvp_gen_bin_url romlib.bin)"
    rootfs="$(fvp_gen_bin_url rootfs.bin.gz)"
    secure_hafnium="$(fvp_gen_bin_url secure_hafnium.bin)"
    scp_ram="$(fvp_gen_bin_url scp_ram.bin)"
    scp_ram_hyphen="$(fvp_gen_bin_url scp-ram.bin)"
    scp_rom="$(fvp_gen_bin_url scp_rom.bin)"
    scp_rom_hyphen="$(fvp_gen_bin_url scp-rom.bin)"
    spm="$(fvp_gen_bin_url spm.bin)"
    tftf="$(fvp_gen_bin_url tftf.bin)"
    tmp="$(fvp_gen_bin_url tmp.bin)"
    uboot="$(fvp_gen_bin_url uboot.bin)"

    docker_registry="${docker_registry:-}"
    docker_registry="$(docker_registry_append)"
    docker_name="${docker_registry}$model_name"
    prompt1='/ #'
    prompt2='root@genericarmv8:~#'
    version_string="\"Fast Models"' [^\\n]+'"\""

    test_config="${TEST_CONFIG}"

    # arrays that relates variables and template macros
    # NOTE: any addition on these arrays, requires an addition in the
    # fvp templates
    declare -A metadata_macros
    declare -A yaml_macros
    declare -A artefacts_macros
    metadata_macros=(
        [test_config]="{TEST_CONFIG}"
    )
    yaml_macros=(
        [armlmd_license_file]="{ARMLMD_LICENSE_FILE}"
        [docker_name]="{BOOT_DOCKER_NAME}"
        [model]="{MODEL}"
        [model_bin]="{BOOT_IMAGE_BIN}"
        [model_dir]="{BOOT_IMAGE_DIR}"
        [prompt1]="{PROMPT1}"
        [prompt2]="{PROMPT2}"
        [version_string]="{BOOT_VERSION_STRING}"
    )
    artefacts_macros=(
        [backup_fip]="{BACKUP_FIP}"
        [bl1]="{BL1}"
        [bl2]="{BL2}"
        [bl31]="{BL31}"
        [bl32]="{BL32}"
        [cactus_primary]="{CACTUS_PRIMARY}"
        [cactus_secondary]="{CACTUS_SECONDARY}"
        [cactus_tertiary]="{CACTUS_TERTIARY}"
        [coverage_trace_plugin]="{COVERAGE_TRACE_PLUGIN}"
        [fvp_spmc_manifest_dtb]="{FVP_SPMC_MANIFEST_DTB}"
        [busybox]="{BUSYBOX}"
        [dtb]="{DTB}"
        [el3_payload]="{EL3_PAYLOAD}"
        [fip_gpt]="{FIP_GPT}"
        [fwu_fip]="{FWU_FIP}"
        [fip]="{FIP}"
        [generic_trace]="{GENERIC_TRACE}"
        [hafnium]="{HAFNIUM}"
        [image]="{IMAGE}"
        [ivy]="{IVY}"
        [manifest_dtb]="{MANIFEST_DTB}"
        [mcp_rom]="{MCP_ROM}"
        [mcp_rom_hyphen]="{MCP_ROM_HYPHEN}"
        [ns_bl1u]="{NS_BL1U}"
        [ns_bl2u]="{NS_BL2U}"
        [ramdisk]="{RAMDISK}"
        [romlib]="{ROMLIB}"
        [rootfs]="{ROOTFS}"
        [secure_hafnium]="{SECURE_HAFNIUM}"
        [scp_ram]="{SCP_RAM}"
        [scp_ram_hyphen]="{SCP_RAM_HYPHEN}"
        [scp_rom]="{SCP_ROM}"
        [scp_rom_hyphen]="{SCP_ROM_HYPHEN}"
        [spm]="{SPM}"
        [tftf]="{TFTF}"
        [tmp]="{TMP}"
        [uboot]="{UBOOT}"
    )

    declare -A artefact_filters=(
        [backup_fip]="backup_fip.bin"
        [bl1]="bl1.bin"
        [bl2]="bl2.bin"
        [bl31]="bl31.bin"
        [bl32]="bl32.bin"
        [busybox]="busybox.bin"
        [cactus_primary]="cactus-primary.pkg"
        [cactus_secondary]="cactus-secondary.pkg"
        [cactus_tertiary]="cactus-tertiary.pkg"
        [coverage_trace_plugin]="coverage_trace.so"
        [dtb]="dtb.bin"
        [el3_payload]="el3_payload.bin"
        [fip_gpt]="fip_gpt.bin"
        [fip]="fip.bin"
        [fvp_spmc_manifest_dtb]="=fvp_spmc_manifest.dtb"
        [fwu_fip]="fwu_fip.bin"
        [generic_trace]="GenericTrace.so"
        [hafnium]="hafnium.bin"
        [image]="kernel.bin"
        [ivy]="ivy.pkg"
        [manifest_dtb]="=manifest.dtb"
        [mcp_rom_hyphen]="mcp-rom.bin"
        [mcp_rom]="mcp_rom.bin"
        [ns_bl1u]="ns_bl1u.bin"
        [ns_bl2u]="ns_bl2u.bin"
        [ramdisk]="initrd.bin|initrd.img"
        [romlib]="romlib.bin"
        [rootfs]="rootfs.bin"
        [scp_ram_hyphen]="scp-ram.bin"
        [scp_ram]="scp_ram.bin"
        [scp_rom_hyphen]="scp-rom.bin"
        [scp_rom]="scp_rom.bin"
        [secure_hafnium]="secure_hafnium.bin"
        [spm]="spm.bin"
        [tftf]="tftf.bin"
        [tmp]="tmp.bin"
        [uboot]="uboot.bin"
    )

    declare -a artefacts=()

    for artefact in "${!artefact_filters[@]}"; do
        if grep -E -q "${artefact_filters[${artefact}]}" "${archive}/model_params"; then
            artefacts+=("${artefact}")
        fi
    done

    # copied files are the working files
    cp "${yaml_template_file}" "${yaml_file}"
    cp "$archive/model_params" "$lava_model_params"

    # Ensure braces in the FVP model parameters are not accidentally interpreted
    # as LAVA macros.
    sed -i -e 's/{/{{/g' "${lava_model_params}"
    sed -i -e 's/}/}}/g' "${lava_model_params}"

    # replace metadata macros with real values
    for m in "${!metadata_macros[@]}"; do
        sed -i -e "s|${metadata_macros[$m]}|${!m}|" "$yaml_file"
    done

    # replace yaml macros with real values
    for m in "${!yaml_macros[@]}"; do
        sed -i -e "s|${yaml_macros[$m]}|${!m}|" "$yaml_file"
    done

    # replace artefact macros with real values
    for m in "${!artefacts_macros[@]}"; do
        sed -i -e "s|${artefacts_macros[$m]}|${!m}|" "$yaml_file"
    done

    # LAVA expects parameters as 'macros', i.e. {X} instead of x.bin, so
    # replace them. As in the macro removal above, handle special cases for several
    # artefacts
    for m in "${!artefacts_macros[@]}"; do
        case "$m" in
            cactus_primary)
                sed -i -e "s|=cactus-primary.pkg|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            cactus_secondary)
                sed -i -e "s|=cactus-secondary.pkg|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            cactus_tertiary)
                sed -i -e "s|=cactus-tertiary.pkg|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            coverage_trace_plugin)
                sed -i -e "s|--plugin .*coverage_trace.so|--plugin ${artefacts_macros[$m]}|" "$lava_model_params"
                sed -i -e "s|--plugin=.*coverage_trace.so|--plugin=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            fvp_spmc_manifest_dtb)
                sed -i -e "s|=fvp_spmc_manifest.dtb|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            generic_trace)
                sed -i -e "s|--plugin .*GenericTrace.so|--plugin ${artefacts_macros[$m]}|" "$lava_model_params"
		sed -i -e "s|--plugin=.*GenericTrace.so|--plugin=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            image)
                sed -i -e "s|=kernel.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            ivy)
                sed -i -e "s|=ivy.pkg|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            manifest_dtb)
                sed -i -e "s|=manifest.dtb|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            mcp_rom_hyphen)
                sed -i -e "s|=mcp-rom.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            ramdisk)
                sed -i -e "s|=initrd.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                sed -i -e "s|=initrd.img|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            scp_ram_hyphen)
                sed -i -e "s|=scp-ram.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            scp_rom_hyphen)
                sed -i -e "s|=scp-rom.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            tmp | hafnium | secure_hafnium)
                sed -i -e "s|=.*/${m}.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
            *)
                sed -i -e "s|=${m}.bin|=${artefacts_macros[$m]}|" "$lava_model_params"
                ;;
        esac
    done

    # include the model parameters
    while read -r line; do
        if [ -n "$line" ]; then
            yaml_line="- $(echo "${line}" | jq -R .)"
            sed -i -e "/{BOOT_ARGUMENTS}/i \ \ \ \ $yaml_line" "$yaml_file"
        fi
    done < "$lava_model_params"
    sed -i -e '/{BOOT_ARGUMENTS}/d' "$yaml_file"

    # Append expect commands into the job definition through test-interactive commands
    gen_fvp_yaml_expect >> "$yaml_file"

    # create job.yaml
    cp "$yaml_file" "$yaml_job_file"

    # archive both yamls
    archive_file "$yaml_file"
    archive_file "$yaml_job_file"
}

gen_fvp_yaml_expect() {

    run_root="$archive/run"

    # Loop through all uarts expect files
    for expect_file in $(find $run_root -name expect); do

        # TODO: currently, only handle UART 0
        case $expect_file in
            *uart0* )
                uart_number=uart0
                ;;
            *)
                continue
                ;;
        esac

        # Array containing "interactive" or "monitor" expect strings and populated during run config execution.
        # Interactive expect scripts are converted into LAVA Interactive Test Actions (see
        # https://tf.validation.linaro.org/static/docs/v2/interactive.html#writing-tests-interactive) and
        # monitor expect scripts are converted into LAVA Monitor Test Actions (see
        # https://validation.linaro.org/static/docs/v2/actions-test.html#monitor)
        #
        # Interactive Expect strings have the format 'i;<prompt>;<succeses>;<failures>;<commands>'
        # where multiple successes or  failures or commands are separated by @
        #
        # Monitor Expect strings have the format 'm;<start>;<end>;<patterns>'
        # where multiple patterns are separated by @
        #
        expect_string=()

       # Get the real name of the expect file
        expect_file=$(cat $expect_file)

        # Source the run_config enviroment variables
        env=$run_root/$uart_number/env
        if [ -e $env ]; then
            source $env
        fi

        # Get all expect strings
        expect_file=$ci_root/expect-lava/${expect_file}
        source $expect_file


        if [ ${#expect_string[@]} -gt 0 ]; then

            # expect loop
            for key in "${!expect_string[@]}"; do

                # single raw expect string
                es="${expect_string[${key}]}"

                # action type: either m or i
                action="$(echo "${es}" | awk -F ';' '{print $1}')"

                if [ "${action}" = "m" ]; then

                    start="$(echo "${es}" | awk -F ';' '{print $2}')"
                    end="$(echo "${es}" | awk -F ';' '{print $3}')"
                    patterns="$(echo "${es}" | awk -F ';' '{print $4}')"

                    cat << EOF
- test:
   monitors:
   - name: tests
     start: '${start}'
     end: '${end}'
EOF
                    # Patterns are separated by '@'
                    OLD_IFS=$IFS; IFS=$'@'
                    for p in ${patterns}; do
                        cat << EOF
     pattern: '$p'
EOF
                    done
                    IFS=$OLD_IFS
                    cat << EOF
     fixupdict:
      PASS: pass
      FAIL: fail
EOF
                fi # end of monitor action

                if [ "${action}" = "i" ]; then

                    prompts="$(echo "${es}" | awk -F ';' '{print $2}')"
                    successes="$(echo "${es}" | awk -F ';' '{print $3}')"
                    failures="$(echo "${es}" | awk -F ';' '{print $4}')"
                    commands="$(echo "${es}" | awk -F ';' '{print $5}')"

                    cat << EOF
- test:
   interactive:
EOF
                    OLD_IFS=$IFS; IFS=$'@'

                    if [[ -n "${prompts}" && -n "${successes}" && -n "${failures}" ]]; then
                        cat << EOF
   - name: interactive_${uart_number}_${key}
     prompts: ['${prompts}']
     script:
EOF
                        if [ -z "${commands}" ]; then
                            cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command:
EOF
                        else
                            for c in ${commands}; do
                                cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command: "$c"
EOF
                            done
                        fi
                        cat << EOF
       successes:
EOF
                        for s in ${successes}; do
                            cat <<EOF
       - message: '$s'
EOF
                        done
                        cat << EOF
       failures:
EOF
                        for f in ${failures}; do
                            cat <<EOF
       - message: '$f'
EOF
                        done
                    elif [[ -n "${prompts}" && -n "${successes}" ]]; then
                        cat << EOF
   - name: interactive_${uart_number}_${key}
     prompts: ['${prompts}']
     script:
EOF

                        if [ -z "${commands}" ]; then
                            cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command:
EOF
                        else
                            for c in ${commands}; do
                                cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command: "$c"
EOF
                            done
                        fi
                        cat << EOF
       successes:
EOF
                        for s in ${successes}; do
                            cat <<EOF
       - message: '$s'
EOF
                        done

                    elif [[ -n "${prompts}" && -n "${failures}" ]]; then
                        cat << EOF
   - name: interactive_${uart_number}_${key}
     prompts: ['${prompts}']
     script:
EOF
                        if [ -z "${commands}" ]; then
                            cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command:
EOF
                        else
                            for c in ${commands}; do
                                cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command: "$c"
EOF
                            done
                        fi
                        cat << EOF
       failures:
EOF
                        for f in ${failures}; do
                            cat <<EOF
       - message: '$f'
EOF
                        done
                    else
                        cat << EOF
   - name: interactive_${uart_number}_${key}
     prompts: ['${prompts}']
     script:
EOF
                        if [ -z "${commands}" ]; then
                            cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command:
EOF
                        else
                            for c in ${commands}; do
                                cat <<EOF
     - name: interactive_command_${uart_number}_${key}
       command: "$c"
EOF
                            done
                        fi
                    fi

                    IFS=$OLD_IFS
                fi # end of interactive action

            done # end of expect  loop

        fi
    done # end of uart loop
}

docker_registry_append() {
    # if docker_registry is empty, just use local docker registry
    [ -z "$docker_registry" ] && return

    local last=-1
    local last_char="${docker_registry:last}"

    if [ "$last_char" != '/' ]; then
        docker_registry="${docker_registry}/";
    fi
    echo "$docker_registry"
}

# generate GPT image and archive it
gen_gpt_bin() {
    raw_image="fip_gpt.bin"
    img_uuid="FB90808A-BA9A-4D42-B9A2-A7A937144AEE"
    img_bank_uuid=`uuidgen`
    disk_uuid=`uuidgen`
    bin="${1:?}"

    # maximum FIP size 2MB
    fip_max_size=2097152
    start_sector=34
    sector_size=512
    num_sectors=$(($fip_max_size/$sector_size))
    bin_size=$(stat -c %s $bin)

    if [[ $fip_max_size -lt $bin_size ]]
    then
           echo "FIP binary ($bin_size bytes) larger than max partition 1"
                "size ($fip_max_size byte)"
           return
    fi

    # create raw 5MB image
    dd if=/dev/zero of=$raw_image bs=5M count=1

    # create GPT image
    sgdisk -a 1 -U $disk_uuid -n 1:$start_sector:+$num_sectors \
           -c 1:FIP_A -t 1:$img_uuid $raw_image -u $img_bank_uuid

    echo "write binary $bin at sector $start_sector"
    dd if=$bin of=$raw_image bs=$sector_size seek=$start_sector \
       count=$num_sectors conv=notrunc

    archive_file "fip_gpt.bin"
}

set +u
