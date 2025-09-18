#!/usr/bin/env bash
#
# Copyright (c) 2019-2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set +x
REPORT_JSON=$1
REPORT_HTML=$2

if echo "$JENKINS_PUBLIC_URL" | grep -q "oss.arm.com"; then
  ARTIFACT_PATH='artifact/html/qa-code-coverage'
  INFO_PATH='coverage.info'
  JSON_PATH='intermediate_layer.json'
else
  ARTIFACT_PATH='artifact'
  INFO_PATH='trace_report/coverage.info'
  JSON_PATH='config_file.json'
fi

###############################################################################
# Create json file for input to the merge.sh for Code Coverage
# Globals:
#   REPORT_JSON: Json file with TF ci gateway builder test results
#   ARTIFACT_PATH: Path in the Jenkins node where the artifacts files reside
#   TEST_GROUPS: Env variable from Jenkins to indicate the test groups configurations
#   JSON_PATH: Path in the Jenkins node where the json file reside
#   INFO_PATH: Path in the Jenkins node where the info file reside
# Arguments:
#   1: Pattern to match files from the test configurations to be merged (in)
#   2: Resultant merge configuration file name (out)
# Outputs:
#   Print number of files to be merged
###############################################################################
create_merge_cfg() {
  local merge_pattern="$1"
  local merge_file="$2"
python3 - << EOF
import json
import os
import re

server = os.getenv("JENKINS_PUBLIC_URL", "https://jenkins.oss.arm.com/")
merge_json = {} # json object
_files = []
with open("$REPORT_JSON") as json_file:
    data = json.load(json_file)
merge_number = 0
test_results = data['test_results']
test_files = data['test_files']
for index, build_number in enumerate(test_results):
    if ("bmcov" in test_files[index] or "code-coverage" in test_files[index]) \
    and test_results[build_number] == "SUCCESS" \
    and re.search(r"$merge_pattern", test_files[index]):
        merge_number += 1
        base_url = "{}job/{}/{}/{}".format(
                        server, data['job'], build_number, "$ARTIFACT_PATH")
        _group_test_config = re.match(f'^[0-9%]*(?:${TEST_GROUPS}%)?(.+?)\.test', test_files[index])
        tf_configuration = _group_test_config.groups()[0] if _group_test_config else 'N/A'
        _files.append( {'id': build_number,
                        'config': {
                                    'type': 'http',
                                    'origin': "{}/{}".format(
                                        base_url, "$JSON_PATH")
                                    },
                        'info': {
                                    'type': 'http',
                                    'origin': "{}/{}".format(
                                        base_url, "$INFO_PATH")
                                },
                         'run-configuration': tf_configuration
                        })
merge_json = { 'files' : _files }
with open("${merge_file}", 'w') as outfile:
    json.dump(merge_json, outfile, indent=4)
print(merge_number)
EOF
}

