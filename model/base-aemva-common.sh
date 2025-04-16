#!/usr/bin/env bash
#
# Copyright (c) 2019-2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

reset_var cluster_0_has_el2
reset_var cluster_1_has_el2

reset_var cluster_0_reg_reset
reset_var cluster_1_reg_reset

reset_var cluster_0_num_cores
reset_var cluster_1_num_cores

reset_var aarch64_only
reset_var aarch32

reset_var plat_variant

reset_var pa_size

#------------ GIC configuration --------------

# GICv2 compatibility is not supported and GICD_CTLR.ARE_* is always one
reset_var gicd_are_fixed_one

# Number of extended PPI supported: Default 0, Maximum 64
reset_var gicd_ext_ppi_count

# Number of extended SPI supported: Default 0, Maximum 1024
reset_var gicd_ext_spi_count

# Number of Interrupt Translation Services to be instantiated (0=none)
reset_var gicd_its_count

# GICv4 Virtual LPIs and Direct injection of Virtual LPIs supported
reset_var gicd_virtual_lpi

# Device has support for extended SPI/PPI ID ranges
reset_var gicv3_ext_interrupt_range

# When using the GICv3 model, pretend to be a GICv2 system
reset_var gicv3_gicv2_only

# Number of SPIs that are implemented: Default 224, Maximum 988
reset_var gicv3_spi_count

reset_var has_ete

# Enable GICv4.1 functionality
reset_var has_gicv4_1

reset_var has_sve

reset_var has_sme

reset_var has_sme_fa64

reset_var sme_only

reset_var has_sme2

reset_var bmcov_plugin

reset_var retain_flash

reset_var nvcounter_version
reset_var nvcounter_diag

# Enable FEAT_MPAM
reset_var has_mpam

# Enable SMMUv3 functionality
reset_var has_smmuv3_params

# Enable FEAT_RME
reset_var has_rme

# Enable FEAT_RNG
reset_var has_rng

# Enable FEAT_RNG_TRAP
reset_var has_rng_trap

# Enable FEAT_ECV
reset_var has_ecv

# Enable FEAT_S1PIE
reset_var has_s1pie

# Enable FEAT_S2PIE
reset_var has_s2pie

# Enable FEAT_S1POE
reset_var has_s1poe

# Enable FEAT_S2POE
reset_var has_s2poe

# Enable FEAT_TCR2
reset_var has_tcr2

# Enable FEAT_CSV2_2
reset_var has_csv2_2

# Enable FEAT_GCS
reset_var has_gcs

# Enable FEAT_FGT2
reset_var has_fgt2

# Layout of MPIDR. 0=AFF0 is CPUID, 1=AFF1 is CPUID
reset_var mpidr_layout

# Sets the MPIDR.MT bit. Setting this to true hints the cluster
# is multi-threading compatible
reset_var supports_multi_threading

# ETM plugin to access ETM trace system registers
reset_var etm_plugin

# Trace filter register support
reset_var supports_trace_filter_regs

# Trace buffer control register support
reset_var supports_trace_buffer_control_regs

# CRC32 support
reset_var supports_crc32

# Accelerator instruction support level (none, FEAT_LS64,
# FEAT_LS64_V, FEAT_LS64_ACCDATA)
reset_var accelerator_support_level

# ROTPK in trusted register space
reset_var has_rotpk_in_regs

source "$ci_root/model/fvp_common.sh"

#------------ Common configuration --------------

cat <<EOF >>"$model_param_file"
${gicv3_gicv2_only+-C gicv3.gicv2-only=$gicv3_gicv2_only}
${gicv3_spi_count+-C gic_distributor.SPI-count=$gicv3_spi_count}
${gicd_are_fixed_one+-C gic_distributor.ARE-fixed-to-one=$gicd_are_fixed_one}
${gicd_ext_ppi_count+-C gic_distributor.extended-ppi-count=$gicd_ext_ppi_count}
${gicd_ext_spi_count+-C gic_distributor.extended-spi-count=$gicd_ext_spi_count}
${gicd_its_count+-C gic_distributor.ITS-count=$gicd_its_count}
${gicd_virtual_lpi+-C gic_distributor.virtual-lpi-support=$gicd_virtual_lpi}
${has_gicv4_1+-C has-gicv4.1=$has_gicv4_1}

