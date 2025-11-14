#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "click~=8.1.7",
#     "prettytable~=3.10.0",
# ]
# ///

import csv
import re
from math import isclose
from statistics import mean
from sys import stdout
from typing import Optional
from collections import defaultdict

import click
import prettytable

CoreIdTuple = tuple[str, str]
ResultTuple = tuple[str, CoreIdTuple, list[int]]
ResultsRaw = dict[CoreIdTuple, list[list[int]]]
ResultsAgg = dict[CoreIdTuple, list[int]]
AllResultsRaw = dict[str, ResultsRaw]
AllResultsAgg = dict[str, ResultsAgg]

UNIT_FACTORS: dict[str, tuple[float, str]] = {
    "ns": (1.0, "ns"),
    "us": (1_000.0, "us"),
}


def format_latency(value: float, scale: float = 1.0) -> str:
    return f"{value / scale:,.0f}"


def resolve_units(units: str) -> tuple[str, float]:
    key = units.lower()
    if key not in UNIT_FACTORS:
        valid = ", ".join(sorted({canonical for _, canonical in UNIT_FACTORS.values()}))
        raise click.BadParameter(
            f"Unsupported units '{units}'. Choose one of: {valid}",
            param_hint="--units",
        )
    scale, canonical = UNIT_FACTORS[key]
    return canonical, scale


def process_rt_instr(result: str) -> Optional[ResultTuple]:
    m = re.search(
        r"<RT_INSTR:(\w+)\t(\d+)\t(\d+)\t(\d+)(?:\t(\d+))?(?:\t(\d+))?",
        result,
    )

    if m is not None:
        test, cluster, core, *data = m.groups()
        return test, (cluster, core), [int(i) for i in data if i is not None]

    return None


def process_lava_log(filename: str) -> AllResultsAgg:
    results: AllResultsRaw = defaultdict(lambda: defaultdict(list))

    with open(filename, "r") as f:
        for line in f:
            result_tuple = process_rt_instr(line)
            if result_tuple:
                test, core_id, data = result_tuple
                results[test][core_id].append(data)

    # Aggregate multiple samples per (test, core) by taking the mean per column.
    aggregated: AllResultsAgg = {}
    for test, per_core in results.items():
        aggregated[test] = {}
        for core_id, samples in per_core.items():
            # zip(*) groups each metric column across samples; map(mean, ...) averages them.
            aggregated[test][core_id] = list(map(mean, zip(*samples)))

    return aggregated


def print_test_result_table(
    title: str,
    data: ResultsAgg,
    candidate_data: ResultsAgg | None = None,
    rtol: float = 0.01,
    units: str = "ns",
    unit_scale: float = 1.0,
    header: list[str] = ["Cluster", "Core", "Powerdown", "Wakeup", "Cache Flush"],
):
    # If title includes "version", collapse to a single "Latency" column.
    base_fields = header if "version" not in title else header[:2] + ["Latency"]
    fields = base_fields.copy()
    for idx in range(2, len(fields)):
        fields[idx] = f"{fields[idx]} ({units})"

    table = prettytable.PrettyTable(
        title=title,
        field_names=fields,
        hrules=prettytable.ALL,
    )

    def to_str_delta(x1: float, x2: float) -> str:
        # No delta if within tolerance; handle x1 == 0 safely.
        if isclose(x1, x2, rel_tol=rtol):
            return ""
        if x1 == 0:
            return " (+∞)" if x2 > 0 else " (0.00%)"
        return f" ({(x2 - x1) / x1:+.2%})"

    # Build rows, optionally including deltas vs candidate
    rows = []
    keys = sorted(data.keys(), key=lambda k: (k[0], k[1]))
    for core_id in keys:
        base_vals = data[core_id]
        if candidate_data and core_id in candidate_data:
            cand_vals = candidate_data[core_id]
            # Format values with thousand separators and append delta string.
            formatted = [
                f"{format_latency(new, unit_scale)}{to_str_delta(prev, new)}"
                for prev, new in zip(base_vals, cand_vals)
            ]
        else:
            formatted = [format_latency(v, unit_scale) for v in base_vals]
        rows.append(list(core_id) + formatted)

    table.add_rows(rows)
    print(table)


@click.command(
    help=(
        "Parse a baseline lava log and optionally compare it to a candidate log. "
        "Both files must be raw LAVA outputs that include <RT_INSTR:...> records."
    )
)
@click.argument(
    "base",
    type=click.Path(exists=True, dir_okay=False),
)
@click.argument(
    "candidate",
    required=False,
    type=click.Path(exists=True, dir_okay=False),
)
@click.option(
    "-r",
    "--rtol",
    type=float,
    default=0.01,
    show_default=True,
    help="Allowed relative tolerance.",
)
@click.option(
    "-f",
    "--fmt",
    type=click.Choice(["table", "csv"]),
    default="table",
    show_default=True,
    help="Output format.",
)
@click.option(
    "-u",
    "--units",
    default="ns",
    show_default=True,
    help="Presentation units for latency values (ns or us).",
)
def main(base: str, candidate: str | None, rtol: float, fmt: str | None, units: str):
    display_units, unit_scale = resolve_units(units)
    base_data = process_lava_log(base)
    candidate_data = None if not candidate else process_lava_log(candidate)

    csv_file = csv.writer(stdout) if fmt == "csv" else None

    for test_name, data in base_data.items():
        if csv_file:
            csv_file.writerow([test_name])
            for core_id in sorted(data.keys(), key=lambda k: (k[0], k[1])):
                csv_file.writerow(
                    list(core_id)
                    + [format_latency(value, unit_scale) for value in data[core_id]]
                )
        else:
            print_test_result_table(
                test_name,
                data,
                candidate_data.get(test_name) if candidate_data else None,
                rtol,
                display_units,
                unit_scale,
            )


if __name__ == "__main__":
    main()