generate_styles() {
  local out_report=$1
  cat <<EOT >> "$out_report"
  <style>
  .dropbtn {
    background-color: #04AA6D;
    color: white;
    padding: 16px;
    font-size: 16px;
    border: none;
  }

  /* The container <div> - needed to position the dropdown content */
  .dropdown {
    position: relative;
    display: inline-block;
  }

  /* Dropdown Content (Hidden by Default) */
  .dropdown-content {
    display: none;
    position: absolute;
    background-color: #f1f1f1;
    min-width: 160px;
    box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2);
    z-index: 1;
  }

  /* Links inside the dropdown */
  .dropdown-content a {
    color: black;
    padding: 12px 16px;
    text-decoration: none;
    display: block;
  }

  /* Change color of dropdown links on hover */
  .dropdown-content a:hover {background-color: #ddd;}

  /* Show the dropdown menu on hover */
  .dropdown:hover .dropdown-content {display: block;}

  /* Change the background color of the dropdown button when the dropdown content is shown */
  .dropdown:hover .dropbtn {background-color: #3e8e41;}
  </style>
  <div id="div-code-coverage-header">
    <br>
    <hr>
    <br>
    <h2>Code Coverage Summary</h2>
    <hr>
  </div>
  <script>
      document.getElementById('tf-report-main').appendChild(document.getElementById("div-code-coverage-header"));
  </script>
EOT

}

###############################################################################
# Append a summary table to an html file (report)that will be interpreted by
# the Jenkins html plugin
#
# If there is more than one code coverage report and is merged  successfully,
# then a summary html/javascript table is created at the end of the
# html file containing the merged function, line and branch coverage
# percentages.
# Globals:
#   OUTDIR: Path where the output folders are
#   build_config_folder: Folder name where the LCOV files are
#   REPORT_JSON: Json file with TF ci gateway builder test results
#   jenkins_archive_folder: Folder name where Jenkins archives files
#   list_of_merged_builds: Array with a list of individual successfully merged
#                          jenkins build id's (Comes from merge.sh)
#   number_of_files_to_merge: Indicates the number of individual jobs that have
#                             code coverage and ran successfully
# Arguments:
#   1: HTML report to be appended the summary table
# Outputs:
#   Appended HTML file with the summary table of merged code coverage
###############################################################################
generate_code_coverage_summary() {
    local out_report=$1
    local configuration_json_file_name=$2
    local cov_html=${OUTDIR}/${build_config_folder}/index.html

python3 - << EOF
import re
import json
cov_html="$cov_html"
out_report = "$out_report"
confs = ""
with open("$REPORT_JSON") as json_file:
    data = json.load(json_file)

with open(cov_html, "r") as f:
    html_content = f.read()
items = ["Lines", "Functions", "Branches"]
s = """
    <div id="div-$configuration_json_file_name">
    <br>
    <h3>Run confs in '$configuration_json_file_name'</h3>
    <br>
        <table id="table-$configuration_json_file_name">
              <tbody>
                <tr>
                    <td>Type</td>
                    <td>Hit</td>
                    <td>Total</td>
                    <td>Coverage</td>
              </tr>
"""
for item in items:
    data = re.findall(r'<td class="headerItem">{}:</td>\n\s+<td class="headerCovTableEntry">(.+?)</td>\n\s+<td class="headerCovTableEntry">(.+?)</td>\n\s+'.format(item),
    html_content, re.DOTALL)
    if data is None:
        continue
    hit, total = data[0]
    if float(total) < 1:
        cov = 0
    else:
        cov = round(float(hit)/float(total) * 100.0, 2)
    color = "success"
    if cov < 90:
        color = "unstable"
    if cov < 75:
        color = "failure"
    s = s + """
                <tr>
                    <td>{}</td>
                    <td>{}</td>
                    <td>{}</td>
                    <td class='{}'>{} %</td>
                </tr>
""".format(item, hit, total, color, cov)
s = s + """
            </tbody>
        </table>
        <p>
        <button onclick="window.open('artifact/${jenkins_archive_folder}/${build_config_folder}/index.html','_blank');">Coverage Report (${#list_of_merged_builds[@]} out of ${number_of_files_to_merge} run confs)</button>
        </p>
    </div>

<script>
    document.getElementById('tf-report-main').appendChild(document.getElementById("div-$configuration_json_file_name"));
</script>

"""
with open(out_report, "a") as f:
    f.write(s)
EOF
}

###############################################################################
# Append a column for each row corresponding to each build with a successful
# code coverage report
#
# The column contains an html button that links to the individual code coverage
# html report or 'N/A' if report cannot be found or build was a failure.
# The column is added to the main table where all the tests configurations
# status are shown.
# Globals:
#   full_list: Array with a list of individual successfully merged
#                          jenkins build id's
#   individual_report_folder: Location within the jenkins job worker where
#                             resides the code coverage html report.
# Arguments:
#   1: HTML report to be appended the summary table
# Outputs:
#   Appended HTML file with the column added to the main hmtl table
###############################################################################
generate_code_coverage_column() {
  echo "List of merged build ids:${full_list[@]}"
python3 - << EOF
merged_ids=[int(i) for i in "${full_list[@]}".split()]
s = """
  <script>
  window.onload = function() {
  """ + f"const mergedIds={merged_ids}" + """
  document.querySelector('#tf-report-main table').querySelectorAll("tr").forEach((row, i) => {
      const cell = document.createElement(i ? "td" : "th")
      const button = document.createElement("button")
      button.textContent = "Report"
      if (i) {
          merged = false
          td = row.querySelector('td.success, td.failure')
          if (td) {
              if ((results = td.getElementsByClassName("result")) && results && results[0].text.toUpperCase() != "FAILURE" && (links = td.getElementsByClassName("buildlink"))) {
                  href = links[0].href
                  buildId = href.split("/").at(-2)
                  if (mergedIds.includes(Number(buildId))) {
                      cell.classList.add("success")
                      const url = href.replace('console', 'artifact/${individual_report_folder}')
                      button.addEventListener('click', () => {
                          window.open(url, "_blank")
                      })
                      cell.appendChild(button)
                      merged = true
                  }

                  if (!merged) {
                      cell.innerText = "N/A"
                      cell.classList.add("failure")
                  }
              }
          }
      } else {
          cell.innerText = "Code Coverage"
      }
      row.appendChild(cell)
  })
  }
  </script>
"""
with open("$1", "a") as f:
    f.write(s)
EOF
}


OUTDIR=""
index=""
ls -al
include_only_patterns=""
case "$TEST_GROUPS" in
    scp*)
            project="scp"
            jenkins_archive_folder=reports
            individual_report_folder=html/qa-code-coverage/lcov/index.html
            run_config_files=("scp-configuration.json")
            run_config_patterns=(".*")
            ;;
    tfut*)
            project="tfut"
            jenkins_archive_folder=merge/outdir
            individual_report_folder=unit_tests/trusted-firmware-a-coverage/index.html
            ;;
    tf*)
            project="trusted_firmware"
            jenkins_archive_folder=merge/outdir
            individual_report_folder=trace_report/index.html
            run_config_files=("tf-configuration.json" "spm-configuration.json")
            run_config_patterns=(".*" ".+?%(fvp-spm.+):.+")
            include_only_patterns=('trusted-firmware-a/*' 'spm/*')
            ;;
    spm*)
            project="hafnium"
            jenkins_archive_folder=merge/outdir
            individual_report_folder=trace_report/index.html
            run_config_files=("hafnium-configuration.json")
            run_config_patterns=( ".+?%(fvp-spm.+):.+")
            include_only_patterns=('spm/*')
            ;;
    *)
            exit 0;;
