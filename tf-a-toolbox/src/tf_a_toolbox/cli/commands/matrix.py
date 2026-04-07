"""`matrix` command implementation."""

import dataclasses
import fnmatch

from enum import IntEnum, StrEnum
from pathlib import Path  # noqa: TC003 - used by Typer annotations
from typing import Annotated

import typer

from rich.text import Text

from tf_a_toolbox.cli.consoles import stderr, stdout
from tf_a_toolbox.cli.diagnostics import Diagnostic, ExitCode, FatalError, Severity
from tf_a_toolbox.matrix import (
    ConfigPathError,
    ConfigState,
    GroupPathError,
    Store,
    StorePathError,
    StoreQuery,
)

app = typer.Typer(no_args_is_help=True)
"""Root application for the `matrix` command."""


class MatrixExitCode(IntEnum):
    """Exit codes shared by the `matrix` command and its subcommands."""

    STORE_NOT_FOUND = 3
    """The requested test store path does not exist."""

    STORE_NOT_A_DIRECTORY = 4
    """The requested test store path exists but is not a directory."""

    STORE_PERMISSION_DENIED = 5
    """The command could not inspect the requested test store path."""

    @staticmethod
    def from_matrix_error(
        error: StorePathError | GroupPathError | ConfigPathError,
    ) -> int:
        """Return the exit code for a matrix traversal error."""
        match (error, error.__cause__):
            case (StorePathError(), FileNotFoundError()):
                return MatrixExitCode.STORE_NOT_FOUND

            case (StorePathError(), NotADirectoryError()):
                return MatrixExitCode.STORE_NOT_A_DIRECTORY

            case (StorePathError(), PermissionError()):
                return MatrixExitCode.STORE_PERMISSION_DENIED

            case _:
                return ExitCode.FAILURE


assert set(map(int, ExitCode)).isdisjoint(map(int, MatrixExitCode)), (  # noqa: S101 - import-time invariant
    "`_MatrixExitCode` overlaps with `ExitCode`"
)


class StateFilter(StrEnum):
    """Enablement state filters."""

    ANY = "any"
    """Include active and inactive items."""

    ACTIVE = "active"
    """Include active items only."""

    INACTIVE = "inactive"
    """Include inactive items only."""

    def accepts(self, state: ConfigState) -> bool:
        """Return whether this filter includes the given state."""
        match self:
            case StateFilter.ANY:
                return True

            case StateFilter.ACTIVE:
                return state is ConfigState.ACTIVE

            case StateFilter.INACTIVE:
                return state is ConfigState.INACTIVE


class Layout(StrEnum):
    """Output layout options for test configuration queries."""

    FLAT = "flat"
    """Render test configurations as a flat list."""

    GROUPED = "grouped"
    """Render test configurations grouped beneath their test group."""


@dataclasses.dataclass(frozen=True, slots=True)
class GlobFilter:
    """Glob inclusion and exclusion filter."""

    includes: tuple[str, ...]
    """Case-sensitive glob patterns to filter."""

    excludes: tuple[str, ...]
    """Case-sensitive glob patterns to filter out."""

    def accepts(self, value: str) -> bool:
        """Return whether this filter includes the given value."""
        included = any(fnmatch.fnmatchcase(value, pattern) for pattern in self.includes)
        excluded = any(fnmatch.fnmatchcase(value, pattern) for pattern in self.excludes)

        return included and not excluded


class MatrixStyle(StrEnum):
    """Named Rich styles used by the `matrix` command."""

    GROUP_ACTIVE = "bold green"
    """Style for active test group names."""

    GROUP_INACTIVE = "bold red"
    """Style for inactive test group names."""

    CONFIG_GROUP = "bold white"
    """Style for the test group name in test configuration output."""

    CONFIG_ACTIVE = "bright_green"
    """Style for active test configuration names."""

    CONFIG_INACTIVE = "bright_red"
    """Style for inactive test configuration names."""


@app.callback()
def root() -> None:
    """Query the test matrix."""


