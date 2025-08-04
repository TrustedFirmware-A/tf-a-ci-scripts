#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
#
# Clone and sync all Trusted Firmware repositories.
#
# For every cloned repository, set its location to a variable so that the
# checked out location can be passed down to sub-jobs.
#
# Generate an environment file that can then be sourced by the caller.

set -e

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

clone_log="$workspace/clone_repos.log"
clone_data="$workspace/clone.data"
override_data="$workspace/override.data"
inject_data="$workspace/inject.data"

# File containing parameters for sub jobs
param_file="$workspace/env.param"

# Emit a parameter to sub jobs
emit_param() {
	echo "$1=$2" >> "$param_file"
}

# Emit a parameter for code coverage metadata
code_cov_emit_param() {
	emit_param "CC_$(echo ${1^^} | tr '-' _)_$2" "$3"
}

meta_data() {
	echo "$1" >> "$clone_data"
}

# Path into the project filer where various pieces of scripts that override
# some CI environment variables are stored.
ci_overrides="$project_filer/ci-overrides"

display_override() {
	echo
	echo -n "Override: "
	# Print the relative path of the override file.
	echo "$1" | sed "s#$ci_overrides/\?##"
}

strip_var() {
	local var="$1"
	local val="$(echo "${!var}" | sed 's#^\s*\|\s*$##g')"
	eval "$var=\"$val\""
}

prefix_tab() {
	sed 's/^/\t/g' < "${1:?}"
}

prefix_arrow() {
	sed 's/^/  > /g' < "${1:?}"
}

test_source() {
	local file="${1:?}"
	if ! bash -c "source $file" &>/dev/null; then
		return 1
	fi

	source "$file"
	return 0
}

# Whether we've overridden some CI environment variables.
has_overrides=0

# Whether we've injected environment via. Jenkins
has_env_inject=0

clone_and_sync() {
	local stat
	local topic
	local refspec="${!ref}"
	local s_before s_after s_diff
	local reference_dir="$project_filer/ref-repos/${name?}"
	local ref_repo
	local ret

	strip_var refspec
	strip_var url

	# Clone in the filter workspace
	mkdir -p "$ci_scratch"
	pushd "$ci_scratch"

	# Seconds before
	s_before="$(date +%s)"

	# Clone repository to the directory same as its name; HEAD stays at
	# master.
	if [ -d "$reference_dir" ]; then
		ref_repo="--reference $reference_dir"
	fi
	echo "$ref_repo $url $name $branch"
	git clone -q $ref_repo "$url" "$name" &>"$clone_log"
	code_cov_emit_param "${name}" "URL" "${url}"
	stat="on branch master"

	pushd "$name"

	if [ "$refspec" ] && [ "$refspec" != "master" ]; then
		# If a specific revision is specified, always use that.
		git fetch -q origin "$refspec" &>"$clone_log"
		git checkout -q FETCH_HEAD &>"$clone_log"
		stat="refspec $refspec"

		# If it's not a commit hash, have the refspec replicated on the
		# clone so that downstream jobs can clone from this one using
		# the same refspec.
		if echo "$refspec" | grep -qv '^[a-f0-9]\+$'; then
			git branch -f "$refspec" FETCH_HEAD
		fi
	fi

	code_cov_emit_param "${name}" "REFSPEC" "${refspec}"
	# Generate meta data. Eliminate any quoting in commit subject as it
	# might cause problems when reporting back to Gerrit.
	meta_data "$name: $stat"
	meta_data "	$(git show --quiet --format=%H): $(git show --quiet --format=%s | sed "s/[\"']/ /g")"
	meta_data "	Commit date: $(git show --quiet --format=%cd)"
	meta_data
	code_cov_emit_param "${name}" "COMMIT"  "$(git show --quiet --format=%H)"

	# Calculate elapsed seconds
	s_after="$(date +%s)"
	let "s_diff = $s_after - $s_before" || true

	echo
	echo "Repository: $url ($stat)"
	prefix_arrow <(git show --quiet)
	echo "Cloned in $s_diff seconds"
	echo

	popd
	popd

	emit_env "$loc" "$ci_scratch/$name"
	emit_env "$ref" "$refspec"
}

# Environment file in Java property file format, that's soured in Jenkins job
env_file="$workspace/env"
rm -f "$env_file"

# Workspace on external filer where all repositories gets cloned so that they're
# accessible to all Jenkins slaves.
if upon "$local_ci"; then
	ci_scratch="$workspace/filer"
else
	scratch_owner="${JOB_NAME:?}-${BUILD_NUMBER:?}"
	ci_scratch="$project_scratch/$scratch_owner"
	tforg_key="$CI_BOT_KEY"
	tforg_user="$CI_BOT_USERNAME"
