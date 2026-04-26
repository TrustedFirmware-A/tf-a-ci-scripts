from pathlib import Path

import pytest

from tf_a_toolbox.matrix import (
    Config,
    ConfigBuildFragmentTuple,
    ConfigDescriptor,
    ConfigFragmentTuples,
    ConfigInfo,
    ConfigRunFragmentTuple,
    ConfigState,
    Group,
    GroupQuery,
    InvalidConfigError,
    Store,
    StoreQuery,
)


def test_store_groups_yield_group_directories(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "group-b").mkdir()
    (store_path / "group-a").mkdir()

    groups = sorted(item.path.name for item in Store(store_path).groups())

    assert groups == ["group-a", "group-b"]


def test_store_groups_skip_generated_directory(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "GENERATED").mkdir()
    (store_path / "group-a").mkdir()

    groups = sorted(item.path.name for item in Store(store_path).groups())

    assert groups == ["group-a"]


def test_store_groups_skip_non_directories(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "notes.txt").write_text("not a test group")
    (store_path / "group-a").mkdir()

    groups = sorted(item.path.name for item in Store(store_path).groups())

    assert groups == ["group-a"]


def test_group_configs_yield_regular_files(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "z.conf").write_text("")
    (group_path / "a.conf.inactive").write_text("")

    configs = sorted(item.path.name for item in Group(group_path).configs())

    assert configs == ["a.conf.inactive", "z.conf"]


def test_group_configs_skip_directories(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "nested").mkdir()
    (group_path / "z.conf").write_text("")

    configs = [item.path.name for item in Group(group_path).configs()]

    assert configs == ["z.conf"]


def test_active_config_info_state_is_active() -> None:
    config = Config(Path("fvp-default:nil"))

    assert config.info.state is ConfigState.ACTIVE


def test_inactive_config_info_state_is_inactive() -> None:
    config = Config(Path("fvp-default:nil.inactive"))

    assert config.info.state is ConfigState.INACTIVE


@pytest.mark.parametrize(
    ("file_name", "expected_name"),
    [
        ("fvp-default:nil", "fvp-default:nil"),
        ("fvp-default:nil.inactive", "fvp-default:nil"),
    ],
)
def test_config_name_returns_unsuffixed_file_name(file_name: str, expected_name: str) -> None:
    config = Config(Path(file_name))

    assert config.name == expected_name


def test_build_fragments_parse_pads_missing_fragments() -> None:
    fragments = ConfigBuildFragmentTuple.parse("fvp-default")

    assert fragments is not None
    assert fragments == ConfigBuildFragmentTuple(tf_a="fvp-default")
    assert str(fragments) == "fvp-default,nil,nil,nil,nil,nil"


def test_build_fragments_parse_returns_none_for_too_many_fragments() -> None:
    assert ConfigBuildFragmentTuple.parse("tf-a,tftf,hafnium,rmm,rf-a,tfut,extra") is None


@pytest.mark.parametrize(
    "string",
    [
        "",
        ",tftf",
        "tf-a,",
        "tf-a,,hafnium",
    ],
)
def test_build_fragments_parse_returns_none_for_empty_fragment_fields(string: str) -> None:
    assert ConfigBuildFragmentTuple.parse(string) is None


def test_build_fragments_reject_empty_selection() -> None:
    with pytest.raises(ValueError, match="at least one fragment"):
        ConfigBuildFragmentTuple()


def test_build_fragments_reject_empty_fragment_fields() -> None:
    with pytest.raises(ValueError, match="must not be empty"):
        ConfigBuildFragmentTuple(tf_a="")


def test_build_fragments_parse_returns_none_for_empty_selection() -> None:
    assert ConfigBuildFragmentTuple.parse("nil") is None


def test_run_fragments_parse_accepts_tfut_fragment() -> None:
    fragments = ConfigRunFragmentTuple.parse("nil,memcpy")

    assert fragments is not None
    assert fragments == ConfigRunFragmentTuple(tfut="memcpy")
    assert str(fragments) == "nil,memcpy"


def test_run_fragments_parse_returns_none_for_too_many_fragments() -> None:
    assert ConfigRunFragmentTuple.parse("primary,tfut,extra") is None


def test_run_fragments_reject_empty_fragment_fields() -> None:
    with pytest.raises(ValueError, match="must not be empty"):
        ConfigRunFragmentTuple(primary="")


@pytest.mark.parametrize("string", ["", ",tfut", "primary,", "nil,"])
def test_run_fragments_parse_returns_none_for_empty_fragment_fields(string: str) -> None:
    assert ConfigRunFragmentTuple.parse(string) is None


def test_config_fragments_parse_normalizes_missing_build_fragments() -> None:
    fragments = ConfigFragmentTuples.parse("fvp-default:nil")

    assert fragments is not None
    assert str(fragments) == "fvp-default,nil,nil,nil,nil,nil:nil,nil"


