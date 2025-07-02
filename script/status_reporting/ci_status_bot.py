#!/usr/bin/env python3

import argparse
import asyncio
import re
import sys
from dataclasses import dataclass

import aiohttp

# Constants to produce the report with
openci_url = "https://ci.trustedfirmware.org/"

# Jenkins API helpers
def get_job_url(job_name: str) -> str:
    return openci_url + f"job/{job_name}/api/json"

def get_build_url(job_name: str, build_number: str) -> str:
    return openci_url + f"job/{job_name}/{build_number}"

def get_build_api(build_url: str) -> str:
    return build_url + "/api/json"

def get_build_console(build_url: str) -> str:
    return build_url + "/consoleText"

async def get_json(session, url):
    async with session.get(url) as response:
        return await response.json()

async def get_text(session, url):
    async with session.get(url) as response:
        return await response.text()

"""Finds the latest run of a given job by name"""
async def process_job(session, job_name: str) -> str:
    req = await get_json(session, get_job_url(job_name))

    name = req["displayName"]
    number = req["lastCompletedBuild"]["number"]

    build = Build(session, name, name, number, level=0)
    await build.process()

    return (build.passed, build.print_build_status())

"""Represents an individual build. Will recursively fetch sub builds"""
class Build:
    def __init__(self, session, job_name, pretty_job_name: str, build_number: str, level: int) -> None:
        self.session = session
        self.url = get_build_url(job_name, build_number)
        self.pretty_job_name = pretty_job_name
        self.name = None
        self.build_number = build_number
        self.level = level

    async def process(self):
        req = await get_json(self.session, get_build_api(self.url))
        self.passed = req["result"].lower() == "success"

        self.name = self.pretty_job_name
        # The full display name is "{job_name} {build_number}"
        if self.name == "":
            self.name = req["fullDisplayName"].split(" ")[0]
        # and builds should show up with their configuration name
        elif self.name == "tf-a-builder":
            self.name = req["actions"][0]["parameters"][1]["value"]

        self.sub_builds = []

        # parent job passed => children passed. Skip
        if not self.passed:
            # the main jobs list sub builds nicely
            self.sub_builds = [
                # the gateways get an alias to differentiate them
                Build(self.session, build["jobName"], build["jobAlias"], build["buildNumber"], self.level + 1)
                for build in req.get("subBuilds", [])
            ]
            # gateways don't, since they determine them dynamically
            if self.sub_builds == []:
                self.sub_builds = [
                    Build(self.session, name, name, num, self.level + 1)
                    for name, num in await self.get_builds_from_console_log()
                ]

            # process sub-jobs concurrently
            await asyncio.gather(*[
                build.process()
                for build in self.sub_builds
            ])

    # extracts (child_name, child_number) from the console output of a build
    async def get_builds_from_console_log(self) -> str:
        log = await get_text(self.session, get_build_console(self.url))

        return re.findall(r"(tf-a[-\w+]+) #(\d+) started", log)

    def print_build_status(self) -> str:
        message = "" + str(self)

        for build in self.sub_builds:
            if not build.passed:
                message += build.print_build_status()
        return message

    def __str__(self) -> str:
        return (f"{' ' * self.level * 4}* {'✅' if self.passed else '❌'} "
                f"**{self.name}** [#{self.build_number}]({self.url})\n"
               )

async def main(session, job_names: list[str]) -> str:
    # process jobs concurrently
    results = await asyncio.gather(
        *[process_job(session, name) for name in job_names]
    )

    final_msg = "🟢" if all(j[0] for j in results) else "🔴"
    final_msg += " Daily Status\n"
    for passed, message in results:
        final_msg += message

    return final_msg

async def run_local(jobs: list[str]) -> str:
    async with aiohttp.ClientSession() as session:
        msg = await main(session, jobs)
        print(msg)

def add_jobs_arg(parser):
    parser.add_argument(
        "-j", "--jobs",
        metavar="JOB_NAME", default=["tf-a-daily"], nargs="+",
        help="CI jobs to monitor"
    )

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Latest CI run status",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    add_jobs_arg(parser)

    args = parser.parse_args(sys.argv[1:])

    asyncio.run(run_local(args.jobs))
