#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
#
# Clone and sync all Trusted Firmware repositories.
#
# The main repository is checked out at the required refspec (GERRIT_REFSPEC).
# The rest of repositories are attempted to sync to the topic of that refspec
# (as pointed to by GERRIT_TOPIC). 'repo_under_test' must be set to a
# GERRIT_PROJECT for sync to work.
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
gerrit_data="$workspace/gerrit.data"
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

post_gerrit_comment() {
	local gerrit_url="${gerrit_url:-$GERRIT_HOST}"
	gerrit_url="${gerrit_url:?}"

	# Posting comments to gerrit.oss.arm.com does not require any special
	# credentials, review.trustedfirmware.org does. Provide the ci-bot-user
	# account credentials for the latter.
	if [ "$gerrit_url" == "review.trustedfirmware.org" ]; then
		ssh -p 29418 -i "$tforg_key" "$tforg_user@$gerrit_url" gerrit \
			review  "$GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER" \
			--message "'$(cat ${msg_file:?})'"
	else
		ssh -p 29418 "$gerrit_url" gerrit review \
			"$GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER" \
			--message "'$(cat ${msg_file:?})'"
	fi
}

# Whether we've synchronized branches or not
has_synched=0

# Whether we've overridden some CI environment variables.
has_overrides=0

# Whether we've injected environment via. Jenkins
has_env_inject=0

# Default Gerrit failure message file
gerrit_fail_msg_file="$workspace/gerrit-fail"

clone_and_sync() {
	local stat
	local topic
	local refspec="${!ref}"
	local s_before s_after s_diff
	local reference_dir="$project_filer/ref-repos/${name?}"
	local ref_repo
	local ret
	local gerrit_server
	local gerrit_user
	local gerrit_keyfile

	strip_var refspec
	strip_var url

	case "$url" in
		*${arm_gerrit_url}*)
			gerrit_server="arm"
			;;

		*${tforg_gerrit_url}*)
			# SSH authentication is required on trustedfirmware.org.
			gerrit_server="tforg"
			gerrit_user="$tforg_user"
			gerrit_keyfile="$tforg_key"
			;;

		*)
			# The project to clone might not be hosted on a Gerrit
			# server at all (e.g. Github).
			;;
	esac

	# Refspec translation is supported for Gerrit patches only.
	if [ "$gerrit_server" ]; then
		refspec="$($ci_root/script/translate_refspec.py \
			-p "$name" -s "$gerrit_server" -u "$gerrit_user" \
			-k "$gerrit_keyfile" "$refspec")"
	fi

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
	elif [ "$name" = "$repo_under_test" ]; then
		# Main repository under test
		if [ "$GERRIT_REFSPEC" ]; then
			# Fetch and checkout GERRIT_REFSPEC
			git fetch -q origin "$GERRIT_REFSPEC" \
				&>"$clone_log"
			git checkout -q FETCH_HEAD &>"$clone_log"
			refspec="$GERRIT_REFSPEC"
			stat="refspec $refspec"
			git branch "$refspec" FETCH_HEAD
		fi
	elif [ "$GERRIT_TOPIC" ]; then
		# Auxiliary repository: it's already on master when cloned above.
		topic="$GERRIT_TOPIC"

		# Check first if there's a Gerrit topic matching the topic of
		# the main repository under test
		ret=0
		refspec="$("$ci_root/script/translate_refspec.py" -p "$name" \
			-u "$gerrit_user" -k "$gerrit_keyfile" \
			-s "$gerrit_server" "topic:$topic" 2>/dev/null)" \
			|| ret="$?"
		if [ "$ret" = 0 ]; then
			{
			git fetch -q origin "$refspec"
			git checkout -q FETCH_HEAD
			} &>"$clone_log"
			stat="gerrit topic $topic"
			git branch "$refspec" FETCH_HEAD

			has_synched=1
		elif git fetch -q origin "topics/$topic" &>"$clone_log"; then
			# If there's a remote branch matching the Gerrit topic
			# name, checkout to that; otherwise, stay on master.
			git checkout -q FETCH_HEAD &>"$clone_log"
			refspec="topics/$topic"
			stat="on branch $refspec"
			git branch "$refspec" FETCH_HEAD

			has_synched=1
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

	# If this repository is being tested under a Gerrit trigger, set the
	# Gerrit test groups.
	if [ "$name" = "$repo_under_test" ]; then
		# For a Gerrit trigger, it's possible that users publish patch
		# sets in quick succession. If the CI is already busy, this
		# leads to more and more triggers queuing up. Also, it's likey
		# that older patch sets are tested before new ones. But because
		# there are newer patch sets already in queue, we should avoid
		# running tests on older ones as their results will be discarded
		# anyway.
		pushd "$ci_scratch/$name"

		change_id="$(git show -q --format=%b | awk '/Change-Id/{print $2}')"
		commit_id="$(git show -q --format=%H)"
		latest_commit_id="$($ci_root/script/translate_refspec.py \
			-p "$name" -u "$gerrit_user" -k "$gerrit_keyfile" \
			-s "$gerrit_server" "change:$change_id")"

		if [ "$commit_id" != "$latest_commit_id" ]; then
			# Overwrite Gerrit failure message
			cat <<EOF >"$gerrit_fail_msg_file"
