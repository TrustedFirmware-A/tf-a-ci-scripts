#!/usr/bin/env python3
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generate a test report from data inferred from Jenkins environment. The
# generated HTML file is meant for inclusion in the report status page,
# therefore isn't standalone, fully-formed, HTML.

import argparse
import collections
import json
import io
import os
import re
import shutil
import sys
import urllib.request

PAGE_HEADER = """\
<div id="tf-report-main">
<table>
"""

PAGE_FOOTER = """\
</tbody>
</table>
</div> <!-- tf-report-main -->

<table id="tf-rebuild-table"><tbody>
<tr><td colspan="2" class="select-row">
  Select tests by result:
  <span class="select-all">None</span>
  &nbsp;|&nbsp;
  <span class="select-all success">SUCCESS</span>
  &nbsp;|&nbsp;
  <span class="select-all unstable">UNSTABLE</span>
  &nbsp;|&nbsp;
  <span class="select-all failure">FAILURE</span>
</td></tr>
<tr>
  <td class="desc-col">
    Select build configurations, and click the button to re-trigger builds.
    <br />
    Use <b>Shift+Click</b> to alter parameters when re-triggering.
  </td>
  <td class="button-col">
    <input id="tf-rebuild-button" type="button" value="Rebuild selected configs"
      disabled count="0"/>
    <input id="tf-rebuild-all-button" type="button" value="Rebuild this job"/>
  </td>
</tr>
</tbody></table>

<div class="tf-label-container">
<div class="tf-label-label">&nbsp;Local commands&nbsp;</div>
<pre class="tf-label-cotent" id="tf-selected-commands">
<i>Hover over test results to display equivalent local commands.</i>
</pre>
</div> <!-- tf-label-container -->

<iframe id="tf-rebuild-frame" style="display: none"></iframe>
"""

TEST_SUFFIX = ".test"
REPORT = "report.html"
REPORT_JSON = "report.json"

# Maximum depth for the tree of results, excluding status
MAX_RESULTS_DEPTH = 5

# We'd have a minimum of 3: group, a build config, a run config.
MIN_RESULTS_DEPTH = 3

# Table header corresponding to each level, starting from group. Note that
# the result is held in the leaf node itself, and has to appear in a column of
# its own.
LEVEL_HEADERS = [
        "Test Group",
        "TF Build Config",
        "TFTF Build Config",
        "SPM Build Config",
        "Run Config",
        "Status"
]

Jenkins = None
Dimmed_hypen = None
Build_job = None
Job = None

# Indicates whether a level of table has no entries. Assume all levels are empty
# to start; and flip that around as and when we see otherwise.
Level_empty = [True] * MAX_RESULTS_DEPTH
assert len(LEVEL_HEADERS) == (MAX_RESULTS_DEPTH + 1)

# A column is deemed empty if it's content is empty or is the string "nil"
is_empty = lambda key: key in ("", "nil")

# A tree of ResultNodes are used to group test results by config. The tree is
# MAX_RESULTS_DEPTH levels deep. Levels above MAX_RESULTS_DEPTH groups results,
# where as those at MAX_RESULTS_DEPTH (leaves) hold test result and other meta
# data.
class ResultNode:
    def __init__(self, depth=0):
        self.depth = depth
        self.printed = False
        if depth == MAX_RESULTS_DEPTH:
            self.result = None
            self.build_number = None
            self.desc = None
        else:
            self.num_children = 0
            self.children = collections.OrderedDict()

    # For a grouping node, set child by key.
    def set_child(self, key):
        assert self.depth < MAX_RESULTS_DEPTH

        self.num_children += 1
        if not is_empty(key):
            Level_empty[self.depth] = False
        return self.children.setdefault(key, ResultNode(self.depth + 1))

    # For a leaf node, set result and other meta data.
    def set_result(self, result, build_number):
        assert self.depth == MAX_RESULTS_DEPTH

        self.result = result
        self.build_number = build_number

    def set_desc(self, desc):
        self.desc = desc

    def get_desc(self):
        return self.desc

    # For a grouping node, return dictionary iterator.
    def items(self):
        assert self.depth < MAX_RESULTS_DEPTH

        return self.children.items()

    # Generator function that walks through test results. The output of
    # iteration is reflected in the stack argument, which ought to be a deque.
    def iterator(self, key, stack):
        stack.append((key, self))
        if self.depth < MAX_RESULTS_DEPTH:
            for child_key, child in self.items():
                yield from child.iterator(child_key, stack)
        else:
            yield
        stack.pop()

    # Convenient child access during debugging.
    def __getitem__(self, key):
        assert self.depth < MAX_RESULTS_DEPTH

        return self.children[key]

    # Print convenient representation for debugging.
    def __repr__(self):
        if self.depth < MAX_RESULTS_DEPTH:
            return "node(depth={}, nc={}, {})".format(self.depth,
                    self.num_children,
                    ("None" if self.children is None else
                        list(self.children.keys())))
        else:
            return ("result(" +
                    ("None" if self.result is None else str(self.result)) + ")")


