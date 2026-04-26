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

from abc import ABC
from dataclasses import astuple, dataclass, field, fields
from enum import Enum, unique
from typing import TYPE_CHECKING, Self

from tf_a_toolbox import paths

if TYPE_CHECKING:
    from collections.abc import Callable, Iterator
    from pathlib import Path


class MatrixError(Exception, ABC):
    """Base class for test matrix errors."""


class MatrixPathError(MatrixError, ABC):
    """Base class for file system-related matrix errors."""

    path: Path
    """Path responsible for the failure."""

    def __init__(self, path: Path, message: str) -> None:
        """Build an error from its associated path."""
        super().__init__(message)

        self.path = path


class StorePathError(MatrixPathError):
    """An error involving a test store path."""

    def __init__(self, path: Path) -> None:
        """Build an error from its associated test store path."""
        super().__init__(path, f"failed to access test store path: {path}")


class GroupPathError(MatrixPathError):
    """An error involving a test group path."""

    def __init__(self, path: Path) -> None:
        """Build an error from its associated test group path."""
        super().__init__(path, f"failed to access test group path: {path}")


class ConfigError(MatrixPathError, ABC):
    """Base class for test configuration-related errors."""


class ConfigPathError(ConfigError):
    """An error involving a test configuration path."""

    def __init__(self, path: Path) -> None:
        """Build an error from its associated test configuration path."""
        super().__init__(path, f"failed to access test configuration path: {path}")


class InvalidConfigError(ConfigError):
    """An error caused by an invalid test configuration."""

    def __init__(self, path: Path) -> None:
        """Build an error from its associated test configuration path."""
        super().__init__(path, f"invalid test configuration: {path}")


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

    configs: tuple[ConfigEntry, ...]
    """Test configuration entries included in this view."""

    errors: tuple[ConfigPathError | InvalidConfigError, ...] = ()
    """Configuration errors captured while materializing."""


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
class ConfigFragmentTuple(ABC):  # noqa: B024
    """An ordered fragment selection from a test configuration.

    Fragment tuples model the positional build or run fragments encoded in a
    test configuration file name, where any missing fragments are represented
    as `nil` in the string form, and as [`None`][] in Python.
    """

    @classmethod
    def parse(cls, string: str) -> Self | None:
        """Parse a fragment tuple from its matrix name encoding.

        This method takes a comma-separated fragment tuple encoded on one side
        of a test configuration file name, where each comma position maps to a
        fixed field on the concrete fragment tuple type.

        The literal `nil` is interpreted as an absent fragment, and any missing
        trailing positions are treated as `nil`. Empty fields are not valid
        fragments; use `nil` to encode an absent fragment.

        If the string cannot be decomposed into the concrete tuple shape for
        any reason, this method instead returns [`None`][].

        Examples:
            >>> build = ConfigBuildFragmentTuple.parse("fvp-default")
            >>> build.tf_a
            'fvp-default'
            >>> build.tfut is None
            True

            >>> ConfigRunFragmentTuple.parse("nil,tfut")
            ConfigRunFragmentTuple(primary=None, tfut='tfut')

            >>> ConfigBuildFragmentTuple.parse("nil") is None
            True
        """
        parts = string.split(",")
        nfields = len(fields(cls))

        if len(parts) > nfields:
            return None

        values = [None if part == "nil" else part for part in parts]
        values.extend([None] * (nfields - len(values)))

        try:
            return cls(*values)
        except ValueError:
            return None

    def __post_init__(self) -> None:
        """Validate that every selected fragment is non-empty.

        Raises:
            ValueError: If any fragment field is an empty string.
        """
        if any(fragment == "" for fragment in astuple(self)):
            message = "fragment tuple fields must not be empty"
            raise ValueError(message)

    def __str__(self) -> str:
        """Return the string representation of this fragment tuple.

        The returned string is the comma-separated form used in test
        configuration file names. Every positional field is emitted.

        Any absent fragment (i.e. any field whose value is [`None`][]) is
        encoded as the special `nil` fragment.

        Examples:
            >>> str(ConfigBuildFragmentTuple(tf_a="fvp-default", tfut="tfut"))
            'fvp-default,nil,nil,nil,nil,tfut'

            >>> str(ConfigRunFragmentTuple())
            'nil,nil'
        """
        return ",".join("nil" if fragment is None else fragment for fragment in astuple(self))


