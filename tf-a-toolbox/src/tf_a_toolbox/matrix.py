"""Interfaces for managing the TF-A CI scripts test matrix.

This module models the TF-A CI test matrix through three core types:

- [`Store`][] represents the *test store* (the top-level `group/` directory).
- [`Group`][] represents a *test group* (a subdirectory of the test store).
- [`Config`][] represents a *test configuration* (a file within a test group).

These types represent high-level [`Path`][]-like wrappers around the matrix's
file system model, and support both lazy traversal and eager snapshotting.

Arbitrary queries can be executed on a test store or test group by using the
query API, which returns partial "views" of the matrix:

- [`StoreQuery`][] queries the test groups and configurations in a test store.
- [`GroupQuery`][] queries the test configurations in a test group.

See Also:
    See [TF-A CI Test Matrix][tf-a-ci-test-matrix-page] for additional
        documentation on the on-disk representation of the test matrix.

Examples:
    >>> store = Store()  # canonical repository store
    >>> store.path.as_posix()  # doctest: +ELLIPSIS
    '.../group'
    >>>
    >>> group = store.group("tf-a-l1-build-arm-fvp")
    >>> group.path.as_posix()  # doctest: +ELLIPSIS
    '.../group/tf-a-l1-build-arm-fvp'
    >>>
    >>> config = group.config("fvp-default:nil")
    >>> config.path.as_posix()  # doctest: +ELLIPSIS
    '.../group/tf-a-l1-build-arm-fvp/fvp-default:nil'
"""

import os
import stat

from dataclasses import dataclass, field
from enum import Enum, unique
from typing import TYPE_CHECKING

from tf_a_toolbox import paths

if TYPE_CHECKING:
    from collections.abc import Callable, Iterator
    from pathlib import Path


class StorePathError(Exception):
    """A traversal failure involving a test store path."""

    path: Path
    """Test store path responsible for the failure."""

    def __init__(self, path: Path) -> None:
        """Build a [`StorePathError`][] from its associated path."""
        super().__init__(path)

        self.path = path


class GroupPathError(Exception):
    """A traversal failure involving a test group path."""

    path: Path
    """Test group path responsible for the failure."""

    def __init__(self, path: Path) -> None:
        """Build a [`GroupPathError`][] from its associated path."""
        super().__init__(path)

        self.path = path


class ConfigPathError(Exception):
    """A traversal failure involving a test configuration path."""

    path: Path
    """Test configuration path responsible for the failure."""

    def __init__(self, path: Path) -> None:
        """Build a [`ConfigPathError`][] from its associated path."""
        super().__init__(path)

        self.path = path


@dataclass(frozen=True, slots=True)
class Store:
    """A test store."""

    path: Path = field(default_factory=lambda: paths.root() / "group")
    """File system path to the store directory."""

    def groups(self) -> Iterator[Group | GroupPathError]:
        """Yield the groups in this store.

        This iterator inspects the immediate children of this store directory,
        yielding a [`Group`][] for each test group identified.

        If inspecting a child triggers an exception, a [`GroupPathError`][]
        is yielded with the cause chain recorded at that point.

        Results are yielded in an unspecified order.

        Raises:
            StorePathError: If the test store path could not be traversed. The
                cause chain records the underlying reason.

        Examples:
            >>> store = Store()  # canonical repository store
            >>>
            >>> sorted(group.path.name for group in store.groups())  # doctest: +ELLIPSIS
            ['rf-a-l1-build-arm-fvp', 'rf-a-l1-build-qemu', ...]
        """
        try:
            with os.scandir(self.path) as scan:
                for entry in scan:
                    # The `GENERATED` group is not part of the matrix.
                    if entry.name == "GENERATED":
                        continue

                    path = self.path / entry.name

                    try:
                        if stat.S_ISDIR(entry.stat().st_mode):
                            yield Group(path=path)
                    except OSError as error:
                        try:
                            raise GroupPathError(path=path) from error  # noqa: TRY301 - captured immediately to preserve cause
                        except GroupPathError as path_error:
                            yield path_error
        except OSError as error:
            raise StorePathError(path=self.path) from error

    def group(self, name: str) -> Group:
        """Return the test group represented by the given directory name.

        Examples:
            >>> store = Store()  # canonical repository store
            >>>
            >>> group = store.group("tf-a-l1-build-arm-fvp")
            >>> group.path.name
            'tf-a-l1-build-arm-fvp'
        """
        return Group(path=self.path / name)

    def snapshot(self) -> StoreView:
        """Return a complete view of this store's groups.

        !!! warning

            This operation is not atomic - if the store is modified while the
            operation is running, the snapshot may be incomplete or stale.

        Raises:
            StorePathError: If the test store path could not be traversed. The
                cause chain records the underlying reason.
        """
        return StoreQuery(groups=GroupQuery()).execute(self)


@dataclass(frozen=True, slots=True)
class StoreView:
    """A frozen, in-memory view of a test store."""

    store: Store
    """Test store represented by this view."""

    groups: tuple[GroupView, ...]
    """Groups materialized into this view."""

    errors: tuple[GroupPathError, ...] = ()
    """Group traversal errors captured while materializing."""