# Open an HTML element, given its name, content, and a dictionary of attributes:
# <name foo="bar"...>
def open_element(name, attrs=None):
    # If there are no attributes, return the element right away
    if attrs is None:
        return "<" + name + ">"

    el_list = ["<" + name]

    # 'class', being a Python keyword, can't be passed as a keyword argument, so
    # is passed as 'class_' instead.
    if "class_" in attrs:
        attrs["class"] = attrs["class_"]
        del attrs["class_"]

    for key, val in attrs.items():
        if val is not None:
            el_list.append(' {}="{}"'.format(key, val))

    el_list.append(">")

    return "".join(el_list)


# Close an HTML element
def close_element(name):
    return "</" + name + ">"


# Make an HTML element, given its name, content, and a dictionary of attributes:
# <name foo="bar"...>content</name>
def make_element(name, content="", **attrs):
    assert type(content) is str

    return "".join([open_element(name, attrs), content, close_element(name)])


# Wrap link in a hyperlink:
# <a href="link" foo="bar"... target="_blank">content</a>
def wrap_link(content, link, **attrs):
    return make_element("a", content, href=link, target="_blank", **attrs)


def jenkins_job_link(job, build_number):
    return "/".join([Jenkins, "job", job, build_number, ""])


# Begin table by emitting table headers for all levels that aren't empty, and
# results column. Finish by opening a tbody element for rest of the table
# content.
def begin_table(results, fd):
    # Iterate and filter out empty levels
    table_headers = []
    for level, empty in enumerate(Level_empty):
        if empty:
            continue
        table_headers.append(make_element("th", LEVEL_HEADERS[level]))

    # Result
    table_headers.append(make_element("th", LEVEL_HEADERS[level + 1]))

    row = make_element("tr", "\n".join(table_headers))
    print(make_element("thead", row), file=fd)
    print(open_element("tbody"), file=fd)


# Given the node stack, reconstruct the original config name
def reconstruct_config(node_stack):
    group = node_stack[0][0]
    run_config, run_node = node_stack[-1]

    desc = run_node.get_desc()
    try:
        with open(desc) as fd:
            test_config = fd.read().strip()
    except FileNotFoundError:
        print("warning: descriptor {} couldn't be opened.".format(desc),
                file=sys.stderr);
        return ""

    if group != "GENERATED":
        return os.path.join(group, test_config)
    else:
        return test_config