@dataclass(frozen=True, slots=True)
class ConfigBuildFragmentTuple(ConfigFragmentTuple):
    """A build-side fragment selection for a test matrix entry.

    A build fragment tuple records the positional build fragments encoded in a
    test configuration file name. Unlike a run fragment tuple, it must select
    at least one concrete build fragment.

    Raises:
        ValueError: When constructing a build fragment tuple where any field is
            an empty string, or where every field is [`None`][].
    """

    tf_a: str | None = None
    """Fragment selecting the TF-A build configuration."""

    tftf: str | None = None
    """Fragment selecting the TFTF build configuration."""

    hafnium: str | None = None
    """Fragment selecting the Hafnium (SPM) build configuration."""

    rmm: str | None = None
    """Fragment selecting the TF-RMM build configuration."""

    rf_a: str | None = None
    """Fragment selecting the RF-A build configuration."""

    tfut: str | None = None
    """Fragment selecting the TFUT build configuration."""

    def __post_init__(self) -> None:
        """Validate that the build fragment tuple is not empty.

        Raises:
            ValueError: If any fragment field is an empty string, or if every
                build fragment field is [`None`][].
        """
        super().__post_init__()

        if any(fragment is not None for fragment in astuple(self)):
            return

        message = "build fragment tuples must include at least one fragment"
        raise ValueError(message)


@dataclass(frozen=True, slots=True)
class ConfigRunFragmentTuple(ConfigFragmentTuple):
    """A run-side fragment selection for a test matrix entry.

    A run fragment tuple records the positional run fragments encoded in a test
    configuration file name. A run fragment tuple is permitted to be empty to
    indicate that no fragments are involved in the test.
    """

    primary: str | None = None
    """Fragment selecting the primary run configuration."""

    tfut: str | None = None
    """Fragment selecting the TFUT run configuration."""


@dataclass(frozen=True, slots=True)
class ConfigFragmentTuples:
    """A complete fragment selection for a test matrix entry.

    A test configuration file name encodes both build-side and run-side
    fragment tuples. This type groups those two positional selections into the
    complete fragment identity for one test matrix entry.
    """

    build: ConfigBuildFragmentTuple
    """Fragments selecting build configurations to be used by the test."""

    run: ConfigRunFragmentTuple
    """Fragments selecting run configurations to be used by the test."""

    @classmethod
    def parse(cls, string: str) -> Self | None:
        """Parse a complete fragment selection from its matrix name encoding.

        This method takes the fragment portion of a test configuration name,
        containing the build-side and run-side fragment tuples separated by a
        colon (`:`), and parses it into its constituent tuples.

        If the string cannot be decomposed into valid build and run fragment
        tuples, this method returns [`None`][].

        Examples:
            >>> fragments = ConfigFragmentTuples.parse("fvp-default:nil")
            >>> str(fragments)
            'fvp-default,nil,nil,nil,nil,nil:nil,nil'

            >>> ConfigFragmentTuples.parse("fvp-default:nil.inactive") is None
            True
        """
        if string.endswith(".inactive"):
            return None

        try:
            left, right = string.split(":")
        except ValueError:
            return None

        build = ConfigBuildFragmentTuple.parse(left)
        run = ConfigRunFragmentTuple.parse(right)

        if (build is None) or (run is None):
            return None

        return cls(build, run)

    def __str__(self) -> str:
        """Return the matrix name encoding of this fragment selection.

        The returned string joins the build-side and run-side fragment tuple
        encodings with a colon (`:`), matching the fragment portion of a test
        configuration file name.

        Examples:
            >>> fragments = ConfigFragmentTuples(
            ...     build=ConfigBuildFragmentTuple(tf_a="fvp-default"),
            ...     run=ConfigRunFragmentTuple(),
            ... )
            >>>
            >>> str(fragments)
            'fvp-default,nil,nil,nil,nil,nil:nil,nil'
        """
        return f"{self.build}:{self.run}"


@dataclass(frozen=True, slots=True)
class ConfigDescriptor:
    """A generated test descriptor for a test matrix entry.

    A test descriptor combines a generation number, a test group name, and a
    complete fragment selection used to generate a `.test` file.
    """

    number: int
    """Zero-based descriptor number assigned during test generation."""

    group: str
    """Test group represented by the descriptor."""

    fragments: ConfigFragmentTuples
    """Test configuration fragments represented by the descriptor."""

    def __str__(self) -> str:
        """Return the file name encoding of this descriptor.

        The string returned by this method is the file name encoding expected
        by the CI: a zero-padded generation number, the group name, and the
        fragment selection joined with `%`, followed by the `.test` suffix.

        Examples:
            >>> fragments = ConfigFragmentTuples(
            ...     build=ConfigBuildFragmentTuple(tf_a="fvp-default"),
            ...     run=ConfigRunFragmentTuple(),
            ... )
            >>>
            >>> str(ConfigDescriptor(3, "tf-a-l1-build-arm-fvp", fragments))
            '0003%tf-a-l1-build-arm-fvp%fvp-default,nil,nil,nil,nil,nil:nil,nil.test'
        """
        return f"{self.number:04d}%{self.group}%{self.fragments}.test"