def test_config_fragments_parse_returns_none_for_inactive_suffix() -> None:
    assert ConfigFragmentTuples.parse("fvp-default:nil.inactive") is None


def test_config_fragments_parse_returns_none_for_invalid_separator_count() -> None:
    assert ConfigFragmentTuples.parse("fvp-default") is None


@pytest.mark.parametrize(
    "string",
    [
        "fvp-default:",
        ":nil",
        "foo:nil,",
        "foo:,tfut",
    ],
)
def test_config_fragments_parse_returns_none_for_empty_fragment_fields(string: str) -> None:
    assert ConfigFragmentTuples.parse(string) is None


def test_config_descriptor_string_uses_generated_descriptor_format() -> None:
    fragments = ConfigFragmentTuples.parse("fvp-default:nil")

    assert fragments is not None

    descriptor = ConfigDescriptor(
        number=3,
        group="tf-a-l1-build-arm-fvp",
        fragments=fragments,
    )

    assert str(descriptor) == (
        "0003%tf-a-l1-build-arm-fvp%fvp-default,nil,nil,nil,nil,nil:nil,nil.test"
    )


def test_config_info_fragments_strip_inactive_suffix() -> None:
    config = Config(Path("fvp-default:nil.inactive"))
    fragments = ConfigFragmentTuples.parse("fvp-default:nil")

    assert fragments is not None
    assert config.info.fragments == fragments


def test_config_info_raises_for_invalid_config() -> None:
    config = Config(Path("fvp-default"))

    with pytest.raises(InvalidConfigError) as error_info:
        _ = config.info

    assert error_info.value.path == config.path
    assert not hasattr(error_info.value, "name")


@pytest.mark.parametrize(
    "file_name",
    [
        "fvp-default:",
        ":nil",
        "foo:nil,",
    ],
)
def test_config_info_raises_for_empty_fragment_fields(file_name: str) -> None:
    config = Config(Path(file_name))

    with pytest.raises(InvalidConfigError) as error_info:
        _ = config.info

    assert error_info.value.path == config.path


def test_config_info_can_be_synthesized_without_path() -> None:
    fragments = ConfigFragmentTuples.parse("fvp-default:nil")

    assert fragments is not None

    info = ConfigInfo(fragments=fragments, state=ConfigState.ACTIVE)

    assert info.fragments == fragments
    assert info.state is ConfigState.ACTIVE


def test_group_query_filters_configs(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "z:nil").write_text("")
    (group_path / "a:nil.inactive").write_text("")

    view = GroupQuery(
        predicate=lambda info: info.state is ConfigState.ACTIVE,
    ).execute(Group(group_path))

    assert [config.path.name for config in view.configs] == ["z:nil"]


def test_group_query_sorts_configs_by_name(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "z:nil").write_text("")
    (group_path / "a:nil").write_text("")

    view = GroupQuery().execute(Group(group_path))

    assert [config.path.name for config in view.configs] == ["a:nil", "z:nil"]


def test_group_query_captures_invalid_configs(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "invalid").write_text("")

    view = GroupQuery().execute(Group(group_path))

    assert view.configs == ()
    assert len(view.errors) == 1
    assert isinstance(view.errors[0], InvalidConfigError)


def test_group_query_captures_configs_with_empty_fragment_fields(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "fvp-default:").write_text("")
    (group_path / ":nil").write_text("")
    (group_path / "foo:nil,").write_text("")

    view = GroupQuery().execute(Group(group_path))

    assert view.configs == ()
    assert [error.path.name for error in view.errors] == [
        ":nil",
        "foo:nil,",
        "fvp-default:",
    ]
    assert all(isinstance(error, InvalidConfigError) for error in view.errors)


def test_store_query_filters_groups(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "skip").mkdir()
    (store_path / "group-a").mkdir()

    view = StoreQuery(
        predicate=lambda group: group.path.name != "skip",
    ).execute(Store(store_path))

    assert [group.group.path.name for group in view.groups] == ["group-a"]


def test_store_query_filters_nested_configs(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "group-a").mkdir()
    (store_path / "group-a" / "z:nil.inactive").write_text("")
    (store_path / "group-a" / "a:nil").write_text("")

    view = StoreQuery(
        groups=GroupQuery(lambda info: info.state is ConfigState.ACTIVE),
    ).execute(Store(store_path))

    assert [config.path.name for config in view.groups[0].configs] == ["a:nil"]


def test_store_query_sorts_groups_by_name(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "group-b").mkdir()
    (store_path / "group-a").mkdir()

    view = StoreQuery().execute(Store(store_path))

    assert [group.group.path.name for group in view.groups] == ["group-a", "group-b"]
