#
# Copyright (c) 2019-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# This file lists the source files that are expected to be excluded from
# Coverity's analysis, and the reason why.
#

# The expected format is an array of tuples (filename_pattern, description).
# - filename_pattern is a Python regular expression (as in the 're' module)
#   describing the file(s) to exclude.
# - description aims at providing the reason why the files are expected
#   to be excluded.
exclude_paths = [
    ("drivers/arm/tzc/tzc_common_private.c", "File included, actually indirectly analyzed"),
    ("drivers/arm/tzc/tzc_dmc500.c", "Only used by deprecated SGM platforms"),
    ("drivers/marvell/comphy/phy-comphy-3700.c", "File is actually analyzed. False positive"),
    ("drivers/marvell/comphy/phy-comphy-cp110.c", "File is actually analyzed. False positive"),
    ("drivers/marvell/gwin.c", "Not used by any upstream marvell platform"),
    ("drivers/marvell/mochi/ap807_setup.c", "Not used by any upstream marvell platform"),
    ("drivers/renesas/common/ddr/ddr_b/boot_init_dram_config.c",
     "It is used as a header file and is included in boot_init_dram.c .Since it is not explicitly compiled, such file cannot be converted into an instrumented binary for further analysis"),
    ("drivers/auth/cryptocell/713/.*", "There is no dummy library to support 713 for now. This can be removed once we have this library in place"),
    ("drivers/scmi-msg/power_domain.c", "Not used by any upstream platform"),

    ("plat/arm/board/fvp/fconf/fconf_nt_config_getter.c", "Not currently used. Future functionality"),
    ("plat/arm/common/arm_tzc_dmc500.c", "Only used by deprecated SGM platforms"),
    ("plat/marvell/armada/a8k/common/plat_bl1_setup.c", "Not used by any upstream marvell platform"),
    ("plat/mediatek/mt8173/plat_mt_gic.c", "Deprecated code"),
    ("plat/mediatek/common/custom/oem_svc.c", "Not used by any upstream mediatek platform"),
    ("plat/nvidia/tegra/common/tegra_gicv3.c", "Not used by any upstream nvidia platform"),
    ("plat/qemu/common/sp_min/sp_min_setup.c", "Not used in any upstream platform - see GENFW-2164"),
    ("plat/rockchip/rk3399/drivers/m0/.*", "Work around the lack of support for the M0 compiler in the scripts"),
    ("drivers/arm/gic/v3/gic600ae_fmu.c", "Not used by any upstream platform"),
    ("drivers/arm/gic/v3/gic600ae_fmu_helpers.c", "Not used by any upstream platform"),

    # The following block is excluding files that are impossible to include in a build due to a missing file
    # this should be removed as soon as it would be possible to build stingray platform with SCP_BL2 option
    ("drivers/brcm/iproc_gpio.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("drivers/brcm/scp.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("drivers/brcm/spi/iproc_qspi.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("drivers/brcm/spi/iproc_spi.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("drivers/brcm/spi_flash.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("drivers/brcm/spi_sf.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/board/common/bcm_elog_ddr.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/board/stingray/src/brcm_pm_ops.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/board/stingray/src/ncsi.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/board/stingray/src/scp_cmd.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/board/stingray/src/scp_utils.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/common/brcm_mhu.c", "Cannot be built due to the missing m0_ipc.h file"),
    ("plat/brcm/common/brcm_scpi.c", "Cannot be built due to the missing m0_ipc.h file"),

    # The following block is excluding files specific to NXP platforms that
    # cannot be compiled with any build flags at this moment due to external
    # dependencies
    ("drivers/nxp/console/console_16550.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/csu/csu.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/ddr/fsl-mmdc/fsl_mmdc.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/ddr/phy-gen1/phy.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/gic/ls_gicv2.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/gpio/nxp_gpio.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/interconnect/ls_cci.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/qspi/qspi.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/sfp/fuse_prov.c", "Cannot be built due to external dependencies"),
    ("drivers/nxp/sfp/sfp.c", "Cannot be built due to external dependencies"),
    ("plat/nxp/common/fip_handler/fuse_fip/fuse_io_storage.c", "Cannot be built due to external dependencies"),

    ("lib/compiler-rt/.*", "3rd party libraries will not be fixed"),
    ("lib/libfdt/.*", "3rd party libraries will not be fixed"),
    ("lib/libc/strlcat.c", "Not used by any upstream platform"),
    ("lib/libc/strtok.c", "Not used by any upstream platform"),

    ("tools/.*", "Host tools"),

    # Temporarily exclude the following files such that tf-coverity job can be
    # reinstated. Appropriate build commands to compile these files should be
    # added to tf-cov-make script after v2.6 release
    ("drivers/renesas/rzg/pfc/G2E/pfc_init_g2e.c", "Temporarily excluded"),
    ("drivers/renesas/rzg/pfc/G2H/pfc_init_g2h.c", "Temporarily excluded"),
    ("drivers/renesas/rzg/pfc/G2N/pfc_init_g2n.c", "Temporarily excluded"),
    ("drivers/renesas/rzg/qos/G2E/qos_init_g2e_v10.c", "Temporarily excluded"),
    ("drivers/renesas/rzg/qos/G2H/qos_init_g2h_v30.c", "Temporarily excluded"),
    ("drivers/renesas/rzg/qos/G2N/qos_init_g2n_v10.c", "Temporarily excluded"),

    # Exclude the following files of imx8mq as this platform is dropped
    # from the CI. Put the files of this platform into a silent status.
    ("plat/imx/imx8m/imx8mq/gpc.c", "Not currently used"),
    ("plat/imx/imx8m/imx8mq/imx8mq_bl31_setup.c", "Not currently used"),
    ("plat/imx/imx8m/imx8mq/imx8mq_psci.c", "Not currently used"),

    # Exclude the following files of RDN1EDGE and SGI575 as these platforms
    # are deprecated and removed from the CI.
    ("plat/arm/board/rdn1edge/rdn1edge_err.c", "Only used by deprecated RDN1EDGE platforms"),
    ("plat/arm/board/rdn1edge/rdn1edge_plat.c", "Only used by deprecated RDN1EDGE platforms"),
    ("plat/arm/board/rdn1edge/rdn1edge_security.c", "Only used by deprecated RDN1EDGE platforms"),
    ("plat/arm/board/rdn1edge/rdn1edge_topology.c", "Only used by deprecated RDN1EDGE platforms"),
    ("plat/arm/board/rdn1edge/rdn1edge_trusted_boot.c", "Only used by deprecated RDN1EDGE platforms"),
    ("plat/arm/board/sgi575/sgi575_err.c", "Only used by deprecated SGI575 platform"),
    ("plat/arm/board/sgi575/sgi575_plat.c", "Only used by deprecated SGI575 platform"),
    ("plat/arm/board/sgi575/sgi575_security.c", "Only used by deprecated SGI575 platform"),
    ("plat/arm/board/sgi575/sgi575_topology.c", "Only used by deprecated SGI575 platform"),
    ("plat/arm/board/sgi575/sgi575_trusted_boot.c", "Only used by deprecated SGI575 platform"),
    ("plat/arm/css/sgi/sgi_ras.c", "Only used by deprecated SGI575 platform"),

    # Exclude the following files used for STM32MP host tools (fiptool and cert_create)
    ("plat/st/stm32mp1/plat_def_uuid_config.c", "Used to build STM32MP fiptool"),
    ("plat/st/stm32mp1/stm32mp1_tbb_cert.c", "Used to build STM32MP cert_create"),

    # Exclude the IO files
    ("drivers/io/io_dummy.c", "None of the upstream platforms using this file"),

    # Exclude The following files used to wrap external test code
    ("plat/arm/board/tc/rss_ap_test_stubs.c", "Only used for testing on arm/tc platform"),
    ("plat/arm/board/tc/rss_ap_tests.c", "Only used for testing on arm/tc platform"),
    ("plat/arm/board/tc/rss_ap_testsuites.c", "Only used for testing on arm/tc platform"),
]
