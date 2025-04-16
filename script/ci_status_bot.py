#!/usr/bin/env python3

import re
from dataclasses import dataclass

import requests

openci_url = "http://ci.trustedfirmware.org/"


class Job:

    def __init__(self, name: str, response: dict, get_sub_jobs=False) -> None:
        self.name = name
        self.url = (
            response["url"]
            if openci_url in response["url"]
            else openci_url + response["url"]
        )
        self.number = (
            response["buildNumber"] if "buildNumber" in response else response["number"]
        )

        if "result" in response:
            self.passed = response["result"].lower() == "success"

        if get_sub_jobs and not "subBuilds" in response:
            console = requests.get(self.url + "consoleText").text
            self.set_sub_jobs(SubJob.get_jobs_from_console_log(console))
        elif "subBuilds" in response:
            self.set_sub_jobs(
                list(map(lambda j: SubJob(j["jobAlias"], j), response["subBuilds"]))
            )
        else:
            self.jobs = []

    def __str__(self) -> str:
        return f"{'✅' if self.passed else '❌'} *{self.name}*"

    def __iter__(self):
        yield from self.jobs

    def failed_sub_jobs(self):
        return list(filter(lambda j: not j.passed, self.jobs))

    def print_failed_subjobs(self):
        for j in self.failed_sub_jobs():
            print(" " * 2, j)

    def set_sub_jobs(self, jobs):
        self.jobs = jobs
        self.passed = not self.failed_sub_jobs()


class SubJob(Job):

    def __str__(self) -> str:
        return f"• *{self.name}* [#{self.number}]({self.url}) {'✅' if self.passed else '❌'}"

    @classmethod
    def get_jobs_from_console_log(cls, log):
        sub_jobs = []

        for name, num in re.findall(r"(tf-a[-\w+]+) #(\d+) started", log):
            response = requests.get(openci_url + f"job/{name}/{num}/api/json").json()
            sub_jobs.append(cls(name, response, get_sub_jobs=False))
        return sub_jobs


def main():
    job_urls = map(
        lambda j: openci_url + f"job/{j}/api/json", ["tf-a-daily", "tf-a-tftf-main"]
    )

    jobs = list(
        map(
            lambda r: Job(r["displayName"], r["lastCompletedBuild"], get_sub_jobs=True),
            map(lambda j: requests.get(j).json(), job_urls),
        )
    )

    print("🟢" if all(j.passed for j in jobs) else "🔴", "Daily Status")

    for j in jobs:
        print("\n", j, f"[#{j.number}]({j.url})", "\n")
        if j.name == "tf-a-daily" or not j.passed:
            for subjob in j:
                print(subjob)
                subjob.print_failed_subjobs()


if __name__ == "__main__":
    main()
