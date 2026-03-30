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
<project>-<level>-<class>[-<driver>][-<theme>]
```

### Axes

| Axis | Meaning | Examples |
|----|----|----|
| `project` | Project under test, including the release line when a release branch is under test | `tf-a`, `tf-a-lts-v2.14`, `tftf`, `tftf-lts-v2.14`, `rf-a` |
| `level` | Approximate test duration or intensity | `l1`, `l2`, `l3` |
| `class` | Test kind | `build-tests`, `docs-tests`, `integration-tests` |
| `driver` | Optional harness axis that runs or evaluates the suite | `tftf`, `tfut` |
| `theme` | Optional invariant scenario identity for the group, such as platform, counterparty, objective, or a meaningful combination of those | `base-fvp`, `linux-lumex-1`, `platforms`, `spm-mm-base-fvp` |

### Level Meaning

- `l1`: fast-feedback tests, normally measured in seconds. Build tests, documentation tests, and unit tests belong here.
- `l2`: representative validation tests, normally measured in minutes. Functional tests and integration tests belong here by default.
- `l3`: exceptional campaign tests. Use this level for coverage, fuzzing, instrumentation, stress tests, and similar exploratory work.

### Class Meaning

- `build-tests`: build-generation tests
- `docs-tests`: documentation-generation tests
- `unit-tests`: tests driven by a unit-test harness such as TFUT
- `functional-tests`: tests that validate the externally visible behavior of the project under test, often through a functional test harness such as TFTF
- `integration-tests`: tests that validate the project's interaction with a counterparty runtime, operating system, platform stack, or other external component
- `analysis-tests`: static analysis and similar source-quality tests
- `coverage-tests`: coverage-instrumented tests
- `fuzz-tests`: fuzz tests involving a fuzz-testing harness
- `instrumentation-tests`: performance-instrumented tests

## Placement Rubric

Choose a group name in this order:

1.  Choose the project under test.

    Include the release line in the project when the configuration targets a release branch (like an LTS).

    The project axis names the component whose own outputs or behavior the configuration validates.

    TFTF-driven functional tests that exercise TF-A therefore use `tf-a` as the project and `tftf` as the driver. Configurations that build TFTF alone or generate TFTF documentation use `tftf` as the project.

2.  Choose the level from the test's role in the CI.

    Build tests, documentation tests, and unit tests use `l1`.

    Functional tests and integration tests use `l2` unless they are clearly an exceptional campaign.

    Use `l3` only for campaign-style suites such as coverage, fuzzing, instrumentation, long-running resilience exploration, or similar bug-hunting and measurement work.

3.  Choose the class from the existing test classes, or add a new one if the test kind is not already covered.

4.  Add a `driver` only if a harness runs or evaluates the suite and that harness is part of the suite identity.

5.  Add a `theme` to capture the group's invariant scenario identity, which may include a target platform, a counterparty component, a technical objective, or a meaningful combination of those elements.

## Group Design Rules

- All test configurations in a group must agree on the project, level, and class.
- If a group name includes a driver or a theme, every test configuration in the group must agree on that axis as well.
- The project axis follows the component being validated by the group, rather than every component named by its fragments.
- Platform identity belongs in the theme when the platform is part of the group's scenario identity.
- A group may vary build and run fragments only when doing so instantiates the same test suite across legitimate variants of the named theme or level.
- If two subsets differ by more than one meaningful axis, split them into different groups.

## Examples

- `tf-a-l1-build-tests-base-fvp`
- `tf-a-lts-v2.14-l1-build-tests-base-fvp`
- `tftf-l1-build-tests`
- `tftf-lts-v2.14-l1-build-tests`
- `tf-a-l1-docs-tests`
- `tftf-l1-docs-tests`
- `tf-a-l1-unit-tests-tfut`
- `tf-a-l2-functional-tests-tftf-base-fvp`
- `tf-a-l2-functional-tests-tftf-rmm-base-fvp`
- `tf-a-l2-functional-tests-tftf-spm-base-fvp`
- `tf-a-l2-integration-tests-platforms`
- `tf-a-l2-integration-tests-linux-lumex-1`
- `tf-a-l2-integration-tests-linux-n1sdp`
- `tf-a-l2-integration-tests-spm-base-fvp`
- `tf-a-l2-integration-tests-spm-mm-base-fvp`
- `tf-a-l2-functional-tests-tftf-lumex-1`
- `tf-a-l3-functional-tests-tftf-ras-base-fvp`
- `tf-a-l3-coverage-tests-tftf-base-fvp`
- `tf-a-l3-fuzz-tests-tftf-base-fvp`
- `rf-a-l2-integration-tests-base-fvp`
