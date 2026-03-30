#!/usr/bin/env bash
#
# Copyright (c) 2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

gen_lava_job_def() {
	local yaml_template_file="${yaml_template_file:?}"
	local yaml_file="${yaml_file:?}"
	local yaml_job_file="${yaml_job_file}"

	# Bash doesn't have array values, we have to create references to the
	# array of artefacts and their urls.
	declare -n artefacts="${1-null}"
	declare -n artefact_urls="${2-null}"

	if [ -f "${lava_model_params}" ]; then
		readarray -t boot_arguments < "${lava_model_params}"
	fi

	# Source runtime environment variables now so that they are accessible from
	# the LAVA job template.
	local run_root="${archive}/run"
	local run_env="${run_root}/env"

	if [ -f "${run_env}" ]; then
	    source "${run_env}"
	fi

	# Generate the LAVA job definition, minus the test expectations
	expand_template "${yaml_template_file}" > "${yaml_file}"

	if not_upon "${skip_lava_expect:-}"; then
		gen_yaml_expect >> "${yaml_file}"
	fi

	# create job.yaml
	cp "$yaml_file" "$yaml_job_file"

	# archive both yamls
	archive_file "$yaml_file"
	archive_file "$yaml_job_file"
}

gen_lava_model_params() {
	local lava_model_params="${lava_model_params:?}"
	declare -n macros="$1"

	# Derive LAVA model parameters from the non-LAVA ones
	cp "${archive}/model_params" "${lava_model_params}"

	sed -i '/^[[:space:]]*$/d' $lava_model_params

	if [[ $model =~ "qemu" ]]; then
		# Strip the model parameters of parameters already specified in the deploy
		# overlay and job context.
		sed -i '/-M/d;/kernel/d;/initrd/d;/bios/d;/cpu/d;/^[[:space:]]*$/d' \
				$lava_model_params
	elif [[ ! $model =~ "qemu" ]]; then
		# FIXME find a way to properly match FVP configurations.
		# Ensure braces in the FVP model parameters are not accidentally
		# interpreted as LAVA macros.
		sed -i -e 's/{/{{/g' "${lava_model_params}"
		sed -i -e 's/}/}}/g' "${lava_model_params}"
	else
		echo "Unsupported emulated platform $model."
	fi

	# LAVA expects binary paths as macros, i.e. `{X}` instead of `x.bin`, so
	# replace the file paths in our pre-generated model parameters.
	for regex in "${!macros[@]}"; do
		sed -i -e "s!${regex}!${macros[${regex}]}!" "${lava_model_params}"
	done
}

gen_yaml_template() {
	local target="${target-fvp}"
	local yaml_template_file="${yaml_template_file-$workspace/${target}_template.yaml}"

	local payload_type="${payload_type:?}"

	cp "${ci_root}/script/lava-templates/${target}-${payload_type:?}.yaml" \
		"${yaml_template_file}"

	archive_file "$yaml_template_file"
}

gen_yaml_expect() {
	# Loop through all uarts expect files
	for expect_file in $(find $run_root -name expect); do
		local uart_number=$(basename "$(dirname ${expect_file})")

		# Only handle the primary UART through LAVA. The remaining UARTs are
		# validated after LAVA returns by the post-expect script.
		if [ "${uart_number:?}" != "uart$(get_primary_uart "${archive}")" ]; then
				continue
		fi

		# Array containing "interactive" or "monitor" expect strings and populated during run config execution.
		# Interactive expect scripts are converted into LAVA Interactive Test Actions (see
		# https://tf.validation.linaro.org/static/docs/v2/interactive.html#writing-tests-interactive) and
		# monitor expect scripts are converted into LAVA Monitor Test Actions (see
		# https://validation.linaro.org/static/docs/v2/actions-test.html#monitor)
		#
		# Interactive Expect strings have the format 'i;<prompt>;<succeses>;<failures>;<commands>'
		# where multiple successes or  failures or commands are separated by @
		#
		# Monitor Expect strings have the format 'm;<start>;<end>;<patterns>'
		# where multiple patterns are separated by @
		#
		expect_string=()

		# Get the real name of the expect file
		expect_file=$(cat $expect_file)

		# Source the run_config enviroment variables
		env=$run_root/$uart_number/env
		if [ -e $env ]; then
			source $env
		fi

		# Get all expect strings
		expect_dir="${ci_root}/expect-lava"
		expect_file="${expect_dir}/${expect_file}"

		# Allow the expectations to be provided directly in LAVA's job YAML
		# format, rather than converting it from a pseudo-Expect Bash script in
		# the block below.
		if [ -f "${expect_file/.exp/.yaml}" ]; then
			pushd "${expect_dir}"
			expand_template "${expect_file/.exp/.yaml}"
			popd

			continue
		else
			source "${expect_file}"
		fi

		if [ ${#expect_string[@]} -gt 0 ]; then
			# expect loop
			for key in "${!expect_string[@]}"; do
				# single raw expect string
				es="${expect_string[${key}]}"

				# action type: either m or i
				action="$(echo "${es}" | awk -F ';' '{print $1}')"

				if [ "${action}" = "m" ]; then
					start="$(echo "${es}" | awk -F ';' '{print $2}')"
					end="$(echo "${es}" | awk -F ';' '{print $3}')"
					patterns="$(echo "${es}" | awk -F ';' '{print $4}')"

					cat <<-EOF
					- test:
					   monitors:
					   - name: tests
					     start: '${start}'
					     end: '${end}'
					EOF

					# Patterns are separated by '@'
					OLD_IFS=$IFS; IFS=$'@'
					for p in ${patterns}; do
						cat <<-EOF
						     pattern: '$p'
						EOF
					done

					IFS=$OLD_IFS
					cat <<-EOF
					     fixupdict:
					      PASS: pass
					      FAIL: fail
					EOF
				fi # end of monitor action

				if [ "${action}" = "i" ]; then
					prompts="$(echo "${es}" | awk -F ';' '{print $2}')"
					success="$(echo "${es}" | awk -F ';' '{print $3}')"
					failure="$(echo "${es}" | awk -F ';' '{print $4}')"
					commands="$(echo "${es}" | awk -F ';' '{print $5}')"

					test_name="${uart_number}_${key}"

					cat <<-EOF
					- test:
					   interactive:
					EOF
					OLD_IFS=$IFS; IFS=$'@'

					name="${test_name}" \
					commands=$commands \
						print_interactive_command

					if [[ -n "${success}" ]]; then
						 message="$success" \
							print_lava_result_msg
                                        fi

					if [[ -n "${failure}" ]]; then
						res="failures" \
						message="$failure" \
							print_lava_result_msg
					fi
					IFS=$OLD_IFS
				fi # end of interactive action

			done # end of expect	loop
		fi
	done # end of uart loop
}


print_interactive_command(){
	local name="${name:?}"
	local prompt=${prompts:-}
	local commands=${commands:-}

	cat <<-EOF
	   - name: interactive_${name}
	     prompts: ['${prompt}']
	     script:
	     - name: interactive_command_${name}
	EOF

	if [ -z "${commands}" ]; then
		cat <<-EOF
		       command:
		EOF
	else
		for c in ${commands}; do
			cat <<-EOF
			       command: "$c"
			EOF
		done
	fi
}

print_lava_result_msg() {
	local res="${res:-successes}"
	local message=${message:?}

	cat <<-EOF
	       ${res}:
	EOF

	for m in ${message}; do
		cat <<-EOF
		       - message: '$m'
		EOF

		if [ $res == "failures" ]; then
			cat <<-EOF
		         exception: JobError
			EOF
		fi
	done
}
