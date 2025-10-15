#!/usr/bin/env bash
set -euo pipefail

optee_version="${optee_version:-4.9.0}"
optee_path="${optee_path:-/workspaces/tf-a-projects/optee_os}"
prebuilts_path="${prebuilts_path:-/workspaces/tf-a-projects/prebuilts}"

optee_prebuilts_dir="${prebuilts_path}/optee/${optee_version}/"
build_dir="${optee_path}/out/arm"

mkdir -p "${optee_prebuilts_dir}/handoff"

# Ensure we have up-to-date refs and tags
git -C "${optee_path}" fetch --tags --force

# Verify the ref exists (tag or branch) before checkout
if git -C "${optee_path}" rev-parse --verify --quiet "${optee_version}" >/dev/null; then
    git -C "${optee_path}" checkout "${optee_version}"
else
    echo "Error: '${optee_version}' not found as a tag or branch" >&2
    exit 1
fi

make -C "${optee_path}" -j \
    O="${build_dir}" \
    CFG_USER_TA_TARGETS=ta_arm64 \
    CFG_ARM64_core=y \
    PLATFORM=vexpress-fvp \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_core=aarch64-linux-gnu- \
    CROSS_COMPILE_ta_arm64=aarch64-linux-gnu- \
    CROSS_COMPILE_ta_arm32=arm-none-linux-gnueabihf- \
    CFG_TEE_CORE_LOG_LEVEL=3 \
    CFG_ARM_GICV3=y

cp "${build_dir}"/core/tee*_v2.bin "${optee_prebuilts_dir}/"

make -C "${optee_path}" -j \
    O="${build_dir}" \
    CFG_USER_TA_TARGETS=ta_arm64 \
    CFG_ARM64_core=y \
    PLATFORM=vexpress-fvp \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_core=aarch64-linux-gnu- \
    CROSS_COMPILE_ta_arm64=aarch64-linux-gnu- \
    CROSS_COMPILE_ta_arm32=arm-none-linux-gnueabihf- \
    CFG_TEE_CORE_LOG_LEVEL=3 \
    CFG_DT=y \
    CFG_MAP_EXT_DT_SECURE=y \
    CFG_ARM_GICV3=y

cp "${build_dir}"/core/tee*_v2.bin "${optee_prebuilts_dir}/handoff"
