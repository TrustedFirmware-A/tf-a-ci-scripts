"""The TF-A Toolbox CLI (`tf-a-toolbox`)."""

from typing import TYPE_CHECKING

from typer import Typer
from typer.core import TyperGroup

from tf_a_toolbox.cli.commands import matrix
from tf_a_toolbox.cli.consoles import stderr
from tf_a_toolbox.cli.diagnostics import FatalError

if TYPE_CHECKING:
    from click import Context


class AppGroup(TyperGroup):
    """Root command group.

    This group centralizes handling of [`FatalError`][]-based exceptions. If a
    fatal error is caught, its diagnostic is reported on [`stderr`][] and the
    application exits with its associated exit code.
    """

    def invoke(self, ctx: Context) -> object:
        """Invoke this group and render fatal errors when raised."""
        try:
            return super().invoke(ctx)
        except FatalError as error:
            error.diagnostic.report(stderr)
            ctx.exit(error.exit_code)


app = Typer(no_args_is_help=True, cls=AppGroup)
"""Main Typer entrypoint for the application."""

app.add_typer(matrix.app, name="matrix")


@app.callback()
def root() -> None:
    """Miscellaneous utilities for Trusted Firmware-A developers."""