@dataclass(frozen=True, slots=True)
class Config:
    """A test configuration within a test group."""

    path: Path
    """File system path to the configuration file."""

    @property
    def name(self) -> str:
        """Configuration file name, stripped of any `.inactive` suffix."""
        return self.path.name.removesuffix(".inactive")

    @property
    def info(self) -> ConfigInfo:
        """Validated matrix information for this test configuration.

        This information is derived from the configuration file name after
        stripping the `.inactive` suffix, if present. It does not inspect the
        configuration file contents.

        Raises:
            InvalidConfigError: If this configuration's file name cannot be
                decomposed into a valid fragment selection.

        Examples:
            >>> from pathlib import Path
            >>>
            >>> info = Config(Path("fvp-default:nil.inactive")).info
            >>> info.state
            <ConfigState.INACTIVE: 'inactive'>
            >>> str(info.fragments)
            'fvp-default,nil,nil,nil,nil,nil:nil,nil'

            >>> try:
            ...     Config(Path("invalid")).info
            ... except InvalidConfigError as error:
            ...     print(error.path)
            invalid
        """
        fragments = ConfigFragmentTuples.parse(self.name)
        if fragments is None:
            raise InvalidConfigError(self.path)

        state = ConfigState.INACTIVE if self.path.name.endswith(".inactive") else ConfigState.ACTIVE

        return ConfigInfo(fragments, state)


@dataclass(frozen=True, slots=True)
class ConfigInfo:
    """Validated matrix information for one test configuration.

    This type represents the path-independent part of a test matrix entry,
    which includes the complete fragment selection encoded by its file name,
    and the entry's enablement state.

    Examples:
        >>> fragments = ConfigFragmentTuples(
        ...     build=ConfigBuildFragmentTuple(tf_a="fvp-default"),
        ...     run=ConfigRunFragmentTuple(),
        ... )
        >>>
        >>> info = ConfigInfo(fragments, ConfigState.ACTIVE)
        >>> info.state
        <ConfigState.ACTIVE: 'active'>
        >>> str(info.fragments)
        'fvp-default,nil,nil,nil,nil,nil:nil,nil'
    """

    fragments: ConfigFragmentTuples
    """Validated fragments selected by the test configuration."""

    state: ConfigState
    """Enablement state for the test configuration."""


@dataclass(frozen=True, slots=True)
class ConfigEntry:
    """A file system-backed record of a validated test matrix entry.

    A test configuration entry binds a path to a test configuration with the
    test matrix information derived from that configuration.

    Examples:
        >>> from pathlib import Path
        >>>
        >>> fragments = ConfigFragmentTuples(
        ...     build=ConfigBuildFragmentTuple(tf_a="fvp-default"),
        ...     run=ConfigRunFragmentTuple(),
        ... )
        >>>
        >>> entry = ConfigEntry(
        ...     Path("fvp-default:nil"),
        ...     ConfigInfo(fragments, ConfigState.ACTIVE),
        ... )
        >>>
        >>> entry.path.name
        'fvp-default:nil'
        >>> entry.info.state
        <ConfigState.ACTIVE: 'active'>
    """

    path: Path
    """Path to the test configuration file."""

    info: ConfigInfo
    """Validated matrix information for the test configuration."""


@dataclass(frozen=True, slots=True)
class GroupQuery:
    """A query applicable to a test group."""

    predicate: Callable[[ConfigInfo], bool] | None = field(default=None, repr=False, compare=False)
    """Optional predicate deciding whether to keep each configuration info."""

    def execute(self, group: Group) -> GroupView:
        """Execute the query on the specified test group.

        Raises:
            GroupPathError: If the test group path could not be traversed. The
                cause chain records the underlying reason.

        Examples:
            >>> store = Store()  # canonical repository store
            >>> group = store.group("tf-a-l1-build-arm-fvp")
            >>>
            >>> query = GroupQuery(lambda info: info.fragments.build.tf_a == "fvp-default")
            >>> view = query.execute(group)
            >>>
            >>> [entry.path.name for entry in view.configs]
            ['fvp-default:nil']
        """
        configs: list[ConfigEntry] = []
        errors: list[ConfigPathError | InvalidConfigError] = []

        for item in group.configs():
            if isinstance(item, ConfigPathError):
                errors.append(item)
                continue

            try:
                entry = ConfigEntry(item.path, item.info)
            except InvalidConfigError as error:
                errors.append(error)
                continue

            if (self.predicate is None) or self.predicate(entry.info):
                configs.append(entry)

        return GroupView(
            group=group,
            configs=tuple(sorted(configs, key=lambda entry: entry.path)),
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

        Examples:
            >>> store = Store()  # canonical repository store
            >>>
            >>> view = StoreQuery(
            ...     predicate=lambda group: group.path.name == "tf-a-l1-build-arm-fvp",
            ...     groups=GroupQuery(lambda info: info.fragments.build.tf_a == "fvp-default"),
            ... ).execute(store)
            >>>
            >>> [group.group.path.name for group in view.groups]
            ['tf-a-l1-build-arm-fvp']
            >>> [entry.path.name for entry in view.groups[0].configs]
            ['fvp-default:nil']
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
            groups=tuple(sorted(groups, key=lambda view: view.group.path)),
            errors=tuple(sorted(errors, key=lambda error: error.path)),
        )
