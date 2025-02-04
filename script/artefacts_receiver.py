#!/usr/bin/env python3
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This is a server that accepts PUT requests that's primary used to receive
# artefacts from Jenkins. Received files are placed under the output directory
# under the same path mentioned in the URL.
#
# The script takes two arguments: IP address and a port number to listen to.
# Note that the IP address has to be externally visible.

import argparse
import calendar
import heapq
import http.server
import itertools
import json
import os
import shutil
import socketserver
import threading
import time
import traceback
import urllib
import urllib.request


JENKINS_PUBLIC_URL = "http://jenkins.oss.arm.com"
counter = itertools.count()
exiting = False
more_consoles = threading.Event()
pq = []
received = set()


# Class representing a pending job whose console is yet to be downloaded. The
# methods help identify when the job is finished (ready to download console),
# and to download the console along with the received artefacts.
class PendingJob:
    def __init__(self, job, build, path):
        self.job = job
        self.build = build
        self.path = path
        self.url = "/".join([JENKINS_PUBLIC_URL, "job", self.job, self.build])

    def download_console(self, more):
        console_url = "/".join([self.url, "consoleText"])
        try:
            with urllib.request.urlopen(console_url) as cfd, \
                    open(os.path.join(self.path, "console.txt"), "wb") as fd:
                shutil.copyfileobj(cfd, fd)

            print("{}: {}#{}: console (+{})".format(time_now(), self.job,
                self.build, more))
        except Exception as e:
            traceback.print_exception(Exception, e, e.__traceback__)

    def is_ready(self):
        # Return true if there were errors as otherwise this job won't ever be
        # completed.
        ret = True

        json_url = "/".join([self.url, "api", "json"])
        try:
            with urllib.request.urlopen(json_url) as fd:
                job_json = json.loads(fd.read().decode())
                ret = job_json["building"] == False
        except Exception as e:
            traceback.print_exception(Exception, e, e.__traceback__)

        return ret


# PUT handler for the receiver. When an artefact with a valid job name and build
# number is received, we keep a pending job instance to download its console
# when the job finishes.
class ArtefactsReceiver(http.server.BaseHTTPRequestHandler):
    def do_PUT(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.lstrip("/")
        relpath = os.path.join(opts.output_dir, os.path.dirname(path))

        os.makedirs(relpath, exist_ok=True)
        content_length = int(self.headers["Content-Length"])

        with open(os.path.join(opts.output_dir, path), "wb") as fd:
            fd.write(self.rfile.read(content_length))

        self.send_response(200)
        self.end_headers()

        qs = urllib.parse.parse_qs(parsed.query)
        job = qs.get("j", [None])[0]
        build = qs.get("b", [None])[0]

        print("{}: {}#{}: {}".format(time_now(), job, build, path))

        if job and build and (job, build) not in received:
            item = (now(), next(counter), PendingJob(job, build, relpath))
            heapq.heappush(pq, item)
            more_consoles.set()
            received.add((job, build))

    # Avoid default logging by overriding with a dummy function
    def log_message(self, *args):
        pass


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    pass


def now():
    return calendar.timegm(time.gmtime())


def time_now():
    return time.strftime("%H:%M:%S")


def console_monitor():
    while not exiting:
        # Wait here for the queue to be non-empty
        try:
            ts, count, job = pq[0]
        except IndexError:
            more_consoles.wait()
            continue

        # Short nap before next job is available
        if ts > now():
            time.sleep(2)
            continue

        ts, count, job = heapq.heappop(pq)
        if not job.is_ready():
            # Re-queue the job for later
            heapq.heappush(pq, (ts + 10, count, job))
            continue

        job.download_console(len(pq))
        more_consoles.clear()


parser = argparse.ArgumentParser()

parser.add_argument("--output-dir", "-o", default="artefacts")
parser.add_argument("ip", help="IP address to listen to")
parser.add_argument("port", help="Port number to listen  to")

opts = parser.parse_args()

os.makedirs(opts.output_dir, exist_ok=True)

server = Server((opts.ip, int(opts.port)), ArtefactsReceiver)
print("Trusted Firmware-A artefacts receiver:")
print()
print("\tUse artefacts_receiver=http://{}:{}".format(opts.ip, opts.port))
print("\tArtefacts will be placed under '{}'. Waiting...".format(opts.output_dir))
print()

try:
    more_consoles.clear()
    console_thread = threading.Thread(target=console_monitor)
    console_thread.start()
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    print()
    print("Exiting...")
    exiting = True
    more_consoles.set()
    console_thread.join()
    server.server_close()