Patch set $GERRIT_PATCHSET_NUMBER is not the latest; not tested.
Please await results for the latest patch set.
EOF

			cat "$gerrit_fail_msg_file"
			echo
			die
		fi

		# Run nominations on this repository
		rules_file="$ci_root/script/$name.nomination.py"
		if [ -f "$rules_file" ]; then
			"$ci_root/script/gen_nomination.py" "$rules_file" > "$nom_file"
			if [ -s "$nom_file" ]; then
				emit_env "NOMINATION_FILE" "$nom_file"
				echo "$name has $(wc -l < $nom_file) test nominations."
			fi
		fi

		popd

		# Allow for groups to be overridden
		GERRIT_BUILD_GROUPS="${GERRIT_BUILD_GROUPS-$gerrit_build_groups}"
		if [ "$GERRIT_BUILD_GROUPS" ]; then
			emit_env "GERRIT_BUILD_GROUPS" "$GERRIT_BUILD_GROUPS"
		fi

		GERRIT_TEST_GROUPS="${GERRIT_TEST_GROUPS-$gerrit_test_groups}"
		if [ "$GERRIT_TEST_GROUPS" ]; then
			emit_env "GERRIT_TEST_GROUPS" "$GERRIT_TEST_GROUPS"
		fi
	fi
}

# When triggered from Gerrit, the main repository that is under test.  Can be
# either TF, TFTF, SCP or CI.
if [ "$GERRIT_REFSPEC" ]; then
	repo_under_test="${repo_under_test:-$REPO_UNDER_TEST}"
	repo_under_test="${repo_under_test:?}"
fi

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

# Nomination file
nom_file="$ci_scratch/nominations"

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

if [ "$GERRIT_BRANCH" ]; then
	# Overrides targeting a specific Gerrit branch.
	target_branch_override="$ci_overrides/branch/$GERRIT_BRANCH/env"
	if [ -f "$target_branch_override" ]; then
		display_override "$target_branch_override"

		{
		echo
		echo "Target branch overrides:"
		prefix_tab "$target_branch_override"
		echo
		} >> "$override_data"

		cat "$override_data"

		source "$target_branch_override"
		cat "$target_branch_override" >> "$env_file"

		has_overrides=1
	fi
fi

TF_REFSPEC="${tf_refspec:-$TF_REFSPEC}"
if not_upon "$no_tf"; then
	# Clone Trusted Firmware repository
	url="$tf_src_repo_url" name="trusted-firmware" ref="TF_REFSPEC" \
		loc="TF_CHECKOUT_LOC" \
		gerrit_build_groups="tf-gerrit-build" \
		gerrit_test_groups="tf-gerrit-tests tf-gerrit-tftf" \
		clone_and_sync
fi

