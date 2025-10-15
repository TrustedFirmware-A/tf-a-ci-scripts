#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "${1:-}" ]]; then
    echo "Usage: $0 <optee_version>" >&2
    exit 1
fi

optee_version="$1"
optee_path="${optee_path:-}"
optee_tmp=""
prebuilts_path="${prebuilts_path:-prebuilts}"

optee_prebuilts_dir="${prebuilts_path}/optee/${optee_version}/"

mkdir -p "${optee_prebuilts_dir}/handoff"

if [[ ! -d "${optee_path}" ]]; then
    optee_tmp=$(mktemp -d)
    optee_path="${optee_tmp}"

    git clone https://github.com/OP-TEE/optee_os.git "${optee_path}"
else
    # Ensure we have up-to-date refs and tags
    git -C "${optee_path}" fetch --tags --force
fi

build_dir="${optee_path}/out/arm"

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

cp "${build_dir}"/core/tee-{header,pager}_v2.bin "${optee_prebuilts_dir}/"

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

cp "${build_dir}"/core/tee-{header,pager}_v2.bin "${optee_prebuilts_dir}/handoff"

# Update the default version after both sets of binaries are ready.
fvp_utils="$(dirname -- "${BASH_SOURCE[0]}")/../../fvp_utils.sh"
sed -i.bak "s/^optee_version=.*/optee_version=\"${optee_version}\"/" "${fvp_utils}"
rm -f "${fvp_utils}.bak"

if [[ -n "${optee_tmp}" ]]; then
    rm -rf -- "${optee_tmp}"
fi
