#!/usr/bin/env python3

import re
from dataclasses import dataclass

import requests

# Constants to produce the report with
openci_url = "https://ci.trustedfirmware.org/"
job_names = ["tf-a-daily", "tf-a-tftf-main"]

# Jenkins API helpers
def get_job_url(job_name: str) -> str:
    return openci_url + f"job/{job_name}/api/json"

def get_build_url(job_name: str, build_number: str) -> str:
    return openci_url + f"job/{job_name}/{build_number}"

def get_build_api(build_url: str) -> str:
    return build_url + "/api/json"

def get_build_console(build_url: str) -> str:
    return build_url + "/consoleText"

"""Finds the latest run of a given job by name"""
class Job:
    def __init__(self, job_name: str) -> None:
        req = requests.get(get_job_url(job_name)).json()
        name = req["displayName"]
        number = req["lastCompletedBuild"]["number"]

        self.build = Build(name, name, number, level=0)
        self.passed = self.build.passed

    def print_build_status(self):
        self.build.print_build_status()

"""Represents an individual build. Will recursively fetch sub builds"""
class Build:
    def __init__(self, job_name: str, pretty_job_name: str, build_number: str, level: int) -> None:
        self.url = get_build_url(job_name, build_number)
        req = requests.get(get_build_api(self.url)).json()
        self.passed = req["result"].lower() == "success"

        self.name = pretty_job_name
        # The full display name is "{job_name} {build_number}"
        if self.name == "":
            self.name = req["fullDisplayName"].split(" ")[0]
        # and builds should show up with their configuration name
        elif self.name == "tf-a-builder":
            self.name = req["actions"][0]["parameters"][1]["value"]

        self.level = level
        self.number = build_number
        self.sub_builds = []

        # parent job passed => children passed. Skip
        if not self.passed:
            # the main jobs list sub builds nicely
            self.sub_builds = [
                # the gateways get an alias to differentiate them
                Build(build["jobName"], build["jobAlias"], build["buildNumber"], level + 1)
                for build in req.get("subBuilds", [])
            ]
            # gateways don't, since they determine them dynamically
            if self.sub_builds == []:
                self.sub_builds = [
                    Build(name, name, num, level + 1)
                    for name, num in self.get_builds_from_console_log()
                ]

    # extracts (child_name, child_number) from the console output of a build
    def get_builds_from_console_log(self) -> str:
        log = requests.get(get_build_console(self.url)).text

        return re.findall(r"(tf-a[-\w+]+) #(\d+) started", log)

    def print_build_status(self):
        print(self)

        for build in self.sub_builds:
            if not build.passed:
                build.print_build_status()

    def __str__(self) -> str:
        return (f"{' ' * self.level * 4}* {'✅' if self.passed else '❌'} "
                f"*{self.name}* [#{self.number}]({self.url})"
               )

def main():
    jobs = [Job(name) for name in job_names]

    print("🟢" if all(j.passed for j in jobs) else "🔴", "Daily Status")

    for j in jobs:
        j.print_build_status()

if __name__ == "__main__":
    main()
