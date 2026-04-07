"""User-facing diagnostic reporting.

The central type of this module is the [`Diagnostic`][]. Diagnostics represent
structured, user-facing messages that the application emits to describe issues
like errors, warnings, notes, help messages, etc.

A [`Diagnostic`][] can be promoted to a [`FatalError`][] and raised, which
reports the diagnostic and terminates the program with a stable exit code when
the exception is caught by the top-level error handler.
"""

import dataclasses

from enum import IntEnum, StrEnum
from typing import TYPE_CHECKING

from rich.text import Text

from tf_a_toolbox.cli.consoles import stderr
from tf_a_toolbox.cli.styles import Style
from tf_a_toolbox.matrix import ConfigPathError, GroupPathError, StorePathError

if TYPE_CHECKING:
    from pathlib import Path

    from rich.console import Console


class ExitCode(IntEnum):
    """Exit codes shared across commands.

    These codes cover only generic success and failure; command-specific exit
    codes live alongside their command implementations, and must be disjoint
    from this enum.
    """

    SUCCESS = 0
    """Successful command completion."""

    FAILURE = 1
    """Generic command failure."""

    USAGE = 2
    """Command-line usage error."""


class Severity(StrEnum):
    """Diagnostic severity levels."""

    ERROR = "error"
    """Error-level diagnostic."""

    WARNING = "warning"
    """Warning-level diagnostic."""

    @property
    def style(self) -> Style:
        """Rich style name associated with this severity."""
        match self:
            case Severity.ERROR:
                return Style.ERROR

            case Severity.WARNING:
                return Style.WARNING


@dataclasses.dataclass(frozen=True, slots=True)
class Diagnostic:
    """A printable problem diagnostic.

    Diagnostics are user-facing reports created from lower-level error types,
    and include additional details more practically useful to the user.

    A diagnostic may combine information from one or more errors to present the
    user with a more contextualized problem diagnosis.
    """

    summary: Text
    """One-line summary shown to the user."""

    _: dataclasses.KW_ONLY

    severity: Severity = Severity.ERROR
    """Severity of the problem."""

    detail: str | None = None
    """Optional detail appended after the summary."""

    def report(self, console: Console = stderr) -> None:
        """Report this diagnostic on the provided console."""
        console.print(self.text, soft_wrap=True)

    @staticmethod
    def from_path_error(
        path: Path,
        subject: str,
        cause: BaseException | None = None,
        severity: Severity = Severity.ERROR,
    ) -> Diagnostic:
        """Build a diagnostic from a path-related error.

        This method maps a common set of path-related failures to a diagnostic
        tailored to the particular failure.

        Args:
            path: The path which triggered the error.
            subject: The subject (the "thing") that the path represents.
            cause: The underlying cause of the diagnostic.
            severity: The severity of the diagnostic.

        Returns:
            A diagnostic describing the path failure.
        """
        match cause:
            case FileNotFoundError():
                summary = Text(f"{subject} does not exist: ")
                detail = None

            case NotADirectoryError():
                summary = Text(f"{subject} is not a directory: ")
                detail = None

            case PermissionError():
                summary = Text(f"permission denied when reading {subject}: ")
                detail = None

            case OSError():
                summary = Text(f"could not access {subject}: ")
                detail = cause.strerror or str(cause)

            case _:
                summary = Text(f"could not access {subject}: ")
                detail = str(cause)

        summary.append(str(path), style=Style.PATH)

        return Diagnostic(summary, severity=severity, detail=detail)

    @staticmethod
    def from_matrix_error(
        error: StorePathError | GroupPathError | ConfigPathError,
        severity: Severity = Severity.ERROR,
    ) -> Diagnostic:
        """Build a diagnostic from a matrix-related error.

        This method maps a common set of matrix-related failures to a
        diagnostic tailored to the particular failure.

        Args:
            error: Matrix error to describe.
            severity: The severity of the diagnostic.

        Returns:
            A diagnostic describing the matrix failure.
        """
        match error:
            case StorePathError():
                subject = "test store path"

            case GroupPathError():
                subject = "test group path"

            case ConfigPathError():
                subject = "test configuration path"

        return Diagnostic.from_path_error(error.path, subject, error.__cause__, severity)

    @property
    def text(self) -> Text:
        """Renderable form of this diagnostic."""
        message = Text()
        message.append(f"{self.severity.value}: ", style=self.severity.style)
        message.append_text(self.summary)

        if self.detail:
            message.append(f" ({self.detail})")

        return message


class FatalError(Exception):
    """A fatal application error.

    A [`FatalError`][] binds a user-facing diagnostic with a stable exit code,
    and represents a failure that the application cannot reasonably handle or
    recover from.

    Exceptions of this kind are designed to be bubbled up to the application
    entrypoint, where the diagnostic is rendered to the standard error stream
    and the application exits with the associated exit code.
    """

    diagnostic: Diagnostic
    """Diagnostic to report before exiting."""

    exit_code: int
    """Exit code to return from the application."""

    def __init__(self, diagnostic: Diagnostic, exit_code: int = ExitCode.FAILURE) -> None:
        """Build a fatal error from its diagnostic and exit code."""
        super().__init__(diagnostic.text.plain)

        self.diagnostic = diagnostic
        self.exit_code = exit_code
