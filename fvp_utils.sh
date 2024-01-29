#!/usr/bin/env bash
#
# Copyright (c) 2020-2023, Arm Limited. All rights reserved.
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
export spm_secure_out_dir="${spm_secure_out_dir:-secure_aem_v8a_fvp_vhe_clang}"
export spm_non_secure_out_dir="${spm_non_secure_out_dir:-aem_v8a_fvp_vhe_clang}"

ns_bl1u_addr="${ns_bl1u_addr:-0x0beb8000}"
fwu_fip_addr="${fwu_fip_addr:-0x08400000}"
backup_fip_addr="${backup_fip_addr:-0x09000000}"
romlib_addr="${romlib_addr:-0x03ff2000}"

uefi_downloads="${uefi_downloads:-http://files.oss.arm.com/downloads/uefi}"
uefi_ci_bin_url="${uefi_ci_bin_url:-$uefi_downloads/Artifacts/Linux/github/fvp/static/DEBUG_GCC5/FVP_AARCH64_EFI.fd}"

uboot32_fip_url="$linaro_release/fvp32-latest-busybox-uboot/fip.bin"
uboot_url="$linaro_release/fvp-latest-busybox-uboot/bl33-uboot.bin"

rootfs_url="$linaro_release/lt-vexpress64-openembedded_minimal-armv8-gcc-5.2_20170127-761.img.gz"

# Default FVP model variables
default_model_dtb="dtb.bin"

# FVP containers and model paths
fvp_arm_std_library_11_24="fvp:fvp_arm_std_library_${model_version_11_24}_${model_build_11_24};/opt/model/FVP_ARM_Std_Library/FVP_Base"

fvp_arm_std_library="fvp:fvp_arm_std_library_${model_version}_${model_build};/opt/model/FVP_ARM_Std_Library/FVP_Base"
fvp_base_revc_2xaemva="fvp:fvp_base_revc-2xaemva_${model_version}_${model_build};/opt/model/Base_RevC_AEMvA_pkg/models/${model_flavour}"
fvp_base_aemv8r="fvp:fvp_base_aemv8r_${model_version}_${model_build};/opt/model/AEMv8R_base_pkg/models/${model_flavour}"

# CSS model list
fvp_morello="fvp:fvp_morello_0.11_33;/opt/model/FVP_Morello/models/Linux64_GCC-6.4"
fvp_rd_e1_edge="fvp:fvp_rd_e1_edge_${model_version}_${model_build};/opt/model/FVP_RD_E1_edge/models/${model_flavour}"
fvp_rd_n1_edge="fvp:fvp_rd_n1_edge_${model_version}_${model_build};/opt/model/FVP_RD_N1_edge/models/${model_flavour}"
fvp_rd_v1="fvp:fvp_rd_v1_${model_version}_${model_build};/opt/model/FVP_RD_V1/models/${model_flavour}"
fvp_tc1="fvp:fvp_tc1_${model_version}_${model_build};/opt/model/FVP_TC1/models/${model_flavour}"
fvp_tc2="fvp:fvp_tc2_11.23_17;/opt/model/FVP_TC2/models/${model_flavour}"

# FVP associate array, run_config are keys and fvp container parameters are the values
#   Container parameters syntax: <model name>;<model dir>;<model bin>
# FIXMEs: fix those ;;; values with real values

