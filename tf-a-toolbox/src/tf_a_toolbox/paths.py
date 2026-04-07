"""Helpers for navigating the parent repository."""

from pathlib import Path


def root() -> Path:
    """Return the path to the TF-A CI scripts root directory.

    Examples:
        >>> from tf_a_toolbox import paths
        >>>
        >>> base_aemva_sh = paths.root() / "model" / "base-aemva.sh"
        >>> base_aemva_sh.is_file()
        True
    """
    package = Path(__file__).parents[2]
    return package.parent.resolve()
