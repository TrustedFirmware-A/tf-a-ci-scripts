"""`mkdocs-click` compatibility bridge."""

from typer import main

from tf_a_toolbox.cli import app

CLICK_APP = main.get_command(app)
"""Click-compatible view of the entrypoint for `mkdocs-click`."""
