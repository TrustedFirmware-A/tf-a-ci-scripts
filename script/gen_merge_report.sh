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

#################################################################
# Create json file for input to the merge.sh for Code Coverage
# Globals:
#   REPORT_JSON: Json file for SCP and TF ci gateway test results
#   MERGE_CONFIGURATION: Json file to be used as input to the merge.sh
# Arguments:
#   None
# Outputs:
#   Print number of files to be merged
################################################################
create_merge_cfg() {
python3 - << EOF
import json
import os

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
    "code-coverage" in test_files[index]) and test_results[build_number] == "SUCCESS":
        merge_number += 1
        base_url = "{}job/{}/{}/{}".format(
                        server, data['job'], build_number, "$ARTIFACT_PATH")
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
                                }
                        })
merge_json = { 'files' : _files }
with open("$MERGE_CONFIGURATION", 'w') as outfile:
    json.dump(merge_json, outfile, indent=4)
print(merge_number)
EOF
}

generate_header() {
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
test_files = data['test_files']
test_results = data['test_results']
for index, build_number in enumerate(test_results):
  test_file = test_files[index]
  test_configuration = test_file.rsplit('%', 1)
  if len(test_configuration) > 1:
    confs += '<a target="_blank" href="artifact/${jenkins_archive_folder}/${COVERAGE_FOLDER}/{}/index.html">{}</a>'.format(build_number,
      test_configuration[1])

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
        <button onclick="window.open('artifact/${jenkins_archive_folder}/${COVERAGE_FOLDER}/index.html','_blank');">Total Coverage Report</button>
        </p>
        <div class="dropdown">
          <button class="dropbtn">Coverage Reports($number_of_files_to_merge)</button>
          <div class="dropdown-content">
          """ + confs + """
          </div>
        </div>
    </div>

<script>
    document.getElementById('tf-report-main').appendChild(document.getElementById("div-cov"));
</script>

"""
with open(out_report, "a") as f:
    f.write(s)
EOF
}
OUTDIR=""
index=""
case "$TEST_GROUPS" in
    scp*)
            project="scp"
            jenkins_archive_folder=reports;;
    tf*)
            project="trusted_firmware"
            jenkins_archive_folder=merge/outdir;;
    spm*)
            project="hafnium"
            jenkins_archive_folder=merge/outdir;;
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
    echo "Merging $number_of_files_to_merge coverage files..."
    # Only merge when more than 1 test result
    if [ "$number_of_files_to_merge" -lt 2 ] ; then
        echo "Only one file to merge."
        exit 0
    fi

    bash ${WORKSPACE}/qa-tools/coverage-tool/coverage-reporting/merge.sh \
        -j $MERGE_CONFIGURATION -l ${OUTDIR}/${COVERAGE_FOLDER} -w $WORKSPACE -c -g

    generate_header ${REPORT_HTML}
    cp ${REPORT_HTML} $OUTDIR
popd
