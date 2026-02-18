#!/usr/bin/env bash
#
# Copyright (c) 2020-2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

post_tf_build() {
	url="$DOWNLOAD_SERVER_TF_A_URL/spm/07-29-2021/spmc_sel2_optee_sel1.bin" fetch_file

	archive_file "spmc_sel2_optee_sel1.bin"
	cp "${archive}/spmc_sel2_optee_sel1.bin" "${archive}/build/tfa/fvp/${bin_mode}"

	cat <<-EOF >"${archive}/build/tfa/fvp/${bin_mode}/optee_sp_layout.json"
		{
			"op-tee" : {
				"image": "spmc_sel2_optee_sel1.bin",
				"pm": "${tf_root}/plat/arm/board/fvp/fdts/optee_sp_manifest.dts"
			}
		}
	EOF

	build_fip BL33="$archive/tftf.bin" BL32="$archive/secure_hafnium.bin"
}

generate_lava_job_template() {
	payload_type="tftf" gen_yaml_template
}

generate_lava_job() {
	local model="base-aemv8a"

	uart="0" file="tftf.exp" track_expect
	uart="1" file="spm-optee-sp-uart1.exp" track_expect

	model="$model" \
		arch_version="8.5" \
		has_branch_target_exception="1" \
		has_smmuv3_params="1" \
		memory_tagging_support_level="2" \
		gicd_are_fixed_one="1" \
		gicv3_ext_interrupt_range="1" \
		gicd_ext_ppi_count="64" \
		gicd_ext_spi_count="1024" \
		gen_model_params

	model="$model" gen_fvp_yaml
}