TFTF_REFSPEC="${tftf_refspec:-$TFTF_REFSPEC}"
if not_upon "$no_tftf"; then
	# Clone Trusted Firmware TF repository
	url="$tftf_src_repo_url" name="trusted-firmware-tf" ref="TFTF_REFSPEC" \
		loc="TFTF_CHECKOUT_LOC" \
		gerrit_test_groups="tftf-l1-build tftf-l1-fvp" \
		clone_and_sync
fi

# Clone code coverage repository if code coverage is enabled
if not_upon "$no_cc"; then
	pushd "$ci_scratch"
	git clone -q $cc_src_repo_url cc_plugin -b $cc_src_repo_tag 2> /dev/null
	popd
fi

SCP_REFSPEC="${scp_refspec:-$SCP_REFSPEC}"
if upon "$clone_scp"; then
	# Clone SCP Firmware repository
	# NOTE: currently scp/firmware:master is not tracking the upstream.
	# Therefore, if the url is gerrit.oss.arm.com/scp/firmware and there is
	# no ref_spec, then set the ref_spec to master-upstream.
	if [ "$scp_src_repo_url" = "$scp_src_repo_default" ]; then
		SCP_REFSPEC="${SCP_REFSPEC:-master-upstream}"
	fi

	url="$scp_src_repo_url" name="scp" ref="SCP_REFSPEC" \
		loc="SCP_CHECKOUT_LOC" clone_and_sync

	pushd "$ci_scratch/scp"

	# Edit the submodule URL to point to the reference repository so that
	# all submodule update pick from the reference repository instead of
	# Github.
	cmsis_ref_repo="${cmsis_root:-$project_filer/ref-repos/cmsis}"
	if [ -d "$cmsis_ref_repo" ]; then
		cmsis_reference="--reference $cmsis_ref_repo"
	fi
	git submodule -q update $cmsis_reference --init

	eval cmsis_dir="$(git submodule status | grep cmsis | awk 'NR==1{print $2}')"

	# Workaround while fixing permissions on /arm/projectscratch/ssg/trusted-fw/ref-repos/cmsis
	cd $cmsis_dir
	code_cov_emit_param "CMSIS" "URL" "$(git remote -v | grep fetch |  awk '{print $2}')"
	code_cov_emit_param "CMSIS" "COMMIT" "$(git rev-parse HEAD)"
	code_cov_emit_param "CMSIS" "REFSPEC" "master"
	cd ..
	########################################
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
		loc="CI_ROOT" gerrit_test_groups="ci-l1" \
		clone_and_sync
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

RMM_EXTRAS_REFSPEC="${rmm_refspec:-$RMM_REFSPEC}"
if not_upon "$no_rmm"; then
	url="$rmm_src_repo_url" name="tf-rmm" ref="RMM_REFSPEC" \
		loc="RMM_PATH" clone_and_sync
fi

if [ "$GERRIT_BRANCH" ]; then
	# If this CI run was in response to a Gerrit commit, post a comment back
	# to the patch set calling out everything that we've done so far. This
	# reassures both the developer and the reviewer about CI refspecs used
	# for CI testing.
	#
	# Note the extra quoting for the message, which Gerrit requires.
	if upon "$has_synched"; then
		echo "Branches synchronized:" >> "$gerrit_data"
		echo >> "$gerrit_data"
		cat "$clone_data" >> "$gerrit_data"
	fi

	if upon "$has_overrides"; then
		cat "$override_data" >> "$gerrit_data"
	fi

	if upon "$has_env_inject"; then
		cat "$inject_data" >> "$gerrit_data"
	fi

	if [ -s "$gerrit_data" ]; then
		msg_file="$gerrit_data" post_gerrit_comment
	fi
fi

echo "SCP_TOOLS_COMMIT=$SCP_TOOLS_COMMIT" >> "$param_file"

# Copy environment file to ci_scratch for sub-jobs' access
cp "$env_file" "$ci_scratch"
cp "$param_file" "$ci_scratch"

# Copy clone data so that it's available for sub-jobs' HTML reporting
if [ -f "$clone_data" ]; then
	cp "$clone_data" "$ci_scratch"
fi

# vim: set tw=80 sw=8 noet:
