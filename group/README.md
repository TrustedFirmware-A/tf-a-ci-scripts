# Test Groups

This directory contains test groups and test configurations.

## Terminology

- A subdirectory under `group/` is a **test group**.
- A file inside a test group is a **test configuration**.
- In a test configuration name, the text before `:` is the **build fragment tuple**.
- In a test configuration name, the text after `:` is the **run fragment tuple**.
- Build fragments refer to files under `tf_config/`, `tftf_config/`, `spm_config/`, `rmm_config/`, `rfa_config/`, and `tfut_config/`.
- Run fragments refer to files under `run_config/` and, for TFUT, `run_config_tfut/`.

## Layout

The directory layout is:

``` text
group/
  <test-group>/
    <build-fragment-tuple>:<run-fragment-tuple>
```

Each test configuration file is a shell script and may contain additional test-specific options.

## Test Configuration Format

The canonical build fragment order is:

``` text
tf_config,tftf_config,spm_config,rmm_config,rfa_config,tfut_config
```

Missing build fragments are padded on the right with `nil`.

Run fragments are resolved by `script/gen_run_config_candidates.py`. A run fragment tuple therefore names a composed run configuration, not necessarily a single file under `run_config/`.

Test configuration files use Java property syntax:

``` text
VAR=value
```

Write the right-hand side without quotes.

If a test configuration has a `.inactive` suffix, it is skipped entirely. Use this to disable the configuration temporarily.

## Taxonomy

### Group Name Grammar

``` text
<project>[-<release-line>]-<level>-<class>[-<driver>][-<campaign>][-<target>]
```

### Axes

| Axis | Meaning | Examples |
|----|----|----|
| `project` | Project under test | `tf-a`, `tftf`, `rf-a` |
| `release-line` | Optional release line qualifier | `lts-v2.14`, `lts-v2.8` |
| `level` | Approximate test duration or intensity | `l1`, `l2`, `l3` |
| `class` | Broad class of validation | `build`, `docs`, `unit`, `functional`, `integration`, `analysis`, `coverage`, `fuzz`, `instrumentation` |
| `driver` | Optional harness axis that runs or evaluates the suite | `tftf`, `tfut`, `linux`, `depthcharge` |
| `campaign` | Optional invariant scenario identity for the group | `reboot`, `psci-system-reset2`, `scan-build`, `tbb`, `undef-injection` |
| `target` | Optional target platform | `arm-fvp`, `arm-fvp-ve`, `mediatek-mt8195`, `qemu` |

### Level Meaning

- `l1`: fast-feedback tests, normally measured in seconds. Build tests, documentation tests, and unit tests belong here.
- `l2`: representative validation tests, normally measured in minutes. Functional tests and integration tests belong here by default.
- `l3`: exceptional campaign tests. Use this level for coverage, fuzzing, instrumentation, stress tests, and similar exploratory work.

### Class Meaning

- `build`: build-generation tests
- `docs`: documentation-generation tests
- `unit`: tests driven by a unit-test harness such as TFUT
- `functional`: tests that validate the externally visible behavior of the project under test, often through TFTF
- `integration`: tests that validate the project's interaction with another runtime, operating system, platform stack, or other external component
- `analysis`: static analysis and similar source-quality tests
- `coverage`: coverage-instrumented tests
- `fuzz`: fuzz tests involving a fuzz-testing harness
- `instrumentation`: performance-instrumented tests

## Placement Rubric

Choose a group name in this order:

1.  Choose the project under test.

    The project axis names the component whose own outputs or behavior the configuration validates.

    TFTF-driven functional tests that exercise TF-A therefore use `tf-a` as the project and `tftf` as the driver. Configurations that build TFTF alone or generate TFTF documentation use `tftf` as the project.

2.  Choose the project release line (e.g. an LTS version) under test, if relevant.

3.  Choose the level from the test's role in the CI.

    Build tests, documentation tests, and unit tests use `l1`.

    Functional tests and integration tests use `l2` unless they are clearly an exceptional campaign.

    Use `l3` only for campaign-style suites such as coverage, fuzzing, instrumentation, long-running resilience exploration, or similar bug-hunting and measurement work.

4.  Choose the class from the existing test classes, or add a new one if the test kind is not already covered.

5.  Decide whether the suite identity includes a driver.

    Add a `driver` only if a harness or runtime component runs or evaluates the suite and that harness or runtime is part of the suite identity.

6.  Choose the campaign, if the group shares a stable scenario name beyond the driver and target.

    Add a `campaign` only if the group has an invariant scenario identity beyond the driver and target.

7.  If the group targets a platform, specify an appropriate target name, ideally composed of the platform vendor and name, and optionally variant.

## Group Design Rules

- All test configurations in a group must agree on the project, level, and class.
- If a group name includes a driver, campaign, or target, every test configuration in the group must agree on that axis as well.
- A platform-targeted group must contain configurations for exactly one platform.
- The project axis follows the component being validated by the group, rather than every component named by its fragments.
- A group may vary build and run fragments only when doing so instantiates the same test suite across legitimate variants of the named driver, campaign, target, or level.
- If two subsets differ by more than one meaningful axis, split them into different groups.

## Examples

- `tf-a-l1-build-arm-fvp`
- `tf-a-l1-build-arm-fvp-ve`
- `tf-a-l1-build-tbb-arm-juno`
- `tf-a-lts-v2.14-l1-build-arm-fvp`
- `tftf-l1-build-nvidia-tegra-194`
- `tftf-lts-v2.14-l1-build-arm-fvp`
- `tf-a-l1-docs`
- `tftf-l1-docs`
- `tf-a-l1-unit-tfut`
- `tf-a-l2-functional-tftf-arm-fvp`
- `tf-a-l2-functional-tftf-rmm-arm-fvp`
- `tf-a-l2-functional-tftf-spm-arm-fvp`
- `tf-a-l2-integration-linux-arm-fvp`
- `tf-a-l2-integration-linux-arm-tc`
- `tf-a-l2-integration-linux-arm-n1sdp`
- `tf-a-l2-integration-spm-arm-fvp`
- `tf-a-l2-integration-spm-mm-arm-fvp`
- `tf-a-l2-functional-tftf-arm-tc`
- `tf-a-l3-functional-tftf-ras-arm-fvp`
- `tf-a-l3-coverage-tftf-arm-fvp`
- `tf-a-l3-fuzz-tftf-arm-fvp`
- `rf-a-l2-integration-arm-fvp`
