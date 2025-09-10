#!/usr/bin/env python3

import argparse
import asyncio
import json
import sys

import aiohttp

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

    message = "Patches in review:\n"
    for name, count in sorted(totals.items(), key=lambda it: it[1], reverse=True):
        message += f"* {name}: {count}\n"
    return message

async def run_local(query: str) -> str:
    async with aiohttp.ClientSession() as session:
        msg = await get_patch_counts(session, query)
        print(msg)

def add_gerrit_arg(parser):
    parser.add_argument(
        "-q", "--tforg-gerrit-query",
        default=(
            "(parentproject:TF-A OR parentproject:TF-RMM OR parentproject:TS OR "
            "parentproject:hafnium OR parentproject:RF-A OR "
            "parentproject:arm-firmware-crates OR "
            "project:^ci/hafnium-.%2B OR project:^ci/tf-a-.%2B) "
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
