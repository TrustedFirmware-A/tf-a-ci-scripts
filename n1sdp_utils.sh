#!/usr/bin/env bash
#
# Copyright (c) 2021-2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

n1sdp_release="N1SDP-2022.06.22"
n1sdp_prebuilts=${n1sdp_prebuilts:="$tfa_downloads/css/n1sdp/$n1sdp_release"}
scp_mcp_prebuilts=${scp_mcp_prebuilts:="$n1sdp_prebuilts"}

get_n1sdp_firmware() {
        url=$n1sdp_firmware_bin_url saveas="n1sdp-board-firmware.zip" fetch_file
        archive_file "n1sdp-board-firmware.zip"
}

fetch_prebuilt_fw_images() {
        url="$n1sdp_prebuilts/n1sdp-board-firmware.zip" filename="n1sdp-board-firmware.zip" \
                fetch_and_archive

        #Fetch pre-built SCP/MCP binaries if they haven't been built
        url="$scp_mcp_prebuilts/mcp_romfw.bin" filename="mcp_rom.bin" \
                fetch_and_archive
        url="$scp_mcp_prebuilts/scp_romfw.bin" filename="scp_rom.bin" \
                fetch_and_archive
        url="$scp_mcp_prebuilts/scp_ramfw.bin" filename="scp_ram.bin" \
                fetch_and_archive
        url="$scp_mcp_prebuilts/mcp_ramfw.bin" filename="mcp_ram.bin" \
                fetch_and_archive
}

gen_recovery_image() {
        local zip_dir="$workspace/$mode/n1sdp-board-firmware_primary"
        local zip_file="${zip_dir}.zip"

        mkdir -p "$zip_dir"

        extract_tarball "$archive/n1sdp-board-firmware.zip" "$zip_dir"

        scp_uuid="cfacc2c4-15e8-4668-82be-430a38fad705"
        mcp_uuid="54464222-a4cf-4bf8-b1b6-cee7dade539e"

	fiptool=$(fiptool_path)
        # Create FIP for SCP
        "$fiptool" create --blob \
                uuid=$scp_uuid,file=$tf_build_root/n1sdp/$bin_mode/bl1.bin \
                --scp-fw "$archive/scp_ram.bin" "scp_fw.bin"

        archive_file "scp_fw.bin"

        # Create FIP for MCP, this needs fixed uuid for now
        "$fiptool" create --blob \
                uuid=$mcp_uuid,file="$archive/mcp_ram.bin" "mcp_fw.bin"

        archive_file "mcp_fw.bin"

        cp -Rp --no-preserve=ownership "$archive/mcp_fw.bin" "$zip_dir/SOFTWARE"
        cp -Rp --no-preserve=ownership "$archive/mcp_rom.bin" "$zip_dir/SOFTWARE"
        cp -Rp --no-preserve=ownership "$archive/scp_fw.bin" "$zip_dir/SOFTWARE"
        cp -Rp --no-preserve=ownership "$archive/scp_rom.bin" "$zip_dir/SOFTWARE"
        cp -Rp --no-preserve=ownership "$archive/fip.bin" "$zip_dir/SOFTWARE"

        (cd "$zip_dir" && zip -rq "$zip_file" -x \.* -- *)

        archive_file "$zip_file"
}

gen_n1sdp_yaml() {
        yaml_template_file="$workspace/n1sdp_template.yaml"
        yaml_file="$workspace/n1sdp.yaml"
        yaml_job_file="$workspace/job.yaml"

        # this function expects a template, quit if it is not present
        if [ ! -f "$yaml_template_file" ]; then
                return
        fi

        yaml_template_file="$yaml_template_file" \
        yaml_file="$yaml_file" \
        yaml_job_file="$yaml_job_file" \
        recovery_img_url="$(gen_bin_url n1sdp-board-firmware_primary.zip)" \
                gen_lava_job_def
}
