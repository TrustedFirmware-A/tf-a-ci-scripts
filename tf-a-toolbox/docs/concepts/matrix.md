[](){ #tf-a-ci-test-matrix-page }

# TF-A CI Test Matrix

This page takes a deeper look at the TF-A CI test matrix, and the schema that backs it.

The TF-A Toolbox exposes interfaces for interacting directly with the matrix through the [`matrix`](../cli-reference.md#tf-a-toolbox-matrix) command in the CLI, and through the [`tf_a_toolbox.matrix`][] module in the API.

## Overview

The TF-A CI models its test matrix directly on the file system.

The matrix itself is the populated inventory of concrete test configurations present in the repository, whilst the schema is the set of rules that explains how to interpret that inventory: directory structure, test configuration naming, how build and run configuration fragments resolve and map to configuration files, etc.

## Schema

### Test Stores

At the root of a populated test matrix is a directory we call the *test store*.

There is one *canonical* test store: the `group/` directory, found at the top level of the repository.

``` text
group/
└── <test-group>/
    └── <test-config>
```

## Test Groups

Within a test store are one or more immediate subdirectories we call *test groups*. These do not themselves add coordinates to the test matrix; instead, they provide a unit of selection for CI jobs by partitioning the populated matrix taxonomically, by collecting related test configurations under shared identities.

## Test Configurations

Finally, within a test group are one or more immediate files we call *test configurations*. Each test configuration defines one concrete entry in the populated matrix.

Test configurations are Bash scripts. While they are *usually* empty, they may define implementations of script hooks to handle test-specific behaviors.

### Naming

A test configuration selects its matrix combination in its file name - the axes of the test matrix are defined by a fixed grammar that all test configuration file names adhere to, composed of:

1. An ordered, comma-separated tuple of "build fragments" naming one or more "build configurations".
2. An ordered, comma-separated tuple of "run fragments" naming zero or more "run configurations".
3. An optional `.inactive` suffix marking the test as disabled.

... the grammar for which is:

    test-config-name = build-fragment-tuple, ":", run-fragment-tuple, [ ".inactive" ] ;

To denote the absence of a fragment from a fragment tuple, a test configuration may use the special `nil` fragment. Omitting one or more *trailing* fragments will also imply they are each `nil`.

#### Build Fragment Tuple

The build fragment tuple selects what the CI builds. Each non-`nil` build fragment represents the name of a file to load from a directory corresponding to its position in the tuple:

| Index | Directory      | Meaning                     |
|-------|----------------|-----------------------------|
| 1     | `tf_config/`   | TF-A build configuration    |
| 2     | `tftf_config/` | TFTF build configuration    |
| 3     | `spm_config/`  | Hafnium build configuration |
| 4     | `rmm_config/`  | TF-RMM build configuration  |
| 5     | `rfa_config/`  | RF-A build configuration    |
| 6     | `tfut_config/` | TFUT build configuration    |

These directories are found at the top level of the repository, and contain Bash-compatible `KEY=VALUE` assignments that supply inputs to the build system of their associated project.

A single test configuration may select several build fragments at once, which allows one matrix entry to describe a coordinated integration test involving multiple projects.

#### Run Fragment Tuple

The run fragment tuple selects how the built artifacts are packaged, executed, and evaluated. Unlike the build fragment tuple, each non-`nil` run fragment represents a *aggregation* of run configurations to load from its corresponding directory:

| Index | Directory          | Meaning                          |
|-------|--------------------|----------------------------------|
| 1     | `run_config/`      | Primary system run configuration |
| 2     | `run_config_tfut/` | TFUT unit-test run configuration |

Like the test configuration, these resolved fragment files are Bash scripts which can influence packaging, test setup, artifact handling, test expectations, and other runtime behavior.

#### Run Fragment Resolution

Resolution of a run fragment tuple to its constituent configurations is a hierarchical, iterative process.

For each non-`nil` run fragment, the resolver splits the fragment on `-`, then processes the resulting components from left to right. At each step, it looks for the most specific matching file that can be formed from the fragments seen so far, falling back to a less specific candidate when needed.

For example, a run fragment of `fvp-tftf.rme` is resolved in two stages:

1.  The first stage looks for `run_config/fvp`.
2.  The second stage looks for `run_config/fvp-tftf.rme`, and falls back to `run_config/tftf.rme` if the more specific file does not exist.

The CI then sources the chosen fragment files in order.