declare -A fvp_models
fvp_models=(
[base-aemv8a-revb]="${fvp_arm_std_library};FVP_Base_AEMvA-AEMvA"
[base-aemv8a-latest-revb]="${fvp_arm_std_library};FVP_Base_AEMvA-AEMvA"
[base-aemva]="${fvp_base_revc_2xaemva};FVP_Base_RevC-2xAEMvA"
[base-aemv8a]="${fvp_base_revc_2xaemva};FVP_Base_RevC-2xAEMvA"
[cortex-a32x4]="${fvp_arm_std_library};FVP_Base_Cortex-A32x4"
[cortex-a35x4]="${fvp_arm_std_library};FVP_Base_Cortex-A35x4"
[cortex-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A53x4"
[cortex-a55x4]="${fvp_arm_std_library};FVP_Base_Cortex-A55"
[cortex-a57x1-a53x1]="${fvp_arm_std_library};FVP_Base_Cortex-A57x1-A53x1"
[cortex-a57x2-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A57x2-A53x4"
[cortex-a57x4]="${fvp_arm_std_library};FVP_Base_Cortex-A57x4"
[cortex-a57x4-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A57x4-A53x4"
[cortex-a65aex8]="${fvp_arm_std_library_11_24};FVP_Base_Cortex-A65AE"
[cortex-a65x4]="${fvp_arm_std_library_11_24};FVP_Base_Cortex-A65"
[cortex-a72x4]="${fvp_arm_std_library};FVP_Base_Cortex-A72x4"
[cortex-a72x4-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A72x4-A53x4"
[cortex-a73x4]="${fvp_arm_std_library};FVP_Base_Cortex-A73x4"
[cortex-a73x4-a53x4]="${fvp_arm_std_library};FVP_Base_Cortex-A73x4-A53x4"
[cortex-a75x4]="${fvp_arm_std_library};FVP_Base_Cortex-A75"
[cortex-a76aex4]="${fvp_arm_std_library};FVP_Base_Cortex-A76AE"
[cortex-a76aex2]="${fvp_arm_std_library};FVP_Base_Cortex-A76AE"
[cortex-a76x4]="${fvp_arm_std_library};FVP_Base_Cortex-A76"
[cortex-a77x4]="${fvp_arm_std_library};FVP_Base_Cortex-A77"
[cortex-a78x4]="${fvp_arm_std_library};FVP_Base_Cortex-A78"
[cortex-a78aex4]="${fvp_arm_std_library};FVP_Base_Cortex-A78AE"
[cortex-a78cx4]="${fvp_arm_std_library};FVP_Base_Cortex-A78C"
[cortex-x2]="${fvp_arm_std_library};FVP_Base_Cortex-X2"
[cortex-a710x8]="${fvp_arm_std_library};FVP_Base_Cortex-A710"
[neoverse_e1]="${fvp_arm_std_library_11_24};FVP_Base_Neoverse-E1"
[neoverse_n1]="${fvp_arm_std_library};FVP_Base_Neoverse-N1"
[neoverse_n2]="${fvp_arm_std_library};FVP_Base_Neoverse-N2"
[neoverse-v1x4]="${fvp_arm_std_library};FVP_Base_Neoverse-V1"
[morello]="${fvp_morello};FVP_Morello"
[css-rde1edge]="${fvp_rd_e1_edge};FVP_RD_E1_edge"
[css-rdn1edgex2]="${fvp_rd_n1_edge};FVP_RD_N1_edge_dual"
[css-rdv1]="${fvp_rd_v1};FVP_RD_V1"
[tc1]="${fvp_tc1};FVP_TC1"
[tc2]="${fvp_tc2};FVP_TC2"
[baser-aemv8r]="${fvp_base_aemv8r};FVP_BaseR_AEMv8R"
)


# FVP Kernel URLs
declare -A kernel_list
kernel_list=(
[fvp-aarch32-zimage]="$linaro_release/fvp32-latest-busybox-uboot/Image"
[fvp-busybox-uboot]="$linaro_release/fvp-latest-busybox-uboot/Image"
[fvp-oe-uboot32]="$linaro_release/fvp32-latest-oe-uboot/Image"
[fvp-oe-uboot]="$linaro_release/fvp-latest-oe-uboot/Image"
[fvp-quad-busybox-uboot]="$tfa_downloads/quad_cluster/Image"
)

# FVP initrd URLs
declare -A initrd_list
initrd_list=(
[aarch32-ramdisk]="$linaro_release/fvp32-latest-busybox-uboot/ramdisk.img"
[dummy-ramdisk]="$linaro_release/fvp-latest-oe-uboot/ramdisk.img"
[dummy-ramdisk32]="$linaro_release/fvp32-latest-oe-uboot/ramdisk.img"
[default]="$linaro_release/fvp-latest-busybox-uboot/ramdisk.img"
)

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


# Generates the final YAML-based LAVA job definition from a template file.
#
# The job definition template is expanded with visibility of all variables that
# are available from within the function, including those with local scope.
gen_fvp_yaml() {
    local model="${model:?}"

    local yaml_template_file="$workspace/fvp_template.yaml"
    local yaml_file="$workspace/fvp.yaml"
    local yaml_job_file="$workspace/job.yaml"
    local lava_model_params="$workspace/lava_model_params"

    # this function expects a template, quit if it is not present
    if [ ! -f "$yaml_template_file" ]; then
        echo "warning: gen_fvp_yaml: template $yaml_template_file not available, skipping generating LAVA job"
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

    if [ -n "${GERRIT_CHANGE_NUMBER}" ]; then
        local gerrit_url="https://review.trustedfirmware.org/c/${GERRIT_CHANGE_NUMBER}/${GERRIT_PATCHSET_NUMBER}"
    elif [ -n "${GERRIT_REFSPEC}" ]; then
        local gerrit_url=$(echo ${GERRIT_REFSPEC} |
            awk -F/ '{print "https://review.trustedfirmware.org/c/" $4 "/" $5}')
    fi

    docker_registry="${docker_registry:-}"
    docker_registry="$(docker_registry_append)"
    docker_name="${docker_registry}$model_name"
    prompt1='/ #'
    prompt2='root@genericarmv8:~#'
    version_string="\"Fast Models"' [^\\n]+'"\""

    test_config="${TEST_CONFIG}"

    declare -A fvp_artefact_filters=(
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
        [ete_trace]="libete-plugin.so"
        [etm_trace]="ETMv4ExamplePlugin.so"
        [fip_gpt]="fip_gpt.bin"
        [fip]="fip.bin"
        [fvp_spmc_manifest_dtb]="=fvp_spmc_manifest.dtb"
        [fwu_fip]="fwu_fip.bin"
        [generic_trace]="GenericTrace.so"
        [hafnium]="hafnium.bin"
        [image]="kernel.bin"
        [ivy]="ivy.pkg"
        [manifest_dtb]="=manifest.dtb"
        [mcp_fw]="mcp_fw.bin"
        [mcp_ram]="mcp_ram.bin"
        [mcp_rom_hyphen]="mcp-rom.bin"
        [mcp_rom]="mcp_rom.bin"
        [ns_bl1u]="ns_bl1u.bin"
        [ns_bl2u]="ns_bl2u.bin"
        [ramdisk]="initrd.bin|initrd.img"
        [romlib]="romlib.bin"
        [rootfs]="rootfs.bin"
        [host_flash_fip]="host_flash_fip.bin"
        [rss_rom]="rss_rom.bin"
        [rss_encrypted_cm_provisioning_bundle_0]="rss_encrypted_cm_provisioning_bundle_0.bin"
        [rss_encrypted_dm_provisioning_bundle]="rss_encrypted_dm_provisioning_bundle.bin"
        [scp_fw]="scp_fw.bin"
        [scp_ram_hyphen]="scp-ram.bin"
        [scp_ram]="scp_ram.bin"
        [scp_rom_hyphen]="scp-rom.bin"
        [scp_rom]="scp_rom.bin"
        [secure_hafnium]="secure_hafnium.bin"
        [spm]="spm.bin"
        [tc_fitimage]="tc_fitimage.bin"
        [tftf]="tftf.bin"
        [tmp]="tmp.bin"
        [uboot]="uboot.bin"
    )

    declare -A fvp_artefact_urls=(
        [backup_fip]="$(gen_bin_url backup_fip.bin)"
        [bl1]="$(gen_bin_url bl1.bin)"
        [bl2]="$(gen_bin_url bl2.bin)"
        [bl31]="$(gen_bin_url bl31.bin)"
        [bl32]="$(gen_bin_url bl32.bin)"
        [busybox]="$(gen_bin_url busybox.bin.gz)"
        [cactus_primary]="$(gen_bin_url cactus-primary.pkg)"
        [cactus_secondary]="$(gen_bin_url cactus-secondary.pkg)"
        [cactus_tertiary]="$(gen_bin_url cactus-tertiary.pkg)"
        [coverage_trace_plugin]="${coverage_trace_plugin}"
        [dtb]="$(gen_bin_url ${model_dtb})"
        [el3_payload]="$(gen_bin_url el3_payload.bin)"
        [ete_trace]="${tfa_downloads}/FastModelsPortfolio_${model_version}/plugins/${model_flavour}/libete-plugin.so"
        [etm_trace]="${tfa_downloads}/FastModelsPortfolio_${model_version}/plugins/${model_flavour}/ETMv4ExamplePlugin.so"
        [fip]="$(gen_bin_url fip.bin)"
        [fip_gpt]="$(gen_bin_url fip_gpt.bin)"
        [fvp_spmc_manifest_dtb]="$(gen_bin_url fvp_spmc_manifest.dtb)"
        [fwu_fip]="$(gen_bin_url fwu_fip.bin)"
        [generic_trace]="${tfa_downloads}/FastModelsPortfolio_${model_version}/plugins/${model_flavour}/GenericTrace.so"
        [hafnium]="$(gen_bin_url hafnium.bin)"
        [image]="$(gen_bin_url kernel.bin)"
        [ivy]="$(gen_bin_url ivy.pkg)"
        [manifest_dtb]="$(gen_bin_url manifest.dtb)"
        [mcp_fw]="$(gen_bin_url mcp_fw.bin)"
        [mcp_ram]="$(gen_bin_url mcp_ram.bin)"
        [mcp_rom]="$(gen_bin_url mcp_rom.bin)"
        [mcp_rom_hyphen]="$(gen_bin_url mcp-rom.bin)"
        [ns_bl1u]="$(gen_bin_url ns_bl1u.bin)"
        [ns_bl2u]="$(gen_bin_url ns_bl2u.bin)"
        [ramdisk]="$(gen_bin_url initrd.bin)"
        [romlib]="$(gen_bin_url romlib.bin)"
        [rootfs]="$(gen_bin_url rootfs.bin.gz)"
        [host_flash_fip]="$(gen_bin_url host_flash_fip.bin)"
        [rss_rom]="$(gen_bin_url rss_rom.bin)"
        [rss_encrypted_cm_provisioning_bundle_0]="$(gen_bin_url rss_encrypted_cm_provisioning_bundle_0.bin)"
        [rss_encrypted_dm_provisioning_bundle]="$(gen_bin_url rss_encrypted_dm_provisioning_bundle.bin)"
        [secure_hafnium]="$(gen_bin_url secure_hafnium.bin)"
        [scp_fw]="$(gen_bin_url scp_fw.bin)"
        [scp_ram]="$(gen_bin_url scp_ram.bin)"
        [scp_ram_hyphen]="$(gen_bin_url scp-ram.bin)"
        [scp_rom]="$(gen_bin_url scp_rom.bin)"
        [scp_rom_hyphen]="$(gen_bin_url scp-rom.bin)"
        [spm]="$(gen_bin_url spm.bin)"
        [tc_fitimage]="$(gen_bin_url tc_fitimage.bin)"
        [tftf]="$(gen_bin_url tftf.bin)"
        [tmp]="$(gen_bin_url tmp.bin)"
        [uboot]="$(gen_bin_url uboot.bin)"
    )

    # In LAVA we don't provide the paths to the artefacts directly, but instead
    # use macros of the form `{XYZ}`. This is a list of regular expression
    # replacements to run on the model parameters file before we add them to the
    # LAVA job definition.
    declare -A fvp_artefact_macros=(
        ["[= ]backup_fip.bin"]="={BACKUP_FIP}"
        ["[= ]bl1.bin"]="={BL1}"
        ["[= ]bl2.bin"]="={BL2}"
        ["[= ]bl31.bin"]="={BL31}"
        ["[= ]bl32.bin"]="={BL32}"
        ["[= ]cactus-primary.pkg"]="={CACTUS_PRIMARY}"
        ["[= ]cactus-secondary.pkg"]="={CACTUS_SECONDARY}"
        ["[= ]cactus-tertiary.pkg"]="={CACTUS_TERTIARY}"
        ["[= ].*coverage_trace.so"]="={COVERAGE_TRACE_PLUGIN}"
        ["[= ]fvp_spmc_manifest.dtb"]="={FVP_SPMC_MANIFEST_DTB}"
        ["[= ]busybox.bin"]="={BUSYBOX}"
        ["[= ]dtb.bin"]="={DTB}"
        ["[= ]el3_payload.bin"]="={EL3_PAYLOAD}"
        ["[= ].*libete-plugin.so"]="={ETE_TRACE}"
        ["[= ].*ETMv4ExamplePlugin.so"]="={ETM_TRACE}"
        ["[= ]fip_gpt.bin"]="={FIP_GPT}"
        ["[= ]fwu_fip.bin"]="={FWU_FIP}"
        ["[= ]fip.bin"]="={FIP}"
        ["[= ].*GenericTrace.so"]="={GENERIC_TRACE}"
        ["[= ].*/hafnium.bin"]="={HAFNIUM}"
        ["[= ]kernel.bin"]="={IMAGE}"
        ["[= ]ivy.pkg"]="={IVY}"
        ["[= ]manifest.dtb"]="={MANIFEST_DTB}"
        ["[= ]mcp_fw.bin"]="={MCP_FW}"
        ["[= ]mcp_ram.bin"]="={MCP_RAM}"
        ["[= ]mcp_rom.bin"]="={MCP_ROM}"
        ["[= ]mcp-rom.bin"]="={MCP_ROM_HYPHEN}"
        ["[= ]ns_bl1u.bin"]="={NS_BL1U}"
        ["[= ]ns_bl2u.bin"]="={NS_BL2U}"
        ["[= ]initrd.bin"]="={RAMDISK}"
        ["[= ]initrd.img"]="={RAMDISK}"
        ["[= ]romlib.bin"]="={ROMLIB}"
        ["[= ]rootfs.bin"]="={ROOTFS}"
        ["[= ]host_flash_fip.bin"]="={HOST_FLASH_FIP}"
        ["[= ]rss_rom.bin"]="={RSS_ROM}"
        ["[= ]rss_encrypted_cm_provisioning_bundle_0.bin"]="={RSS_ENCRYPTED_CM_PROVISIONING_BUNDLE_0}"
        ["[= ]rss_encrypted_dm_provisioning_bundle.bin"]="={RSS_ENCRYPTED_DM_PROVISIONING_BUNDLE}"
        ["[= ].*/secure_hafnium.bin"]="={SECURE_HAFNIUM}"
        ["[= ]scp_fw.bin"]="={SCP_FW}"
        ["[= ]scp_ram.bin"]="={SCP_RAM}"
        ["[= ]scp-ram.bin"]="={SCP_RAM_HYPHEN}"
        ["[= ]scp_rom.bin"]="={SCP_ROM}"
        ["[= ]scp-rom.bin"]="={SCP_ROM_HYPHEN}"
        ["[= ]spm.bin"]="={SPM}"
        ["[= ]tc_fitimage.bin"]="={TC_FITIMAGE}"
        ["[= ]tftf.bin"]="={TFTF}"
        ["[= ].*/tmp.bin"]="={TMP}"
        ["[= ]uboot.bin"]="={UBOOT}"
    )

    declare -a fvp_artefacts
    filter_artefacts fvp_artefacts fvp_artefact_filters

    lava_model_params="${lava_model_params}" \
      gen_lava_model_params fvp_artefact_macros

    yaml_template_file="$yaml_template_file" \
    yaml_file="$yaml_file" \
    yaml_job_file="$yaml_job_file" \
      gen_lava_job_def fvp_artefacts fvp_artefact_urls
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
           echo "FIP binary ($bin_size bytes) larger than max partition 1" \
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

#corrupt GPT image header and archive it
corrupt_gpt_bin() {
    bin="${1:?}"

    # Primary GPT header is present in LBA-1 second block after MBR
    # empty the primary GPT header forcing to use backup GPT header
    # and backup GPT entries.
    dd if=/dev/zero of=$bin bs=512 seek=1 count=1 conv=notrunc
}

set +u
