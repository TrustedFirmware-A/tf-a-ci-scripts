#
# Copyright (c) 2019-2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This file contains common model controls and parameters across *ALL* FVP
# models.

default_var pctl_startup 0.0.0.0
default_var quantum 1000
default_var data_instance cluster0.cpu0
default_var cache_state_modelled 1
default_var print_stat 1
# Trace unit functionally works in FVP model by enabling ETM/ETE trace
# unit along with its plugin.
# Hence disabled ETM by default, and enable it along with its plugin whenever
# needed.
default_var etm_present 0

reset_var has_bl1
reset_var has_fip
reset_var preload_bl33
reset_var reset_to_bl31
reset_var reset_to_spmin
reset_var secure_memory
reset_var secure_ram_fill
reset_var wait_debugger
reset_var cluster_0_num_cores


if [ "$bl2_at_el3" ]; then
	has_fip=1
elif [ "$fip_as_gpt" ]; then
	has_bl1=1
elif [ -z "$reset_to_spmin" -a -z "$reset_to_bl31" ]; then
	has_bl1=1
	has_fip=1
fi

cat <<EOF >"$model_param_file"

-C bp.ve_sysregs.exit_on_shutdown=1
-C pctl.startup=$pctl_startup

${wait_debugger+-I -p}

${secure_memory+-C bp.secure_memory=$secure_memory}
${cache_state_modelled+-C cache_state_modelled=$cache_state_modelled}
${use_pchannel_for_threads+-C pctl.use_pchannel_for_threads=$use_pchannel_for_threads}

${secure_ram_fill+-C bp.secureSRAM.fill1=0x00000000}
${secure_ram_fill+-C bp.secureSRAM.fill2=0x00000000}

${bl2_at_el3+--data ${data_instance}=$bl2_bin@${bl2_addr:?}}

${cluster_0_num_cores+-C cluster0.NUM_CORES=$cluster_0_num_cores}

${reset_to_bl31+--data ${data_instance}=$bl31_bin@${bl31_addr:?}}
${preload_bl33+--data ${data_instance}=$preload_bl33_bin@${bl33_addr:?}}

${reset_to_spmin+--data ${data_instance}=$bl32_bin@${bl32_addr:?}}
${reset_to_spmin+--data ${data_instance}=$uboot_bin@${bl33_addr:?}}

${memprotect+--data ${data_instance}=$memprotect@${memprotect_addr:?}}
${romlib_bin+--data ${data_instance}=$romlib_bin@${romlib_addr:?}}

${has_bl1+-C bp.secureflashloader.fname=$bl1_bin}
${has_fip+-C bp.flashloader0.fname=$fip_bin}
${fip_as_gpt+-C bp.flashloader0.fname=$fip_gpt_bin}

${dtb_bin+--data ${data_instance}=$dtb_bin@${dtb_addr:?}}
${kernel_bin+--data ${data_instance}=$kernel_bin@${kernel_addr:?}}
${initrd_bin+--data ${data_instance}=$initrd_bin@${initrd_addr:?}}
${boot_script_bin+--data ${data_instance}=$boot_script_bin@${boot_script_addr:?}}

${spm_bin+--data ${data_instance}=$spm_bin@${spm_addr:?}}
${spmc_manifest+--data ${data_instance}=$spmc_manifest@${spmc_manifest_addr:?}}
${sp1_pkg+--data ${data_instance}=$sp1_pkg@${sp1_addr:?}}
${sp2_pkg+--data ${data_instance}=$sp2_pkg@${sp2_addr:?}}
${sp3_pkg+--data ${data_instance}=$sp3_pkg@${sp3_addr:?}}
${sp4_pkg+--data ${data_instance}=$sp4_pkg@${sp4_addr:?}}

${ns_bl1u_bin+--data ${data_instance}=$ns_bl1u_bin@$ns_bl1u_addr}
${fwu_fip_bin+--data ${data_instance}=$fwu_fip_bin@$fwu_fip_addr}
${backup_fip_bin+--data ${data_instance}=$backup_fip_bin@$backup_fip_addr}

${flashloader1_bin+-C bp.flashloader1.fname=$flashloader1_bin}
${rootfs_bin+-C bp.virtioblockdevice.image_path=$rootfs_bin}

${uart0_out+-C bp.pl011_uart0.out_file=$uart0_out}
${uart0_out+-C bp.pl011_uart0.unbuffered_output=1}
${uart1_out+-C bp.pl011_uart1.out_file=$uart1_out}

${no_quantum--Q ${quantum}}

${disable_visualisation+-C bp.vis.disable_visualisation=1}

EOF

# OpenCI uses LAVA to launch models, the latter requiring (uart) unbuffered output,
# otherwise these may get full and models hang.
if ! is_arm_jenkins_env && not_upon "$local_ci"; then
	cat <<EOF >>"$model_param_file"
-C bp.pl011_uart0.unbuffered_output=1
-C bp.pl011_uart1.unbuffered_output=1
-C bp.pl011_uart2.unbuffered_output=1
-C bp.pl011_uart3.unbuffered_output=1
EOF
fi

if [ "$print_stat" = "1" ]; then
	cat <<EOF >>"$model_param_file"
--stat
EOF
fi

# TFTF: There are two scenarions where simulation should be shutdown
# when a EOT (ASCII 4) char is transmitted: on local or some OpenCI
# runs. In the latter case, shutdown is required for code coverage
# runs, so that FVP trace log was properly dumped (and parsed by LAVA).
# Don't use it for other OpenCI runs, as it may lead to race condition
# with LAVA's capturing of FVP output.
if echo "$RUN_CONFIG" | grep -Eiq 'tftf|spm|next'; then
    is_arm_env=0
    if is_arm_jenkins_env; then
        is_arm_env=1
    fi

    if [ "$is_arm_env" == "0" -a "$COVERAGE_ON" == "1" ] || upon "$local_ci"; then
	cat <<EOF >>"$model_param_file"
-C bp.pl011_uart0.shutdown_on_eot=1
EOF
    fi
fi