@app.command()
def groups(
    path: Annotated[
        Path | None,
        typer.Argument(
            help="Path to the test store.",
            metavar="PATH",
            readable=False,
        ),
    ] = None,
    *,
    includes: Annotated[
        list[str] | None,
        typer.Option(
            "--include",
            metavar="PATTERN",
            help="Include group names that match this case-sensitive glob.",
        ),
    ] = None,
    excludes: Annotated[
        list[str] | None,
        typer.Option(
            "--exclude",
            metavar="PATTERN",
            help="Skip group names that match this case-sensitive glob.",
        ),
    ] = None,
    state: Annotated[
        StateFilter,
        typer.Option(
            help="Choose which derived group states to include.",
        ),
    ] = StateFilter.ACTIVE,
) -> None:
    """Query and filter test groups."""
    store = Store(path) if path is not None else Store()
    globs = GlobFilter(tuple(includes or ("*",)), tuple(excludes or ()))

    query = StoreQuery(lambda group: globs.accepts(group.path.name))

    try:
        matrix = query.execute(store)
    except StorePathError as error:
        diagnostic = Diagnostic.from_matrix_error(error, Severity.ERROR)
        exit_code = MatrixExitCode.from_matrix_error(error)

        raise FatalError(diagnostic, exit_code) from error

    for error in matrix.errors:
        diagnostic = Diagnostic.from_matrix_error(error, Severity.WARNING)
        diagnostic.report(stderr)

    for group in matrix.groups:
        for error in group.errors:
            diagnostic = Diagnostic.from_matrix_error(error, Severity.WARNING)
            diagnostic.report(stderr)

    for group in matrix.groups:
        active = any(config.state is ConfigState.ACTIVE for config in group.configs)
        if not state.accepts(ConfigState.ACTIVE if active else ConfigState.INACTIVE):
            continue

        style = MatrixStyle.GROUP_ACTIVE if active else MatrixStyle.GROUP_INACTIVE
        text = Text(group.group.path.name, style)

        stdout.print(text, soft_wrap=True)


@app.command()
def configs(
    path: Annotated[
        Path | None,
        typer.Argument(
            help="Path to the test store.",
            metavar="PATH",
            readable=False,
        ),
    ] = None,
    *,
    includes: Annotated[
        list[str] | None,
        typer.Option(
            "--include",
            metavar="PATTERN",
            help="Include group names that match this case-sensitive glob.",
        ),
    ] = None,
    excludes: Annotated[
        list[str] | None,
        typer.Option(
            "--exclude",
            metavar="PATTERN",
            help="Skip group names that match this case-sensitive glob.",
        ),
    ] = None,
    state: Annotated[
        StateFilter,
        typer.Option(
            help="Choose which configuration states to include.",
        ),
    ] = StateFilter.ACTIVE,
    layout: Annotated[
        Layout,
        typer.Option(
            help="Choose how to lay out matching configurations.",
        ),
    ] = Layout.FLAT,
) -> None:
    """Query and filter test configurations."""
    store = Store(path) if path is not None else Store()
    globs = GlobFilter(tuple(includes or ("*",)), tuple(excludes or ()))

    query = StoreQuery(lambda group: globs.accepts(group.path.name))

    try:
        matrix = query.execute(store)
    except StorePathError as error:
        diagnostic = Diagnostic.from_matrix_error(error, Severity.ERROR)
        exit_code = MatrixExitCode.from_matrix_error(error)

        raise FatalError(diagnostic, exit_code) from error

    for error in matrix.errors:
        diagnostic = Diagnostic.from_matrix_error(error, Severity.WARNING)
        diagnostic.report(stderr)

    for group in matrix.groups:
        for error in group.errors:
            diagnostic = Diagnostic.from_matrix_error(error, Severity.WARNING)
            diagnostic.report(stderr)

    for group in matrix.groups:
        configs = [config for config in group.configs if state.accepts(config.state)]
        if not configs:
            continue

        if layout is Layout.GROUPED:
            active = any(config.state is ConfigState.ACTIVE for config in group.configs)
            style = MatrixStyle.GROUP_ACTIVE if active else MatrixStyle.GROUP_INACTIVE
            text = Text(group.group.path.name, style)

            stdout.print(text, soft_wrap=True)

        for config in configs:
            active = config.state is ConfigState.ACTIVE
            style = MatrixStyle.CONFIG_ACTIVE if active else MatrixStyle.CONFIG_INACTIVE

            text = Text()
            text.append(f"{group.group.path.name}/", style=MatrixStyle.CONFIG_GROUP)
            text.append(config.path.name, style)

            stdout.print(text, soft_wrap=True)