esac
# Folder in the node where all the input/output files for code coverage reside
# and where can be archived
OUTDIR=${WORKSPACE}/${jenkins_archive_folder}
source "$CI_ROOT/script/qa-code-coverage.sh"
# Folder for each project (TF Build Config) input/output files
build_config_folder=lcov
cd $WORKSPACE
deploy_qa_tools
cd -
mkdir -p $OUTDIR
pushd $OUTDIR
    export full_list=()
    for (( i=0; i<${#run_config_files[*]}; ++i)); do
      run_config_name=${run_config_files[$i]/.json/}
      build_config_folder="$run_config_name"
      mkdir -p "${OUTDIR}/${build_config_folder}"
      run_config_file="${OUTDIR}/input-${run_config_files[$i]}"
      number_of_files_to_merge=$(create_merge_cfg "${run_config_patterns[$i]}" "${run_config_file}")
      echo "Merging from $number_of_files_to_merge code coverage reports..."
      # Only merge when more than 1 test result
      if [ "$number_of_files_to_merge" -lt 2 ]; then
          echo "Only one file to merge."
          continue
      fi
      sources_folder="${OUTDIR}/${build_config_folder}/sources"
      include_only_pattern="${include_only_patterns[$i]:+$sources_folder/${include_only_patterns[$i]}}"
      mkdir -p "${sources_folder}"
      source ${WORKSPACE}/qa-tools/coverage-tool/coverage-reporting/merge.sh \
         -j ${run_config_file} -l ${OUTDIR}/${build_config_folder} \
         -w "${sources_folder}" -c -i \
         -o "${OUTDIR}/${build_config_folder}/merged-${run_config_name}.info" \
         -m "${OUTDIR}/${build_config_folder}/merged-${run_config_name}-scm.json" \
         $([ -n "$include_only_pattern" ] && echo " -e $include_only_pattern")
     # backward compatibility with old qa-tools
     [ $? -eq 0 ] && status=true || status=false
     # merged_status is set at 'merge.sh' indicating if merging reports was ok
     if ${merged_status:-$status}; then
       full_list+=( "${list_of_merged_builds[@]}" ) # Comes from merge.sh
       [ $i -eq 0 ] && generate_styles "${REPORT_HTML}"
        generate_code_coverage_summary "${REPORT_HTML}" "${run_config_name}"
      fi
    done
    generate_code_coverage_column "${REPORT_HTML}"
    cp "${REPORT_HTML}" "$OUTDIR"

popd
