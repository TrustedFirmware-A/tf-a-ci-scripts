#!/usr/bin/env python3

import argparse
import asyncio
import re
import sys
from dataclasses import dataclass

import aiohttp


@dataclass
class BuildStatus:
    name: str
    build_number: str
    url: str
    passed: bool
    sub_builds: list["BuildStatus"]

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
        try:
            return await response.json()
        except Exception as e:
            print(session, url)
            raise e


async def get_text(session, url):
    async with session.get(url) as response:
        return await response.text()

"""Finds the latest run of a given job by name"""
async def process_job(session, job_name: str) -> BuildStatus:
    req = await get_json(session, get_job_url(job_name))

    name = req["displayName"]
    number = req["lastCompletedBuild"]["number"]

    build = Build(session, name, name, number)
    await build.process()

    return build.to_status()

"""Represents an individual build. Will recursively fetch sub builds"""
class Build:
    def __init__(self, session, job_name, pretty_job_name: str, build_number: str) -> None:
        self.session = session
        self.url = get_build_url(job_name, build_number)
        self.pretty_job_name = pretty_job_name
        self.name = None
        self.build_number = str(build_number)
        self.sub_builds = []

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

        # parent job passed => children passed. Skip
        if not self.passed:
            # the main jobs list sub builds nicely
            self.sub_builds = [
                # the gateways get an alias to differentiate them
                Build(self.session, build["jobName"], build["jobAlias"], build["buildNumber"])
                for build in req.get("subBuilds", [])
            ]
            # gateways don't, since they determine them dynamically
            # but the windows job doesn't parse. It's a leaf anyway so skip
            if self.sub_builds == [] and self.name != "tf-a-windows-builder":
                self.sub_builds = [
                    Build(self.session, name, name, num)
                    for name, num in await self.get_builds_from_console_log()
                ]

            # process sub-jobs concurrently
            await asyncio.gather(*[
                build.process()
                for build in self.sub_builds
            ])

    def to_status(self) -> BuildStatus:
        return BuildStatus(
            name=self.name,
            build_number=self.build_number,
            url=self.url,
            passed=self.passed,
            sub_builds=[build.to_status() for build in self.sub_builds],
        )

    # extracts (child_name, child_number) from the console output of a build
    async def get_builds_from_console_log(self) -> str:
        log = await get_text(self.session, get_build_console(self.url))

        return re.findall(r"(tf-a[-\w+]+) #(\d+) started", log)

async def get_daily_jobs(session, job_names: list[str]) -> list[BuildStatus]:
    return await asyncio.gather(
        *[process_job(session, name) for name in job_names]
    )

def build_status_to_markdown(status: BuildStatus, level: int = 0) -> str:
    message = (f"{' ' * level * 2}* {'✅' if status.passed else '❌'} "
               f"**{status.name}** [#{status.build_number}]({status.url})\n")
    if not status.passed:
        for sub_status in status.sub_builds:
            message += build_status_to_markdown(sub_status, level + 1)
    return message

def print_build_status(status: BuildStatus, level: int = 0) -> str:
    """Return markdown for failing jobs only."""
    if status.passed:
        return ""

    message = (f"{' ' * level * 2}* ❌ **{status.name}** "
               f"[#{status.build_number}]({status.url})\n")
    for sub_status in status.sub_builds:
        message += print_build_status(sub_status, level + 1)
    return message

def format_daily_status(statuses: list[BuildStatus]) -> str:
    header = ("🟢" if all(job.passed for job in statuses) else "🔴") + " Daily Status"

    details = "".join(print_build_status(status) for status in statuses).rstrip()
    if details:
        return f"{header}\n{details}\n"
    return header + "\n"

async def main(session, job_names: list[str]) -> str:
    statuses = await get_daily_jobs(session, job_names)
    return format_daily_status(statuses)

async def run_local(jobs: list[str]) -> str:
    async with aiohttp.ClientSession() as session:
        statuses = await get_daily_jobs(session, jobs)
        msg = format_daily_status(statuses)
        print(msg)
        return msg

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
