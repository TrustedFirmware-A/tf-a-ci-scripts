"""Styles used across the application."""

from enum import StrEnum


class Style(StrEnum):
    """Named [`rich`][] styles used across the application."""

    ERROR = "bold red"
    """Style for error text."""

    WARNING = "bold yellow"
    """Style for warning text."""

    PATH = "yellow"
    """Style for filesystem paths."""
