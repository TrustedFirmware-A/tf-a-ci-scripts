"""Consoles for colorized and rich text output."""

from rich.console import Console

stdout = Console()
"""Console used for ordinary command output."""

stderr = Console(stderr=True)
"""Console used for warnings, errors, and other diagnostic output."""
