# TF-A Toolbox

The TF-A Toolbox is a general-purpose CLI and Python API aimed at streamlining the TF-A developer experience.

## Requirements

- [uv](https://docs.astral.sh/uv/) (\>= `0.10.0`)

## Quick Start

Use `uv` to install the CLI:

``` console
$ uv tool install --python "3.14" --editable ".[cli]"
$ tf-a-toolbox --help
```

Do *not* omit the `--editable` option - the CLI is deliberately coupled to the surrounding repository.

### Development

If you plan to work on the TF-A Toolbox, you can set up the developer virtual environment directly with:

``` console
$ uv sync --dev --extra cli
$ uv run tf-a-toolbox --help
```

#### Documentation

To build and serve the project's [MkDocs](https://www.mkdocs.org/) documentation locally, run:

``` console
$ uv run --extra cli mkdocs serve # or just `build`
```

#### Validation

The TF-A Toolbox enforces strict quality assurance gates with the help of:

- [Ruff](https://docs.astral.sh/ruff/) for linting and formatting,
- [ty](https://docs.astral.sh/ty/) and [Pyright](https://microsoft.github.io/pyright/#/) for type-checking, and
- [pytest](https://docs.pytest.org/en/stable/) for unit testing.

You can run the full QA suite with:

``` console
$ ruff format # format
$ ruff check # lint
$ ty check && pyright # type-check
$ pytest # test
```

### Python API

To add `tf_a_toolbox` as an editable path dependency to another `uv` project, run:

``` console
$ uv add --editable "/path/to/tf-a-toolbox"
```