${has_ete+-C cluster0.has_ete=1}
${has_sve+-C cluster0.has_sve=1}
${has_sve+-C cluster0.sve.veclen=$((128 / 8))}
${has_sme+-C cluster0.sve.has_sme=1}
${has_sme2+-C cluster0.sve.has_sme2=1}
${has_sme_fa64+-C cluster0.sve.has_sme_fa64=1}
${sme_only+-C cluster0.sve.sme_only=1}

${has_ete+-C cluster1.has_ete=1}
${has_sve+-C cluster1.has_sve=1}
${has_sve+-C cluster1.sve.veclen=$((128 / 8))}
${has_sme+-C cluster1.sve.has_sme=1}
${has_sme2+-C cluster1.sve.has_sme2=1}
${has_sme_fa64+-C cluster1.sve.has_sme_fa64=1}
${sme_only+-C cluster1.sve.sme_only=1}

${bmcov_plugin+--plugin=$bmcov_plugin_path}

${nvcounter_version+-C bp.trusted_nv_counter.version=$nvcounter_version}
${nvcounter_diag+-C bp.trusted_nv_counter.diagnostics=$nvcounter_diag}

${etm_plugin+--plugin=$etm_plugin_path}
EOF

# Store the fixed ROTPK hash in registers
# Note: This is the SHA256 hash of the RSA 2K development public key used in TF-A
if [ "$has_rotpk_in_regs" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C bp.trusted_key_storage.public_key="0982f3b0 3ad89712 47727a37 7332ec1b e23292e9 5ef65949 464a4a8b da9a22d8"
EOF
fi

# TFTF Reboot/Shutdown tests
if [ "$retain_flash" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C bp.flashloader1.fname=$flashloader1_fwrite
-C bp.flashloader1.fnameWrite=$flashloader1_fwrite
-C bp.flashloader0.fnameWrite=$flashloader0_fwrite
-C bp.pl011_uart0.untimed_fifos=1
-C bp.ve_sysregs.mmbSiteDefault=0
EOF
fi

# Enable RME at the system level
if [ "$has_rme" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C bp.refcounter.non_arch_start_at_default=1
-C bp.refcounter.use_real_time=0
-C bp.has_rme=1
EOF
fi

# MTE is enabled
if [[ -n $memory_tagging_support_level ]]; then
	cat <<EOF >>"$model_param_file"
-C bp.dram_metadata.is_enabled=1
EOF
fi

# If accelerator support level enabled, disable bitwise negation
# for values stored/read using FEAT_LS64* instructions.
if [ "$accelerator_support_level" != "0" ]; then
	cat <<EOF >>"$model_param_file"
-C bp.ls64_testing_fifo.op_type=0
EOF
fi

#------------ Cluster0 configuration --------------

cat <<EOF >>"$model_param_file"
${pa_size+-C cluster0.PA_SIZE=$pa_size}

${cluster_0_reg_reset+-C cluster0.register_reset_data=$cluster_0_reg_reset}

${cluster_0_has_el2+-C cluster0.has_el2=$cluster_0_has_el2}

${amu_present+-C cluster0.has_amu=$amu_present}
${amu_version+-C cluster0.amu_version=${amu_version}}

${reset_to_bl31+-C cluster0.cpu0.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu1.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu2.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu3.RVBAR=${bl31_addr:?}}

${reset_to_spmin+-C cluster0.cpu0.RVBAR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu1.RVBAR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu2.RVBAR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu3.RVBAR=${bl32_addr:?}}

${cluster_0_num_cores+-C cluster0.NUM_CORES=$cluster_0_num_cores}

${el3_payload_bin+--data cluster0.cpu0=$el3_payload_bin@${el3_payload_addr:?}}

${aarch64_only+-C cluster0.max_32bit_el=-1}

${aarch32+-C cluster0.cpu0.CONFIG64=0}
${aarch32+-C cluster0.cpu1.CONFIG64=0}
${aarch32+-C cluster0.cpu2.CONFIG64=0}
${aarch32+-C cluster0.cpu3.CONFIG64=0}


${bl2_at_el3+-C cluster0.cpu0.RVBAR=${bl2_addr:?}}
${bl2_at_el3+-C cluster0.cpu1.RVBAR=${bl2_addr:?}}
${bl2_at_el3+-C cluster0.cpu2.RVBAR=${bl2_addr:?}}
${bl2_at_el3+-C cluster0.cpu3.RVBAR=${bl2_addr:?}}

${memory_tagging_support_level+-C cluster0.memory_tagging_support_level=$memory_tagging_support_level}

${has_branch_target_exception+-C cluster0.has_branch_target_exception=$has_branch_target_exception}

${restriction_on_speculative_execution+-C cluster0.restriction_on_speculative_execution=$restriction_on_speculative_execution}

${restriction_on_speculative_execution+-C cluster0.restriction_on_speculative_execution_aarch32=$restriction_on_speculative_execution}

${gicv3_ext_interrupt_range+-C cluster0.gicv3.extended-interrupt-range-support=$gicv3_ext_interrupt_range}

${mpidr_layout+-C cluster0.mpidr_layout=$mpidr_layout}

${supports_multi_threading+-C cluster0.supports_multi_threading=$supports_multi_threading}

${has_v8_9_debug_extension+-C cluster0.has_v8_9_debug_extension=$has_v8_9_debug_extension}

${etm_present+-C cluster0.cpu0.etm-present=$etm_present}
${etm_present+-C cluster0.cpu1.etm-present=$etm_present}
${etm_present+-C cluster0.cpu2.etm-present=$etm_present}
${etm_present+-C cluster0.cpu3.etm-present=$etm_present}
${supports_trace_filter_regs+-C cluster0.has_self_hosted_trace_extension=$supports_trace_filter_regs}
${supports_trace_buffer_control_regs+-C cluster0.has_trbe=$supports_trace_buffer_control_regs}
${supports_branch_record_buffer_control_regs+-C cluster0.has_brbe=$supports_branch_record_buffer_control_regs}
${supports_crc32+-C cluster0.cpu0.enable_crc32=$supports_crc32}
${supports_crc32+-C cluster0.cpu1.enable_crc32=$supports_crc32}
${supports_crc32+-C cluster0.cpu2.enable_crc32=$supports_crc32}
${supports_crc32+-C cluster0.cpu3.enable_crc32=$supports_crc32}

${cache_state_modelled+-C cluster0.stage12_tlb_size=1024}
${cache_state_modelled+-C cluster0.check_memory_attributes=0}

EOF

if [ "$has_smmuv3_params" = "1" ]; then
		cat <<EOF >>"$model_param_file"
-C pci.pci_smmuv3.mmu.SMMU_AIDR=2
-C pci.pci_smmuv3.mmu.SMMU_IDR1=0x00600002
-C pci.pci_smmuv3.mmu.SMMU_IDR3=0x1714
-C pci.pci_smmuv3.mmu.SMMU_S_IDR1=0xA0000002
-C pci.pci_smmuv3.mmu.SMMU_S_IDR2=0
-C pci.pci_smmuv3.mmu.SMMU_S_IDR3=0
-C pci.smmulogger.trace_debug=1
-C pci.smmulogger.trace_snoops=1
-C pci.tbu0_pre_smmu_logger.trace_snoops=1
-C pci.tbu0_pre_smmu_logger.trace_debug=1
-C pci.pci_smmuv3.mmu.all_error_messages_through_trace=1
-C TRACE.GenericTrace.trace-sources=verbose_commentary,smmu_initial_transaction,smmu_final_transaction,*.pci.pci_smmuv3.mmu.*,*.pci.smmulogger.*,*.pci.tbu0_pre_smmu_logger.*,smmu_poison_tw_data
--plugin $warehouse/SysGen/PVModelLib/$model_version/$model_build/external/plugins/$model_flavour/GenericTrace.so
-C cci550.force_on_from_start=1
EOF

# If RME is implemented:
# * pci.pci_smmuv3.mmu.SMMU_IDR5 defines 48 bit physical address size aligned
#   with the model configuration for the PE.
# * pci.pci_smmuv3.mmu.root_register_page_offset defines the (platform
#   dependent) SMMU Root register page offset.
# * SMMU_IDR0.RME_IMPL=1: RME features supported for non-secure and secure
#   programming interface.
# * pci.pci_smmuv3.mmu.SMMU_ROOT_IDR0=3: ROOT_IMPL=1/BGPTM=1.
# * pci.pci_smmuv3.mmu.SMMU_ROOT_IIDR=0x43B: JEP106 Arm implementer code.
	if [ "$has_rme" = "1" ]; then
		cat <<EOF >>"$model_param_file"
-C pci.pci_smmuv3.mmu.SMMU_IDR0=0x4046123b
-C pci.pci_smmuv3.mmu.SMMU_IDR5=0xFFFF0475
-C pci.pci_smmuv3.mmu.SMMU_ROOT_IDR0=3
-C pci.pci_smmuv3.mmu.SMMU_ROOT_IIDR=0x43B
-C pci.pci_smmuv3.mmu.root_register_page_offset=0x20000
EOF
	else
		cat <<EOF >>"$model_param_file"
-C pci.pci_smmuv3.mmu.SMMU_IDR0=0x0046123B
EOF

                # Align pci.pci_smmuv3.mmu.SMMU_IDR5 to define 48 bit physical
                # address size as for the PE.
                if [ "$pa_size" = "48" ]; then
                    cat <<EOF >>"$model_param_file"
-C pci.pci_smmuv3.mmu.SMMU_IDR5=0xFFFF0475
EOF
                else
                    cat <<EOF >>"$model_param_file"
-C pci.pci_smmuv3.mmu.SMMU_IDR5=0xFFFF0472
EOF
	        fi
        fi
fi

# Parameters to select architecture version
if [ "$arch_version" = "8.3" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-3=1
EOF
fi

if [ "$arch_version" = "8.4" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-4=1
EOF
fi

if [ "$arch_version" = "8.5" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-5=1
EOF
fi

if [ "$arch_version" = "8.6" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-6=1
EOF
fi

if [ "$arch_version" = "8.7" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-7=1
EOF
fi

if [ "$arch_version" = "8.8" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-8=1
EOF
fi

if [ "$arch_version" = "8.9" ]; then
       cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v8-9=1
-C cluster1.has_arm_v8-9=1
EOF
fi

if [ "$arch_version" = "9.2" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v9-2=1
-C cluster1.has_arm_v9-2=1
EOF
fi

if [ "$arch_version" = "9.3" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v9-3=1
-C cluster1.has_arm_v9-3=1
EOF
fi

if [ "$arch_version" = "9.4" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_arm_v9-4=1
-C cluster1.has_arm_v9-4=1
EOF
fi

# Parameters for fault injection
if [ "$fault_inject" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.number_of_error_records=2
-C cluster0.has_ras=2
-C cluster0.error_record_feature_register='{"INJ":0x1,"ED":0x1,"UI":0x0,"FI":0x0,"UE":0x1,"CFI":0x0,"CEC":0x0,"RP":0x0,"DUI":0x0,"CEO":0x0}'
-C cluster0.pseudo_fault_generation_feature_register='{"OF":false,"CI":false,"ER":false,"PN":false,"AV":false,"MV":false,"SYN":false,"UC":true,"UEU":true,"UER":false,"UEO":false,"DE":false,"CE":0,"R":false}'
EOF
fi

if [ "$has_mpam" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_mpam=2
-C cluster1.has_mpam=2
EOF
fi

# FEAT_RME is enabled for the PE, plus additional arch options
if [ "$has_rme" = "1" ]; then
        cat <<EOF >>"$model_param_file"
-C cluster0.rme_support_level=2
-C cluster0.gicv3.cpuintf-mmap-access-level=2
-C cluster0.gicv4.mask-virtual-interrupt=1
-C cluster0.gicv3.without-DS-support=1
-C cluster0.max_32bit_el=-1
-C cluster0.PA_SIZE=48
-C cluster0.output_attributes=ExtendedID[62:55]=MPAM_PMG,ExtendedID[54:39]=MPAM_PARTID,ExtendedID[38:37]=MPAM_SP
EOF
fi

# FEAT_BRBE is enabled
if [ "$has_brbe" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_brbe=1
EOF
fi

# FEAT_TRBE is enabled
if [ "$has_trbe" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_trbe=1
EOF
fi

# FEAT_PACQARMA3 is enabled
if [ "$has_pacqarma3" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_qarma3_pac=1
EOF
fi

# FEAT_RNG is enabled
if [ "$has_rng" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_rndr=1
EOF
fi

# FEAT_RNG_TRAP is enabled
if [ "$has_rng_trap" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_rndr_trap=1
EOF
fi

if [ "$has_fgt2" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_fgt2=2
-C cluster1.has_fgt2=2
EOF
fi

if [ "$has_ecv" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.ecv_support_level=2
-C cluster1.ecv_support_level=2
EOF
fi

if [ "$has_s1pie" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_permission_indirection_s1=2
-C cluster1.has_permission_indirection_s1=2
EOF
fi

if [ "$has_s2pie" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_permission_indirection_s2=2
-C cluster1.has_permission_indirection_s2=2
EOF
fi

if [ "$has_s1poe" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_permission_overlay_s1=2
-C cluster1.has_permission_overlay_s1=2
EOF
fi

if [ "$has_s2poe" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_permission_overlay_s2=2
-C cluster1.has_permission_overlay_s2=2
EOF
fi

if [ "$has_tcr2" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_tcr2=2
-C cluster1.has_tcr2=2
EOF
fi

if [ "$has_csv2_2" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.restriction_on_speculative_execution=2
-C cluster1.restriction_on_speculative_execution=2
EOF
fi

if [ "$has_gcs" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_gcs=2
-C cluster1.has_gcs=2
EOF
fi

# Accelerator support level enabled
if [ "$accelerator_support_level" != "0" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.arm_v8_7_accelerator_support_level="$accelerator_support_level"
EOF
fi

# FEAT_THE is enabled
if [ "$has_translation_hardening" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_translation_hardening=2
-C cluster1.has_translation_hardening=2
EOF
fi

# FEAT_D128 is enabled
if [ "$has_d128" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_128_bit_tt_descriptors=2
-C cluster1.has_128_bit_tt_descriptors=2
EOF
fi

# FEAT_FPMR support
if [ "$has_fpmr" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_fpmr="1"
-C cluster1.has_fpmr="1"
EOF
fi

if [ "$has_pmuv3p7" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_v8_7_pmu_extension=2
-C cluster1.has_v8_7_pmu_extension=2
EOF
fi

if [ "$has_mops" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster0.has_mops_option=1
-C cluster1.has_mops_option=1
EOF
fi

#------------ Cluster1 configuration (if exists) --------------
if [ "$is_dual_cluster" = "1" ]; then
	cat <<EOF >>"$model_param_file"
${pa_size+-C cluster1.PA_SIZE=$pa_size}

${cluster_1_reg_reset+-C cluster1.register_reset_data=$cluster_1_reg_reset}

${cluster_1_has_el2+-C cluster1.has_el2=$cluster_1_has_el2}

${amu_present+-C cluster1.has_amu=$amu_present}
${amu_version+-C cluster1.amu_version=${amu_version}}

${reset_to_bl31+-C cluster1.cpu0.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu1.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu2.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu3.RVBAR=${bl31_addr:?}}

${reset_to_spmin+-C cluster1.cpu0.RVBAR=${bl32_addr:?}}
${reset_to_spmin+-C cluster1.cpu1.RVBAR=${bl32_addr:?}}
${reset_to_spmin+-C cluster1.cpu2.RVBAR=${bl32_addr:?}}
${reset_to_spmin+-C cluster1.cpu3.RVBAR=${bl32_addr:?}}

${cluster_1_num_cores+-C cluster1.NUM_CORES=$cluster_1_num_cores}

${aarch64_only+-C cluster1.max_32bit_el=-1}

${aarch32+-C cluster1.cpu0.CONFIG64=0}
${aarch32+-C cluster1.cpu1.CONFIG64=0}
${aarch32+-C cluster1.cpu2.CONFIG64=0}
${aarch32+-C cluster1.cpu3.CONFIG64=0}

${bl2_at_el3+-C cluster1.cpu0.RVBAR=${bl2_addr:?}}
${bl2_at_el3+-C cluster1.cpu1.RVBAR=${bl2_addr:?}}
${bl2_at_el3+-C cluster1.cpu2.RVBAR=${bl2_addr:?}}
${bl2_at_el3+-C cluster1.cpu3.RVBAR=${bl2_addr:?}}

${memory_tagging_support_level+-C cluster1.memory_tagging_support_level=$memory_tagging_support_level}

${has_branch_target_exception+-C cluster1.has_branch_target_exception=$has_branch_target_exception}

${restriction_on_speculative_execution+-C cluster1.restriction_on_speculative_execution=$restriction_on_speculative_execution}

${restriction_on_speculative_execution+-C cluster1.restriction_on_speculative_execution_aarch32=$restriction_on_speculative_execution}

${gicv3_ext_interrupt_range+-C cluster1.gicv3.extended-interrupt-range-support=$gicv3_ext_interrupt_range}

${mpidr_layout+-C cluster1.mpidr_layout=$mpidr_layout}

${supports_multi_threading+-C cluster1.supports_multi_threading=$supports_multi_threading}

${has_v8_9_debug_extension+-C cluster1.has_v8_9_debug_extension=$has_v8_9_debug_extension}

${etm_present+-C cluster1.cpu0.etm-present=$etm_present}
${etm_present+-C cluster1.cpu1.etm-present=$etm_present}
${etm_present+-C cluster1.cpu2.etm-present=$etm_present}
${etm_present+-C cluster1.cpu3.etm-present=$etm_present}
${supports_system_trace_filter_regs+-C cluster1.has_self_hosted_trace_extension=$supports_system_trace_filter_regs}
${supports_trace_buffer_control_regs+-C cluster1.has_trbe=$supports_trace_buffer_control_regs}
${supports_crc32+-C cluster1.cpu0.enable_crc32=$supports_crc32}
${supports_crc32+-C cluster1.cpu1.enable_crc32=$supports_crc32}
${supports_crc32+-C cluster1.cpu2.enable_crc32=$supports_crc32}
${supports_crc32+-C cluster1.cpu3.enable_crc32=$supports_crc32}

${cache_state_modelled+-C cluster1.stage12_tlb_size=1024}
${cache_state_modelled+-C cluster1.check_memory_attributes=0}

EOF

# Parameters to select architecture version
if [ "$arch_version" = "8.3" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_arm_v8-3=1
EOF
fi

if [ "$arch_version" = "8.4" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_arm_v8-4=1
EOF
fi

if [ "$arch_version" = "8.5" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_arm_v8-5=1
EOF
fi

if [ "$arch_version" = "8.6" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_arm_v8-6=1
EOF
fi

if [ "$arch_version" = "8.7" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_arm_v8-7=1
EOF
fi

if [ "$arch_version" = "8.8" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_arm_v8-8=1
EOF
fi

# Parameters for fault injection
if [ "$fault_inject" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.number_of_error_records=2
-C cluster1.has_ras=2
-C cluster1.error_record_feature_register='{"INJ":0x1,"ED":0x1,"UI":0x0,"FI":0x0,"UE":0x1,"CFI":0x0,"CEC":0x0,"RP":0x0,"DUI":0x0,"CEO":0x0}'
-C cluster1.pseudo_fault_generation_feature_register='{"OF":false,"CI":false,"ER":false,"PN":false,"AV":false,"MV":false,"SYN":false,"UC":true,"UEU":true,"UER":false,"UEO":false,"DE":false,"CE":0,"R":false}'
EOF
fi

# FEAT_BRBE is enabled
if [ "$has_brbe" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_brbe=1
EOF
fi

# FEAT_TRBE is enabled
if [ "$has_trbe" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_trbe=1
EOF
fi

# FEAT_RME is enabled for the PE, plus additional arch options
if [ "$has_rme" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.rme_support_level=2
-C cluster1.gicv3.cpuintf-mmap-access-level=2
-C cluster1.gicv4.mask-virtual-interrupt=1
-C cluster1.gicv3.without-DS-support=1
-C cluster1.max_32bit_el=-1
-C cluster1.PA_SIZE=48
-C cluster1.output_attributes=ExtendedID[62:55]=MPAM_PMG,ExtendedID[54:39]=MPAM_PARTID,ExtendedID[38:37]=MPAM_SP
EOF
fi

# FEAT_PACQARMA3 is enabled
if [ "$has_pacqarma3" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_qarma3_pac=1
EOF
fi

# FEAT_RNG is enabled
if [ "$has_rng" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_rndr=1
EOF
fi

# FEAT_RNG_TRAP is enabled
if [ "$has_rng_trap" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.has_rndr_trap=1
EOF
fi

# Accelerator support level enabled
if [ "$accelerator_support_level" != "0" ]; then
	cat <<EOF >>"$model_param_file"
-C cluster1.arm_v8_7_accelerator_support_level="$accelerator_support_level"
EOF
fi

fi

# 48bit PA size: in order to access memory in high address ranges the
# model must declare and the interconnect has to be configured to
# support such address width.
if [ "$pa_size" = "48" ]; then
cat <<EOF >>"$model_param_file"
-C bp.dram_size=4000000
-C cci550.addr_width=48
EOF
fi
