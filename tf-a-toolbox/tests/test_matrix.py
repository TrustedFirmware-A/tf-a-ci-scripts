from pathlib import Path

from tf_a_toolbox.matrix import Config, ConfigState, Group, GroupQuery, Store, StoreQuery


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


def test_active_config_state_is_active() -> None:
    config = Config(Path("fvp-default:nil"))

    assert config.state is ConfigState.ACTIVE


def test_inactive_config_state_is_inactive() -> None:
    config = Config(Path("fvp-default:nil.inactive"))

    assert config.state is ConfigState.INACTIVE


def test_group_query_filters_configs(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "z.conf").write_text("")
    (group_path / "a.conf.inactive").write_text("")

    view = GroupQuery(
        lambda config: config.state is ConfigState.ACTIVE,
    ).execute(Group(group_path))

    assert [config.path.name for config in view.configs] == ["z.conf"]


def test_group_query_sorts_configs_by_name(tmp_path: Path) -> None:
    group_path = tmp_path / "group-a"
    group_path.mkdir()

    (group_path / "z.conf").write_text("")
    (group_path / "a.conf").write_text("")

    view = GroupQuery().execute(Group(group_path))

    assert [config.path.name for config in view.configs] == ["a.conf", "z.conf"]


def test_store_query_filters_groups(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "skip").mkdir()
    (store_path / "group-a").mkdir()

    view = StoreQuery(lambda group: group.path.name != "skip").execute(Store(store_path))

    assert [group.group.path.name for group in view.groups] == ["group-a"]


def test_store_query_filters_nested_configs(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "group-a").mkdir()
    (store_path / "group-a" / "z.conf.inactive").write_text("")
    (store_path / "group-a" / "a.conf").write_text("")

    view = StoreQuery(
        groups=GroupQuery(lambda config: config.state is ConfigState.ACTIVE),
    ).execute(Store(store_path))

    assert [config.path.name for config in view.groups[0].configs] == ["a.conf"]


def test_store_query_sorts_groups_by_name(tmp_path: Path) -> None:
    store_path = tmp_path / "group"
    store_path.mkdir()

    (store_path / "group-b").mkdir()
    (store_path / "group-a").mkdir()

    view = StoreQuery().execute(Store(store_path))

    assert [group.group.path.name for group in view.groups] == ["group-a", "group-b"]
