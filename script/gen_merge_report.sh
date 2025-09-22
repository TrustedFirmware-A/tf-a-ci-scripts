#!/usr/bin/env bash
#
# Copyright (c) 2019-2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -x
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
#   MERGE_CONFIGURATION: Json file to be used as input to the merge.sh
# Arguments:
#   None
# Outputs:
#   Print number of files to be merged
###############################################################################
create_merge_cfg() {
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
    if ("bmcov" in test_files[index] or
    "coverage" in test_files[index]) and test_results[build_number] == "SUCCESS":
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
                         'tf-configuration': tf_configuration
                        })
merge_json = { 'files' : _files }
with open("$MERGE_CONFIGURATION", 'w') as outfile:
    json.dump(merge_json, outfile, indent=4)
print(merge_number)
EOF
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
#   COVERAGE_FOLDER: Folder name where the LCOV files are
#   REPORT_JSON: Json file with TF ci gateway builder test results
#   jenkins_archive_folder: Folder name where Jenkins archives files
#   list_of_merged_builds: Array with a list of individual successfully merged
#                          jenkins build id's
#   number_of_files_to_merge: Indicates the number of individual jobs that have
#                             code coverage and ran successfully
# Arguments:
#   1: HTML report to be appended the summary table
# Outputs:
#   Appended HTML file with the summary table of merged code coverage
###############################################################################
generate_code_coverage_summary() {
    local cov_html=${OUTDIR}/${COVERAGE_FOLDER}/index.html
    local out_report=$1
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
    <div id="div-cov">
    <hr>
        <table id="table-cov">
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
        <button onclick="window.open('artifact/${jenkins_archive_folder}/${COVERAGE_FOLDER}/index.html','_blank');">Total Coverage Report (${#list_of_merged_builds[@]} out of ${number_of_files_to_merge})</button>
        </p>
    </div>

<script>
    document.getElementById('tf-report-main').appendChild(document.getElementById("div-cov"));
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
#   list_of_merged_builds: Array with a list of individual successfully merged
#                          jenkins build id's
#   individual_report_folder: Location within the jenkins job worker where
#                             resides the code coverage html report.
# Arguments:
#   1: HTML report to be appended the summary table
# Outputs:
#   Appended HTML file with the column added to the main hmtl table
###############################################################################
generate_code_coverage_column() {
  echo "List of merged build ids:${list_of_merged_builds[@]}"
python3 - << EOF
merged_ids=[int(i) for i in "${list_of_merged_builds[@]}".split()]
s = """

  <script>
  window.onload = function() {
  """ + f"const mergedIds={merged_ids}" + """
    document.querySelector('#tf-report-main table').querySelectorAll("tr").forEach((row,i) => {
    const cell = document.createElement(i ? "td" : "th")
    const button = document.createElement("button")
    button.textContent = "Report"
    if (i) {
        merged = false
        if (q = row.querySelector('td.success a.buildlink')) {
          href = q.href
          buildId = Number(href.split("/").at(-2))
          if (mergedIds.includes(buildId)) {
              cell.classList.add("success")
              const url = href.replace('console', 'artifact/${individual_report_folder}')
              button.addEventListener('click', () => {
                  window.open(url, "_blank")
              })
              cell.appendChild(button)
              merged = true
          }
        }
        if (!merged) {
            cell.innerText = "N/A"
            cell.classList.add("failure")
        }
    }
    else {
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
case "$TEST_GROUPS" in
    scp*)
            project="scp"
            jenkins_archive_folder=reports
            individual_report_folder=html/qa-code-coverage/lcov/index.html
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
            ;;
    spm*)
            project="hafnium"
            jenkins_archive_folder=merge/outdir
            individual_report_folder=trace_report/index.html
            ;;
    *)
            exit 0;;
esac
OUTDIR=${WORKSPACE}/${jenkins_archive_folder}
source "$CI_ROOT/script/qa-code-coverage.sh"
export MERGE_CONFIGURATION="$OUTDIR/merge_configuration.json"
COVERAGE_FOLDER=lcov
cd $WORKSPACE
deploy_qa_tools
cd -
mkdir -p $OUTDIR
pushd $OUTDIR
    number_of_files_to_merge=$(create_merge_cfg)
    echo "Merging from $number_of_files_to_merge code coverage reports..."
    # Only merge when more than 1 test result
    if [ "$number_of_files_to_merge" -lt 2 ]; then
        echo "Only one file to merge."
        exit 0
    fi

     source ${WORKSPACE}/qa-tools/coverage-tool/coverage-reporting/merge.sh \
        -j $MERGE_CONFIGURATION -l ${OUTDIR}/${COVERAGE_FOLDER} \
        -w $WORKSPACE -c -i -d
    # backward compatibility with old qa-tools
    [ $? -eq 0 ] && status=true || status=false

    # merged_status is set at 'merge.sh' indicating if merging reports was ok
    ${merged_status:-$status} && generate_code_coverage_summary "${REPORT_HTML}"
    generate_code_coverage_column "${REPORT_HTML}" || true
    cp "${REPORT_HTML}" "$OUTDIR"
popd
