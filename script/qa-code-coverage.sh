#!/usr/bin/env bash
#
# Copyright (c) 2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Include variables and functions to be used by these scripts
source "$CI_ROOT/utils.sh"
################################################################################
# CI VARIABLES:
# workspace, warehouse, artefacts
# GLOBAL VARIABLES:
# OUTDIR, PROJECT, FALLBACK_PLUGIN_URL, FALLBACK_FILES, PLUGIN_BINARY
################################################################################
# Defining constants
GERRIT_URL=${GERRIT_URL:-https://gerrit.oss.arm.com}
QA_REPO_USER=jenkins_auto
QA_REPO_INTERNAL=${QA_REPO_INTERNAL:-https://${QA_REPO_USER}:${QA_REPO_TOKEN}@git.gitlab.arm.com/tooling/qa-tools-internal.git}
QA_REPO_PUBLIC=${QA_REPO_PUBLIC:-https://git.gitlab.arm.com/tooling/qa-tools.git}
QA_REPO_NAME=qa-tools
# Internal globals
CODE_COVERAGE_FOLDER="${OUTDIR:-$workspace}/qa-code-coverage"
DEBUG_FOLDER=${artefacts}/debug
RELEASE_FOLDER=${artefacts}/release
TRACE_FILE_PREFIX=covtrace
CONFIG_JSON=${CODE_COVERAGE_FOLDER}/configuration_file.json
INTERMEDIATE_LAYER_FILE=${CODE_COVERAGE_FOLDER}/intermediate_layer.json
INFO_FILE=${CODE_COVERAGE_FOLDER}/coverage.info
REPORT_FOLDER=${CODE_COVERAGE_FOLDER}/lcov

QA_REPO=${QA_TOOLS_REPO:-$QA_REPO_PUBLIC}
QA_REFSPEC=${QA_TOOLS_BRANCH:-$TEST_DEFINITIONS_TAG}
QA_REFSPEC=${QA_REFSPEC:-stable}


################################################################################
# Deploy qa-tools into the current directory
# GLOBALS:
#   QA_REPO, QA_REPO_NAME, QA_REFSPEC
# ARGUMENTS:
#   None
# OUTPUTS:
#   Clones the qa-tools repo from the global variables with the given
#   commit hash.
# RETURN:
#   0 if succeeds, non-zero on error.
################################################################################
deploy_qa_tools() {
  git clone "${QA_REPO}" ${QA_REPO_NAME}
  cd ${QA_REPO_NAME} && git checkout "${QA_REFSPEC}" && cd ..
}


################################################################################
# Builds or downloads the QA Code Coverage Tool
# GLOBALS:
#   CODE_COVERAGE_FOLDER, QA_REPO, QA_REPO_NAME, QA_REFSPEC, FALLBACK_PLUGIN_URL
# ARGUMENTS:
#   None
# OUTPUTS:
#   Creates coverage folder and builds/downloads there the plugin binaries.
#   It exports the binary plugin location to coverage_trace_plugin.
# RETURN:
#   0 if succeeds, non-zero on error.
################################################################################
build_tool() {
  echo "Building QA Code coverage tool..."
  PLUGIN_BINARY="${FALLBACK_FILES%%,*}" # The first in the list of the binary files
  local PVLIB_HOME="warehouse/SysGen/PVModelLib/$model_version/$model_build/external"
  local LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CODE_COVERAGE_FOLDER
  mkdir -p ${CODE_COVERAGE_FOLDER}
  pushd "${CODE_COVERAGE_FOLDER}"
  deploy_qa_tools
  local cc_source=$(find . -type f -name 'coverage_trace.cc')
  echo "Warehouse=${warehouse}"

  IFS=',' read -r -a files <<< "$FALLBACK_FILES"
  for file in "${files[@]}"; do
      url="${FALLBACK_PLUGIN_URL}/${file}" \
        saveas="${CODE_COVERAGE_FOLDER}/${file}" \
        fetch_file
  done

  ls -al
  export coverage_trace_plugin="${CODE_COVERAGE_FOLDER}/${PLUGIN_BINARY}"
  popd
}

  ################################################################################
  # Creates configuration file for intermediate layer generation
  # GLOBALS:
  #   PROJECT, CONFIG_JSON, INTERMEDIATE_LAYER_FILE, CODE_COVERAGE_FOLDER
  # ARGUMENTS:
  #   $1 Folder where are the elf/axf files.
  #   $2 List of elf/axf file names.
  #   $3 Path for trace files.
  #   $4 Root folder name where all the repos are cloned.
  # OUTPUTS:
  #   Creates coverage folder and builds/downloads there the plugin binaries.
  # RETURN:
  #   0 if succeeds, non-zero on error.
  ################################################################################
create_config_json() {
  set +e
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
  then
    cat << END
Missing argument at '${FUNCNAME[0]}'.
USAGE:
  create_config_json ' Glob binaries' 'Glob trace files' 'Repos root folder name'
  Example:
    create_config_json 'bl1.elf bl2.elf' 'tf'
END
    exit 1
  fi
  local ELF_FOLDER=$1
  local dwarf_array=($2)
  local TRACE_FOLDER=$3
  local root_repos_foolder="${4:-$workspace}"
  local scm_sources=""

  # Obtaining binaries from array
  bin_section=""
  for index in "${!dwarf_array[@]}"
  do
      local elf_file="${ELF_FOLDER}/${dwarf_array[$index]}"
      cp "$elf_file" ${CODE_COVERAGE_FOLDER}/.
      read -r -d '' bin_section << EOM
${bin_section}
              {
                  "name": "$elf_file",
                  "traces": [
                              "${TRACE_FOLDER}/${TRACE_FILE_PREFIX:-covtrace}-*.log"
                            ]
              }
EOM
  if [ $index -lt $((${#dwarf_array[@]} - 1)) ];then
      bin_section="${bin_section},"
  fi
  done

  if [ "$PROJECT" = "SCP" ]; then
      read -r -d '' scm_sources << EOM
              [
                  {
                  "type": "git",
                  "URL":  "$CC_SCP_URL",
                  "COMMIT": "$CC_SCP_COMMIT",
                  "REFSPEC": "$CC_SCP_REFSPEC",
                  "LOCATION": "scp"
                  },
                  {
                  "type": "git",
                  "URL":  "$CC_CMSIS_URL",
                  "COMMIT": "$CC_CMSIS_COMMIT",
                  "REFSPEC": "$CC_CMSIS_REFSPEC",
                  "LOCATION": "scp/contrib/cmsis/git"
                  }
              ]
EOM
elif [ "$PROJECT" = "TF-A" ]; then
      read -r -d '' scm_sources << EOM
              [
                  {
                  "type": "git",
                  "URL":  "$CC_TRUSTED_FIRMWARE_URL",
                  "COMMIT": "$CC_TRUSTED_FIRMWARE_COMMIT",
                  "REFSPEC": "$CC_TRUSTED_FIRMWARE_REFSPEC",
                  "LOCATION": "trusted_firmware"
                  },
                  {
                  "type": "http",
                  "URL":  "$mbedtls_archive",
                  "COMPRESSION": "xz",
                  "EXTRA_PARAMS": "--strip-components=1",
                  "LOCATION": "mbedtls"
                  }
              ]
EOM
elif [ "$PROJECT" = "HAFNIUM" ]; then
      read -r -d '' scm_sources << EOM
              [
                  {
                  "type": "git",
                  "URL":  "$CC_TRUSTED_FIRMWARE_URL",
                  "COMMIT": "$CC_TRUSTED_FIRMWARE_COMMIT",
                  "REFSPEC": "$CC_TRUSTED_FIRMWARE_REFSPEC",
                  "LOCATION": "trusted_firmware"
                  },
                  {
                  "type": "git",
                  "URL":  "$CC_SPM_URL",
                  "COMMIT": "$CC_SPM_COMMIT",
                  "REFSPEC": "$CC_SPM_REFSPEC",
                  "LOCATION": "spm"
                  }
              ]
EOM
  else
      echo "SCM sources not provided for project '${PROJECT}'"
      exit 1
  fi
local metadata="\"BUILD_CONFIG\": \"${BUILD_CONFIG}\", \"RUN_CONFIG\": \"${RUN_CONFIG}\""
cat <<EOF > "${CONFIG_JSON}"
{
  "configuration":
      {
      "remove_workspace": true,
      "include_assembly": true
      },
  "parameters":
      {
      "objdump": "${OBJDUMP}",
      "readelf": "${READELF}",
      "sources": $scm_sources,
      "workspace": "${root_repos_foolder}",
      "output_file": "${INTERMEDIATE_LAYER_FILE}",
      "metadata": {$metadata}
      },
  "elfs": [
          ${bin_section}
      ]
}
EOF

}

################################################################################
# Creates intermediate layer json file with trace coverage data.
#
# Creates a configuration JSON file to be the input for the intermediate
# layer file creation.
# GLOBALS:
#   TRACE_FILE_PREFIX, CODE_COVERAGE_FOLDER
# ARGUMENTS:
#   $1 Location of trace files.
#   $2 Location of elf/axf files.
#   $3 List of binaries to be checked the traces.
#   $4 Root folder name where all the repos are cloned.
# OUTPUTS:
#   A configuration JSON file.
#   An intermediate layer JSON  file.
# RETURN:
#   0 if succeeds, non-zero on error.
################################################################################
create_intermediate_layer() {
  local TRACE_FOLDER="$1"
  local ELF_FOLDER="$2"
  local LIST_OF_BINARIES="$3"
  local root_repos_foolder="$4"

  # Copying trace files into the qa-tools executables folder
  if [ $(ls -1 ${TRACE_FOLDER}/${TRACE_FILE_PREFIX}-* 2>/dev/null | wc -l) != 0 ]; then
    cp ${TRACE_FOLDER}/${TRACE_FILE_PREFIX}-* ${CODE_COVERAGE_FOLDER}/.
  else
    echo "Trace files not present, aborting reports..."
    ls -al ${TRACE_FOLDER}
    exit -1
  fi
  create_config_json "${ELF_FOLDER}" "${LIST_OF_BINARIES}" "${TRACE_FOLDER}" "$root_repos_foolder"
  python3 ${CODE_COVERAGE_FOLDER}/qa-tools/coverage-tool/coverage-reporting/intermediate_layer.py \
    --config-json ${CONFIG_JSON}

}


################################################################################
# Creates LCOV coverage report.
# GLOBALS:
#   CODE_COVERAGE_FOLDER, workspace, INTERMEDIATE_LAYER_FILE, INFO_FILE,
#   REPORT_FOLDER
# ARGUMENTS:
#   None
# OUTPUTS:
#   A coverage info file.
#   LCOV HTML coverage report.
# RETURN:
#   0 if succeeds, non-zero on error.
################################################################################
create_coverage_report() {
	python3 ${CODE_COVERAGE_FOLDER}/qa-tools/coverage-tool/coverage-reporting/generate_info_file.py \
	--workspace ${workspace} --json ${INTERMEDIATE_LAYER_FILE} --info ${INFO_FILE}
	genhtml --branch-coverage ${INFO_FILE} --output-directory ${REPORT_FOLDER}
}