@dataclass(frozen=True, slots=True)
class Group:
    """A test group within a test store."""

    path: Path
    """File system path to the group directory."""

    def configs(self) -> Iterator[Config | ConfigPathError]:
        """Yield the configurations in this group.

        This iterator inspects the immediate children of this group directory,
        yielding a [`Config`][] for each test configuration identified.

        If inspecting a child triggers an exception, a [`ConfigPathError`][]
        is yielded with the cause chain recorded at that point.

        Results are yielded in an unspecified order.

        Raises:
            GroupPathError: If the test group path could not be traversed. The
                cause chain records the underlying reason.

        Examples:
            >>> store = Store()  # canonical repository store
            >>> group = store.group("tf-a-l1-build-arm-fvp")
            >>>
            >>> sorted(config.path.name for config in group.configs())  # doctest: +ELLIPSIS
            ['fvp-aarch32-bl2-el3:nil', 'fvp-aarch32-console-getc:nil', ...]
        """
        try:
            with os.scandir(self.path) as scan:
                for entry in scan:
                    path = self.path / entry.name

                    try:
                        if stat.S_ISREG(entry.stat().st_mode):
                            yield Config(path=path)
                    except OSError as error:
                        try:
                            raise ConfigPathError(path=path) from error  # noqa: TRY301 - captured immediately to preserve cause
                        except ConfigPathError as path_error:
                            yield path_error
        except OSError as error:
            raise GroupPathError(path=self.path) from error

    def config(self, name: str) -> Config:
        """Return the test configuration represented by the given file name.

        Examples:
            >>> store = Store()  # canonical repository store
            >>> group = store.group("tf-a-l1-build-arm-fvp")
            >>>
            >>> config = group.config("fvp-default:nil")
            >>> config.path.name
            'fvp-default:nil'
        """
        return Config(path=self.path / name)

    def snapshot(self) -> GroupView:
        """Return a complete view of this group's configurations.

        !!! warning

            This operation is not atomic - if the store is modified while the
            operation is running, the snapshot may be incomplete or stale.

        Raises:
            GroupPathError: If the test group path could not be traversed. The
                cause chain records the underlying reason.
        """
        return GroupQuery().execute(self)


@dataclass(frozen=True, slots=True)
class GroupView:
    """A frozen, in-memory view of a test group."""

    group: Group
    """Test group represented by this view."""

    configs: tuple[Config, ...]
    """Configurations materialized into this view."""

    errors: tuple[ConfigPathError, ...] = ()
    """Configuration traversal errors captured while materializing."""


@unique
class ConfigState(Enum):
    """Enablement state of a test configuration."""

    ACTIVE = "active"
    """Active (enabled) state."""

    INACTIVE = "inactive"
    """Inactive (disabled) state."""

    def __str__(self) -> str:
        """Return the string value of this configuration state.

        Examples:
            >>> str(ConfigState.INACTIVE)
            'inactive'

            >>> str(ConfigState.ACTIVE)
            'active'
        """
        return self.value


@dataclass(frozen=True, slots=True)
class Config:
    """A test configuration within a test group."""

    path: Path
    """File system path to the configuration file."""

    @property
    def state(self) -> ConfigState:
        """Enablement state of this configuration.

        A configuration whose file name ends with `.inactive` is considered to
        be inactive; inactive configurations are skipped during the test
        descriptor generation process.

        Examples:
            >>> store = Store()  # canonical repository store
            >>> group = store.group("tf-a-l1-build-arm-fvp")
            >>>
            >>> config = group.config("fvp-default:nil")
            >>> (config.path.name, str(config.state))
            ('fvp-default:nil', 'active')
            >>>
            >>> config = group.config("fvp-default:nil.inactive")
            >>> (config.path.name, str(config.state))
            ('fvp-default:nil.inactive', 'inactive')
        """
        return ConfigState.INACTIVE if self.path.name.endswith(".inactive") else ConfigState.ACTIVE


@dataclass(frozen=True, slots=True)
class GroupQuery:
    """A query applicable to a test group."""

    predicate: Callable[[Config], bool] | None = field(default=None, repr=False, compare=False)
    """Optional predicate deciding whether to keep each configuration."""

    def execute(self, group: Group) -> GroupView:
        """Execute the query on the specified test group.

        Raises:
            GroupPathError: If the test group path could not be traversed. The
                cause chain records the underlying reason.
        """
        configs: list[Config] = []
        errors: list[ConfigPathError] = []

        for item in group.configs():
            if isinstance(item, ConfigPathError):
                errors.append(item)
                continue

            if (self.predicate is None) or self.predicate(item):
                configs.append(item)

        return GroupView(
            group=group,
            configs=tuple(sorted(configs, key=lambda config: (config.path.name, config.path))),
            errors=tuple(sorted(errors, key=lambda error: error.path)),
        )


@dataclass(frozen=True, slots=True)
class StoreQuery:
    """A query applicable to a test store."""

    predicate: Callable[[Group], bool] | None = field(default=None, repr=False, compare=False)
    """Optional predicate deciding whether to keep each group."""

    groups: GroupQuery = field(default_factory=GroupQuery, repr=False, compare=False)
    """Query to apply to each test group in the store."""

    def execute(self, store: Store) -> StoreView:
        """Execute the query on the specified test store.

        Raises:
            StorePathError: If the test store path could not be traversed. The
                cause chain records the underlying reason.
        """
        groups: list[GroupView] = []
        errors: list[GroupPathError] = []

        for item in store.groups():
            if isinstance(item, GroupPathError):
                errors.append(item)
                continue

            if (self.predicate is not None) and not self.predicate(item):
                continue

            try:
                groups.append(self.groups.execute(item))
            except GroupPathError as error:
                errors.append(error)

        return StoreView(
            store=store,
            groups=tuple(sorted(groups, key=lambda view: (view.group.path.name, view.group.path))),
            errors=tuple(sorted(errors, key=lambda error: error.path)),
        )
