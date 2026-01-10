#!/usr/bin/env python3

import argparse
import asyncio
import json
import os
import sys

import aiohttp

def format_patch_totals(totals, header="Patches in review: {}", bullet="*"):
    lines = [header.format(sum(totals.values()))]
    for name, count in sorted(totals.items(), key=lambda it: it[1], reverse=True):
        lines.append(f"{bullet} {name}: {count}")
    return "\n".join(lines)

async def get_patch_counts(session, query: str) -> str:
    url = "https://review.trustedfirmware.org/changes/?q="
    skip_arg = "&S={}"
    skip_num = 0

    totals = {}
    while True:
        async with session.get(url + query + skip_arg.format(skip_num)) as response:
            text = (await response.text())[4:] # strip magic string ")]}'"
            data = json.loads(text)

            for entry in data:
                name = entry["project"]
                totals[name] = totals.get(name, 0) + 1

            if len(data) and data[-1].get("_more_changes", False):
                skip_num = len(data)
            else:
                break
    return totals

async def run_local(query: str) -> str:
    async with aiohttp.ClientSession() as session:
        msg = await get_patch_counts(session, query)
        print(format_patch_totals(msg))

def add_gerrit_arg(parser):
    gerrit_project_prefix = os.environ.get("GERRIT_PROJECT_PREFIX", "")

    parser.add_argument(
        "-q", "--tforg-gerrit-query",
        default=(
            f"(parentproject:{gerrit_project_prefix}TF-A OR parentproject:{gerrit_project_prefix}TF-RMM OR parentproject:{gerrit_project_prefix}TS OR "
            f"parentproject:{gerrit_project_prefix}hafnium OR parentproject:{gerrit_project_prefix}RF-A OR "
            f"parentproject:{gerrit_project_prefix}arm-firmware-crates OR "
            f"project:^{gerrit_project_prefix}shared/libEventLog OR "
            f"project:^{gerrit_project_prefix}shared/transfer-list-library OR "
            f"project:^{gerrit_project_prefix}ci/hafnium-.%2B OR project:^{gerrit_project_prefix}ci/tf-a-.%2B) "
            "(branch:integration OR branch:master OR branch:main OR "
            "branch:^topics\\/.*) -is:wip is:open"
        ), help="the query to pass to tforg's Gerrit (as written in the query box)"
    )

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Counter of patches in tforg's gerrit",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    add_gerrit_arg(parser)
    args = parser.parse_args(sys.argv[1:])

    asyncio.run(run_local(args.tforg_gerrit_query))