# While iterating results, obtain a trail to the current result. node_stack is
# iterated to identify the nodes contributing to one result.
def result_to_html(node_stack):
    global Dimmed_hypen

    crumbs = []
    for key, child_node in node_stack:
        if child_node.printed:
            continue

        child_node.printed = True

        # If the level is empty, skip emitting this column
        if not Level_empty[child_node.depth - 1]:
            # - TF config might be "nil" for TFTF-only build configs;
            # - TFTF config might not be present for non-TFTF runs;
            # - All build-only configs have runconfig as "nil";
            #
            # Make nil cells empty, and grey empty cells out.
            if is_empty(key):
                key = ""
                td_class = "emptycell"
            else:
                td_class = None

            rowspan = None
            if (child_node.depth < MAX_RESULTS_DEPTH
                    and child_node.num_children > 1):
                rowspan = child_node.num_children

            # Keys are hyphen-separated strings. For better readability, dim
            # hyphens so that text around the hyphens stand out.
            if not Dimmed_hypen:
                Dimmed_hypen = make_element("span", "-", class_="dim")
            dimmed_key = Dimmed_hypen.join(key.split("-"))

            crumbs.append(make_element("td", dimmed_key, rowspan=rowspan,
                class_=td_class))

        # For the last node, print result as well.
        if child_node.depth == MAX_RESULTS_DEPTH:
            # Make test result as a link to the job console
            result_class = child_node.result.lower()
            job_link = jenkins_job_link(Job, child_node.build_number)
            result_link = wrap_link(child_node.result, job_link,
                    class_="result")
            build_job_console_link = job_link + "console"

            # Add selection checkbox
            selection = make_element("input", type="checkbox")

            # Add link to build console if applicable
            if build_job_console_link:
                build_console = wrap_link("", build_job_console_link,
                        class_="buildlink", title="Click to visit build job console")
            else:
                build_console = ""

            config_name = reconstruct_config(node_stack)

            crumbs.append(make_element("td", (result_link + selection +
                build_console), class_=result_class, title=config_name))

    # Return result as string
    return "".join(crumbs)

# Emit style sheet, and script elements.
def emit_header(fd):
    stem = os.path.splitext(os.path.abspath(__file__))[0]
    for tag, ext in [("style", "css"), ("script", "js")]:
        print(open_element(tag), file=fd)
        with open(os.extsep.join([stem, ext])) as ext_fd:
            shutil.copyfileobj(ext_fd, fd)
        print(close_element(tag), file=fd)

def print_error_message(fd):
            # Upon error, create a static HTML reporting the error, and then raise
        # the latent exception again.
        fd.seek(0, io.SEEK_SET)

        # Provide inline style as there won't be a page header for us.
        err_style = (
                "border: 1px solid red;",
                "color: red;",
                "font-size: 30px;",
                "padding: 15px;"
                )

        print(make_element("div",
            "HTML report couldn't be prepared! Check job console.",
            style=" ".join(err_style)), file=fd)

        # Truncate file as we're disarding whatever there generated before.
        fd.truncate()

def main(fd):
    global Build_job, Jenkins, Job

    parser = argparse.ArgumentParser()

    # Add arguments
    parser.add_argument("--build-job", default=None, help="Name of build job")
    parser.add_argument("--from-json", "-j", default=None,
            help="Generate results from JSON input rather than from Jenkins run")
    parser.add_argument("--job", default=None, help="Name of immediate child job")
    parser.add_argument("--meta-data", action="append", default=[],
            help=("Meta data to read from file and include in report "
                "(file allowed be absent). "
                "Optionally prefix with 'text:' (default) or "
                "'html:' to indicate type."))

    opts = parser.parse_args()

    workspace = os.environ["WORKSPACE"]

    emit_header(fd)

    if not opts.from_json:
        json_obj = {}

        if not opts.job:
            raise Exception("Must specify the name of Jenkins job with --job")
        else:
            Job = opts.job
            json_obj["job"] = Job

        if not opts.build_job:
            raise Exception("Must specify the name of Jenkins build job with --build-job")
        else:
            Build_job = opts.build_job
            json_obj["build_job"] = Build_job

        Jenkins = os.environ["JENKINS_PUBLIC_URL"].strip().rstrip("/")

        # Replace non-alphabetical characters in the job name with underscores. This is
        # how Jenkins does it too.
        job_var = re.sub(r"[^a-zA-Z0-9]", "_", opts.job)

        # Build numbers are comma-separated list
        child_build_numbers = (os.environ["TRIGGERED_BUILD_NUMBERS_" +
            job_var]).split(",")

        # Walk the $WORKSPACE directory, and fetch file names that ends with
        # TEST_SUFFIX
        _, _, files = next(os.walk(workspace))
        test_files = sorted(filter(lambda f: f.endswith(TEST_SUFFIX), files))

        # Store information in JSON object
        json_obj["job"] = Job
        json_obj["build_job"] = Build_job
        json_obj["jenkins_url"] = Jenkins

        json_obj["child_build_numbers"] = child_build_numbers
        json_obj["test_files"] = test_files
        json_obj["test_results"] = {}
    else:
        # Load JSON
        with open(opts.from_json) as json_fd:
            json_obj = json.load(json_fd)

        Job = json_obj["job"]
        Build_job = json_obj["build_job"]
        Jenkins = json_obj["jenkins_url"]

        child_build_numbers = json_obj["child_build_numbers"]
        test_files = json_obj["test_files"]

    # This iteration is in the assumption that Jenkins visits the files in the same
    # order and spawns children, which is ture as of this writing. The test files
    # are named in sequence, so it's reasonable to expect that'll remain the case.
    # Just sayin...
    results = ResultNode(0)
    for i, f in enumerate(test_files):
        # Test description is generated in the following format:
        #   seq%group%build_config:run_config.test
        _, group, desc = f.split("%")
        test_config = desc[:-len(TEST_SUFFIX)]
        build_config, run_config = test_config.split(":")
        spare_commas = "," * (MAX_RESULTS_DEPTH - MIN_RESULTS_DEPTH)
        tf_config, tftf_config, spm_config, *_ = (build_config +
                spare_commas).split(",")

        build_number = child_build_numbers[i]
        if not opts.from_json:
            var_name = "TRIGGERED_BUILD_RESULT_" + job_var + "_RUN_" + build_number
            test_result = os.environ[var_name]
            json_obj["test_results"][build_number] = test_result
        else:
            test_result = json_obj["test_results"][build_number]

        # Build result tree
        group_node = results.set_child(group)
        tf_node = group_node.set_child(tf_config)
        tftf_node = tf_node.set_child(tftf_config)
        spm_node = tftf_node.set_child(spm_config)
        run_node = spm_node.set_child(run_config)
        run_node.set_result(test_result, build_number)
        run_node.set_desc(os.path.join(workspace, f))

    # Emit page header element
    print(PAGE_HEADER, file=fd)
    begin_table(results, fd)

    # Generate HTML results for each group
    node_stack = collections.deque()
    for group, group_results in results.items():
        node_stack.clear()

        # For each result, make a table row
        for _ in group_results.iterator(group, node_stack):
            result_html = result_to_html(node_stack)
            row = make_element("tr", result_html)
            print(row, file=fd)

    print(PAGE_FOOTER, file=fd)

    # Insert meta data into report. Since meta data files aren't critical for
    # the test report, and that other scripts may not generate all the time,
    # ignore if the specified file doesn't exist.
    type_to_el = dict(text="pre", html="div")
    for data_file in opts.meta_data:
        *prefix, filename = data_file.split(":")
        file_type = prefix[0] if prefix else "text"
        assert file_type in type_to_el.keys()

        # Ignore if file doens't exist, or it's empty.
        if not os.path.isfile(filename) or os.stat(filename).st_size == 0:
            continue

        with open(filename) as md_fd:
            md_name = make_element("div", "&nbsp;" + filename + ":&nbsp;",
                    class_="tf-label-label")
            md_content = make_element(type_to_el[file_type],
                    md_fd.read().strip("\n"), class_="tf-label-content")
            md_container = make_element("div", md_name + md_content,
                    class_="tf-label-container")
            print(md_container, file=fd)

    # Dump JSON file unless we're reading from it.
    if not opts.from_json:
        with open(REPORT_JSON, "wt") as json_fd:
            json.dump(json_obj, json_fd, indent=2)

if __name__ == "__main__":
    with open(REPORT, "wt") as fd:
        try:
            main(fd)
        except:
            print_error_message(fd)
            raise
