# Trusted Firmware-A CI scripts

This repository contains the scripts used to generate test firmware configs,
build binaries, and run them. This mainly targets the upstream CI at
`https://ci.trustedfirmware.org/` but also works locally.

These scripts are used to test TF-A and RF-A, but are also helpful for RMM,
TFTF, and Hafnium. This is a brief overview of how to navigate and use the
repository.

# Principle of operation

## Test group

A test group is a collection of CI configurations that are closely linked and
logically similar, usually a handful of configs. They can be found in `groups`
and are semantically named as such:

`{project}-a-[lts-version]-l{level}-{group-name}`

where

  - `project` is one of `tf-a` or `rf-a`
  - `lts-version` is in the form `lts-v2.XY` and is optional
  - `level` is one of 1, 2, or 3. Level 1 are tests that only build firmware,
    Level 2 are most tests that also run the binaries, and level 3 are extended
    tests.
  - `group-name` is an arbitrary name roughly representing the behaviour under
    test

for example `tf-a-l1-build-arm-fvp` or `tf-a-l2-functional-tftf-handoff-arm-fvp`

## Test configuration (aka config)

Test configuration concisely specifies a single test: what set of images to
build, how to build them, and finally, how to run a test using the these images.
A test configuration is a specially-named plain text file whose name comprises
of two parts: the build configuration and the run configuration. It is named in
the following format:

`{tf-config |
nil}[,tftf-config][,spm-config][,rmm-config][,rfa-config][,tfut-config]:{run-config
| nil}`

Where `nil` is the special name to skip this part. Optional configs can be
omitted, provided that configs after are omitted too. Each project's config is
looked up and loaded form the corresponding file in the project's folder. For
example:

`fvp-default,fvp-default:nil`

will use

`tf_config/fvp-default` for TF-A `tftf_config/fvp-default` for TFTF and it won't
be run

Build configurations are plain text files containing build parameters for a
component. The build parameters are listed one per line as they would appear on
the component's build command line verbatim.

Run config fragments are small shell scripts that implement callbacks called
hooks like `generate_lava_job` or `pre_tf_build` which are executing at specific
points in the configuration's lifetime. A run configuration essentially is
hyphen-separated fragments.

Given a run configuration, the mechanism to select fragments is simple enough: a
fragment F under run\_config/ directory is chosen if it forms a
[subsequence](https://en.wikipedia.org/wiki/Subsequence) of the run
configuration.

Example: the run configuration
`fvp-linux32-dtb.aarch32-fip.uboot32-aemv8a_revb.aarch32+regreset-debug`, the
following fragments are chosen: `fvp-linux32`, `fvp-dtb.aarch32`,
`fvp-fip.uboot32`, `fvp-aemv8a_revb.aarch32+regreset`, and `debug`, which will
be looked for in `run_config/`.

## Test

A test is a file with a name as per a configuration above in a test group
directory. Tests without a test group will be placed in the `GENERATED` group.

The file itself is usually empty, but it sometimes will define hooks (like run
fragments) to be executed for that test only.

# Running tests

Tests can be run both locally with a minimal environment and via the Jenkins CI
hosted on <https://ci.trustedfirmware.org/>. The procedure is similar but the
implementation differs vastly.

## Locally

Local CI runs happen via the `script/run_local_ci.sh` script.

Environment variables that are accepted (in rough order of relevance):
**Mandatory**:

  - `workspace` - directory to put *all* artefacts. Will be wiped before first
    use.
  - `test_groups` - a space separated list of tests and/or groups to run

**Optional** but recommended:

  - `tf_root, tftf_root, spm_root, rmm_root, tfm_tests_root, tfm_extras_root,
    rfa_root` - paths to local checkouts of these repositories. If unset, the
    script will make fresh clones for each for each test. Useful for running
    tests against local changes to any of these repositories. Note that if you
    use your local repositories for the tests, you should not keep working (i.e.
    modifying your files) while the tests are running. It is not necessary to
    commit the changes for them to take effect.

  - `parallel=1` - number of tests to run in parallel. When more than one tests
    are executed in parallel, the script will produce a terse output, displaying
    only the status of individual tests. Build/run output for individual test
    can be found under $workspace in respective directories for their test
    configuration.
    
    Note that when this is set to a number greater than 1, the following
    variables are forcefully set: `test_run=0`, `primary_live=0`.

  - `bin_mode=release` - whether to build binaries in `debug` or `release` mode.

**Truly Optional** :

  - `skip_runs=0` - only build, skip the run phase. Useful for using L2 jobs as
    L1

  - `dont_clean=0` - if the build script should skip cleaning the repositories.
    Convenient during debugging sessions where the user continuously re-builds
    after experimentation. Only makes sense with local checkouts of
    repositories.

  - `primary_live=0` - whether to print the output of primary UART is on to the
    console in addition to being captured into a log file.

  - `test_run=0` - run the test without automation. I.e., the model and its UART
    terminal windows are open. The user has to close the model windows to
    terminate the test. This is useful for local debugging. When set to 0, no
    model windows are open for view; instead, UART outputs are logged into the
    $workspace directory.

  - `connect_debugger=0` - override the test\_run variable with value 1, build
    TF-A with SPIN\_ON\_BL1\_EXIT enabled and it will pass the -S flag to FVP so
    it will be launched in server mode. This allows for debugging sessions using
    Arm DS.

  - `retain_paths=0` - whether to append (vs default prepend) paths to required
    tools to the `$PATH`. Currently a NOP.

  - `dont_print_memory=0` - build will not run poetry run memory . This saves on
    runtime if the output isn't needed.

  - `DOWNLOAD_SERVER_URL` - path to configuration artefacts. Some runs needs
    artefacts which are not stored in this repository. By default, files are
    downloaded from `https://downloads.trustedfirmware.org/` but a local copy
    can be used to speed this up. Note that this copy must be manually kept in
    sync and requires local disk space on the order of 60G.

  - `linaro_release` - similar to `DOWNLOAD_SERVER_URL` but for files which come
    from the CI's Docker image

### Local CI quickstart

Assuming you're developing TF-A, the shortest useful way to run CI is with the
following script:

``` bash
export tf_root=$TFA_ROOT
export tftf_root=$TFTF_ROOT
export spm_root=$HAFNIUM_ROOT
export rmm_root=$RMM_ROOT
export tfm_tests_root="no"
export tfm_extras_root="no"
export rfa_root="no"
export bin_mode="debug"
export workspace=/tmp/wherever/
export test_groups="tf-a-l1-docs"

bash $CI_ROOT/script/run_local_ci.sh
```

With an optional `parallel=$(nproc)` for multiple tests at once.

This requires local checkouts of the full A class firmware stack (TF-A, Hafnium,
RMM + tests) and ignores supplemental repositories that will not be built
normally. Local toolchains (gcc and clang) and models are also required as per
TF-A's setup guide.

### Matching test groups by glob

All tests belong to a group and match globs nicely. To expand those you can use
`uv run --project ${CI_ROOT}/tf-a-toolbox tf-a-toolbox matrix groups --include
"<test-glob>"` where `test-glob` is of the form `tf-a-l1-*`. Its output can be
fed unmodified to `test_groups`. Run `uv sync --project ./tf-a-toolbox --dev
--extra cli` before the first run to install dependencies

## Upstream in CI

The same CI scripts run in <https://ci.trustedfirmware.org/>. Relevant jobs are
`tf-a-gateway-pipeline`, and `tf-a-main-pipeline`. They do not use
`script/run_local_ci.sh` but rather invoke `script/build_package.sh` directly.
Variables can be set in the UI or automatically via the Allow CI +1/+2 label in
gerrit.
