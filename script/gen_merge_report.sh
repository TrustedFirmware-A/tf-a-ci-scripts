#!/usr/bin/env bash
#
# Copyright (c) 2019-2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

REPORT_JSON=$1
REPORT_HTML=$2
TEST_DEF_FOLDER="${WORKSPACE}/test-definitions"

if echo "$JENKINS_PUBLIC_URL" | grep -q "oss.arm.com"; then
ARTIFACT_PATH='artifact/html'
INFO_PATH='lcov_report/coverage.info'
JSON_PATH='output_file.json'
else
ARTIFACT_PATH='artifact'
INFO_PATH='trace_report/coverage.info'
JSON_PATH='config_file.json'
fi

BRANCH_FOLDER="scripts/tools/code_coverage/fastmodel_baremetal/bmcov/report/branch_coverage"
BMCOV_REPORT_FOLDER="$OUTDIR/$TEST_DEF_FOLDER/scripts/tools/code_coverage/fastmodel_baremetal/bmcov/report"

#################################################################
# Create json file for input to the merge.sh for Code Coverage
# Globals:
#   REPORT_JSON: Json file for SCP and TF ci gateway test results
#   MERGE_JSON: Json file to be used as input to the merge.sh
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
    if "bmcov" in test_files[index] and test_results[build_number] == "SUCCESS":
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
with open("$MERGE_JSON", 'w') as outfile:
    json.dump(merge_json, outfile)
print(merge_number)
EOF
}

generate_bmcov_header() {
    cov_html=$1
    out_report=$2
python3 - << EOF
import re
cov_html="$cov_html"
out_report = "$out_report"
with open(cov_html, "r") as f:
    html_content = f.read()
items = ["Lines", "Functions", "Branches"]
s = """
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
        <button onclick="window.open('artifact/$index/index.html','_blank');">Coverage Report</button>
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
OUTDIR=""
index=""
case "$TEST_GROUPS" in
    scp*)
            project="scp"
            OUTDIR=${WORKSPACE}/reports
            index=reports;;
    tf*)
            project="trusted_firmware"
            OUTDIR=${WORKSPACE}/merge/outdir
            index=merge/outdir;;
    *)
            exit 0;;
esac
export MERGE_JSON="$OUTDIR/merge.json"
source "$CI_ROOT/script/test_definitions.sh"
mkdir -p $OUTDIR
pushd $OUTDIR
    merge_files=$(create_merge_cfg)
    echo "Merging $merge_files coverage files..."
    # Only merge when more than 1 test result
    if [ "$merge_files" -lt 2 ] ; then
        exit 0
    fi
    git clone $TEST_DEFINITIONS_REPO $TEST_DEF_FOLDER
    pushd $TEST_DEF_FOLDER
        git checkout $TEST_DEFINITIONS_REFSPEC
    popd

    if echo "$JENKINS_PUBLIC_URL" | grep -q "oss.arm.com"; then
    bash $TEST_DEF_FOLDER/scripts/tools/code_coverage/fastmodel_baremetal/bmcov/report/branch_coverage/merge.sh \
        -j $MERGE_JSON -l ${OUTDIR} -p $project
    else
    bash $TEST_DEF_FOLDER/coverage-tool/coverage-reporting/merge.sh \
        -j $MERGE_JSON -l ${OUTDIR} -w $SHARE_FOLDER
    fi

    generate_bmcov_header ${OUTDIR}/index.html ${REPORT_HTML}
    cp ${REPORT_HTML} $OUTDIR
popd