fi

if [ -d "$ci_scratch" ]; then
	# This could be because of jobs of same name running from
	# production/staging/temporary VMs
	echo "Scratch space $ci_scratch already exists; removing."
	rm -rf "$ci_scratch"
fi
mkdir -p "$ci_scratch"

# Set CI_SCRATCH so that it'll be injected when sub-jobs are triggered.
emit_param "CI_SCRATCH" "$ci_scratch"

# However, on Jenkins v2, injected environment variables won't override current
# job's parameters. This means that the current job (the scratch owner, the job
# that's executing this script) would always observe CI_SCRATCH as empty, and
# therefore won't be able to remove it. Therefore, use a different variable
# other than CI_SCRATCH parameter for the current job to refer to the scratch
# space (although they both will have the same value!)
emit_env "SCRATCH_OWNER" "$scratch_owner"
emit_env "SCRATCH_OWNER_SPACE" "$ci_scratch"

strip_var CI_ENVIRONMENT
if [ "$CI_ENVIRONMENT" ]; then
	{
	echo
	echo "Injected environment:"
	prefix_tab <(echo "$CI_ENVIRONMENT")
	echo
	} >> "$inject_data"

	cat "$inject_data"

	tmp_env=$(mktempfile)
	echo "$CI_ENVIRONMENT" > "$tmp_env"
	source "$tmp_env"
	cat "$tmp_env" >> "$env_file"

	has_env_inject=1
fi

TF_REFSPEC="${tf_refspec:-$TF_REFSPEC}"
if not_upon "$no_tf"; then
	# Clone Trusted Firmware repository
	url="$tf_src_repo_url" name="trusted-firmware" ref="TF_REFSPEC" \
		loc="TF_CHECKOUT_LOC" \
		clone_and_sync
fi

TFTF_REFSPEC="${tftf_refspec:-$TFTF_REFSPEC}"
if not_upon "$no_tftf"; then
	# Clone Trusted Firmware TF repository
	url="$tftf_src_repo_url" name="trusted-firmware-tf" ref="TFTF_REFSPEC" \
		loc="TFTF_CHECKOUT_LOC" \
		clone_and_sync
fi

# Clone code coverage repository if code coverage is enabled
if not_upon "$no_cc"; then
	pushd "$ci_scratch"
	git clone -q $cc_src_repo_url cc_plugin -b $cc_src_repo_tag 2> /dev/null
	popd
fi

SPM_REFSPEC="${spm_refspec:-$SPM_REFSPEC}"
if not_upon "$no_spm"; then
	# Clone SPM repository
	url="$spm_src_repo_url" name="spm" ref="SPM_REFSPEC" \
		loc="SPM_CHECKOUT_LOC" clone_and_sync
fi

CI_REFSPEC="${ci_refspec:-$CI_REFSPEC}"
if not_upon "$no_ci"; then
	# Clone Trusted Firmware CI repository
	url="$tf_ci_repo_url" name="trusted-firmware-ci" ref="CI_REFSPEC" \
		loc="CI_ROOT" clone_and_sync
fi

TF_M_TESTS_REFSPEC="${tf_m_tests_refspec:-$TF_M_TESTS_REFSPEC}"
if not_upon "$no_tfm_tests"; then
	url="$tf_m_tests_src_repo_url" name="tf-m-tests" ref="TF_M_TESTS_REFSPEC" \
		loc="TF_M_TESTS_PATH" clone_and_sync
fi

TF_M_EXTRAS_REFSPEC="${tf_m_extras_refspec:-$TF_M_EXTRAS_REFSPEC}"
if not_upon "$no_tfm_extras"; then
	url="$tf_m_extras_src_repo_url" name="tf-m-extras" ref="TF_M_EXTRAS_REFSPEC" \
		loc="TF_M_EXTRAS_PATH" clone_and_sync
fi

RMM_REFSPEC="${rmm_refspec:-$RMM_REFSPEC}"
if not_upon "$no_rmm"; then
	url="$rmm_src_repo_url" name="tf-rmm" ref="RMM_REFSPEC" \
		loc="RMM_PATH" clone_and_sync
fi

# Copy environment file to ci_scratch for sub-jobs' access
cp "$env_file" "$ci_scratch"
cp "$param_file" "$ci_scratch"

# Copy clone data so that it's available for sub-jobs' HTML reporting
if [ -f "$clone_data" ]; then
	cp "$clone_data" "$ci_scratch"
fi

# vim: set tw=80 sw=8 noet:
